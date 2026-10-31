#ifndef SONGSEARCHMATCHER_H
#define SONGSEARCHMATCHER_H

#include <QString>
#include <QStringList>
#include <QVector>
#include <algorithm>

#include "./SearchTuning.hpp"
#include "./TextNormalizer.hpp"
#include "./ApproxMatch.hpp"

/* 曲库搜索的匹配算法对象: 预处理, 精确与模糊两路召回, 计分去重, 统一精排都在这里;
 * 对象本身不持有状态, 一次搜索的中间量全部落在局部变量里, 可重入 */
class SongSearchMatcher {
public:
    /* 候选条目: 三个原始字段与可选质量分; filename 传完整文件名, 去扩展名在这里做 */
    struct Candidate {
        QString songname;
        QString singer;
        QString filename;
        double hot=0.0;
    };
    /* 一条命中: 原条目下标, 是否精确命中, 分数, 字段权重, 命中位置与质量分;
     * 排序键依次为 是否精确, 分数, 字段权重, 位置, 质量分, 原顺序 */
    struct Hit {
        int index=-1;
        bool exact=false;
        double score=0.0;
        int fieldRank=0;
        int position=0;
        double hot=0.0;
    };
    /* 一次搜索的统计: 查询词长度, 两路召回条数, 最终条数与模式, 供界面输出调试 */
    struct Stats {
        int queryLen=0;
        int exactHits=0;
        int fuzzyHits=0;
        int returned=0;
        QString mode;
        QString normalized;
    };
    /* 查询词长度对应的编辑距离上限: 0 表示这一档不做模糊匹配 */
    static int maxDistanceOf(int queryLen) {
        if (queryLen<=SearchTuning::minExactOnlyLen) {
            return 0;
        }
        if (queryLen<=SearchTuning::strictFuzzyLen) {
            return SearchTuning::strictFuzzyMaxDistance;
        }
        if (queryLen>=SearchTuning::midLenLower && queryLen<=SearchTuning::midLenUpper) {
            return SearchTuning::midLenMaxDistance;
        }
        if (queryLen>=SearchTuning::longLenLower && queryLen<=SearchTuning::longLenUpper) {
            return SearchTuning::longLenMaxDistance;
        }
        return SearchTuning::longestLenMaxDistance;
    }
    /* 查询词长度对应的匹配模式说明 */
    static QString modeOf(int queryLen) {
        if (queryLen<=SearchTuning::minExactOnlyLen) {
            return QStringLiteral("精确");
        }
        if (queryLen<=SearchTuning::strictFuzzyLen) {
            return QStringLiteral("精确+严格模糊");
        }
        return QStringLiteral("精确+模糊");
    }
    /* 搜索: 关键字先归一化, 再按长度分档决定是否放行模糊匹配;
     * 每个条目只产出一条命中, 曲名与歌手的多路命中在这里取最高分 */
    QVector<Hit> search(const QString &keyword,const QVector<Candidate> &songs,
                        Stats *stats=nullptr) const {
        QVector<Hit> out;
        const QString query=TextNormalizer::normalize(keyword);
        const QVector<uint> queryUcs=query.toUcs4();
        const int queryLen=static_cast<int>(queryUcs.size());
        const int maxDistance=maxDistanceOf(queryLen);
        if (stats!=nullptr) {
            stats->normalized=query;
            stats->queryLen=queryLen;
            stats->mode=modeOf(queryLen);
            stats->exactHits=0;
            stats->fuzzyHits=0;
            stats->returned=0;
        }
        if (query.isEmpty() || songs.isEmpty()) {
            return out;
        }
        QVector<Hit> exactHits;
        QVector<Hit> fuzzyHits;
        for (int i=0;i<songs.size();++i) {
            const Candidate &one=songs.at(i);
            const QString song=TextNormalizer::normalize(one.songname);
            QStringList singers;
            const QStringList rawSingers=TextNormalizer::splitSingers(one.singer);
            for (const QString &raw : rawSingers) {
                const QString part=TextNormalizer::normalize(raw);
                if (part.isEmpty()==false) {
                    singers.append(part);
                }
            }
            /* 原始文件名称: 取末段, 去扩展名, 统一分隔符, 再走同一套归一化 */
            const QString file=TextNormalizer::normalize(
                        TextNormalizer::unifySeparators(
                            TextNormalizer::stripExtension(
                                TextNormalizer::fileNameOf(one.filename))));
            const bool fileHit=(file.isEmpty()==false && file.contains(query));
            /* 精确命中: 曲名优先于歌手, 原始文件名称只作加分项与兜底 */
            int fieldRank=-1;
            int position=0;
            if (song.isEmpty()==false) {
                const qsizetype at=song.indexOf(query);
                if (at>=0) {
                    fieldRank=2;
                    position=static_cast<int>(at);
                }
            }
            if (fieldRank<0) {
                for (const QString &part : singers) {
                    const qsizetype at=part.indexOf(query);
                    if (at>=0) {
                        fieldRank=1;
                        position=static_cast<int>(at);
                        break;
                    }
                }
            }
            if (fieldRank>=0) {
                Hit hit;
                hit.index=i;
                hit.exact=true;
                hit.fieldRank=fieldRank;
                hit.position=position;
                hit.hot=one.hot;
                hit.score=SearchTuning::exactBaseScore+bonusOf(fieldRank)
                        +(fileHit? SearchTuning::fileHitBonus:0.0);
                exactHits.append(hit);
                continue;
            }
            /* 模糊命中: 只对曲名与歌手开窗, 原始文件名称不参与模糊主排序 */
            if (maxDistance>0) {
                double bestSim=-1.0;
                int bestRank=-1;
                int bestPos=0;
                const auto tryField=[&](const QString &text,int rankOfField) {
                    if (text.isEmpty()) {
                        return;
                    }
                    const QVector<uint> ucs=text.toUcs4();
                    if (static_cast<int>(ucs.size())>SearchTuning::maxFuzzyFieldLen) {
                        return;
                    }
                    const ApproxMatch::WindowHit win=ApproxMatch::bestWindow(ucs,queryUcs,maxDistance);
                    if (win.distance<0 || win.distance>maxDistance) {
                        return;
                    }
                    if (win.sim<SearchTuning::minSimilarity) {
                        return;
                    }
                    if (win.sim>bestSim || (win.sim==bestSim && rankOfField>bestRank)) {
                        bestSim=win.sim;
                        bestRank=rankOfField;
                        bestPos=win.position;
                    }
                };
                tryField(song,2);
                for (const QString &part : singers) {
                    tryField(part,1);
                }
                if (bestSim>=0.0) {
                    Hit hit;
                    hit.index=i;
                    hit.exact=false;
                    hit.fieldRank=bestRank;
                    hit.position=bestPos;
                    hit.hot=one.hot;
                    hit.score=qMin<double>(SearchTuning::fuzzyMaxScore,
                                           bestSim*100.0+(fileHit? SearchTuning::fileHitBonus:0.0));
                    fuzzyHits.append(hit);
                    continue;
                }
            }
            /* 只有原始文件名称命中: 作为低权重的精确兜底候选 */
            if (fileHit) {
                Hit hit;
                hit.index=i;
                hit.exact=true;
                hit.fieldRank=0;
                hit.position=static_cast<int>(file.indexOf(query));
                hit.hot=one.hot;
                hit.score=SearchTuning::exactBaseScore+bonusOf(0);
                exactHits.append(hit);
            }
        }
        if (stats!=nullptr) {
            stats->exactHits=exactHits.size();
            stats->fuzzyHits=fuzzyHits.size();
        }
        /* 两路召回各自截断到上限, 再合并去重统一精排 */
        std::sort(exactHits.begin(),exactHits.end(),before);
        std::sort(fuzzyHits.begin(),fuzzyHits.end(),before);
        if (exactHits.size()>SearchTuning::exactRecallLimit) {
            exactHits.resize(SearchTuning::exactRecallLimit);
        }
        if (fuzzyHits.size()>SearchTuning::fuzzyRecallLimit) {
            fuzzyHits.resize(SearchTuning::fuzzyRecallLimit);
        }
        out+=exactHits;
        out+=fuzzyHits;
        std::sort(out.begin(),out.end(),before);
        if (stats!=nullptr) {
            stats->returned=out.size();
        }
        return out;
    }
private:
    /* 字段权重分: 曲名最高, 歌手次之, 原始文件名称最低 */
    static double bonusOf(int fieldRank) {
        switch (fieldRank) {
        case 2:
            return SearchTuning::songFieldBonus;
        case 1:
            return SearchTuning::singerFieldBonus;
        default:
            return SearchTuning::fileFieldBonus;
        }
    }
    /* 统一排序: 精确命中整体置顶, 其后分数降序, 再按字段权重, 命中位置, 质量分与原顺序兜底 */
    static bool before(const Hit &a,const Hit &b) {
        if (a.exact!=b.exact) {
            return a.exact;
        }
        if (a.score>b.score) {
            return true;
        }
        if (a.score<b.score) {
            return false;
        }
        if (a.fieldRank!=b.fieldRank) {
            return a.fieldRank>b.fieldRank;
        }
        if (a.position!=b.position) {
            return a.position<b.position;
        }
        if (a.hot>b.hot) {
            return true;
        }
        if (a.hot<b.hot) {
            return false;
        }
        return a.index<b.index;
    }
};

#endif

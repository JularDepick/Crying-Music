#ifndef APPSEARCHHELPER_H
#define APPSEARCHHELPER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

#include "./SongSearchMatcher.hpp"
#include "./TextNormalizer.hpp"

/* 搜索匹配的界面桥: 把界面传来的条目字段转成候选, 跑一遍匹配算法,
 * 返回排好序的条目下标与本次统计; 匹配逻辑本身在 SongSearchMatcher */
class AppSearchHelper : public QObject {
    Q_OBJECT
public:
    explicit AppSearchHelper(QObject *parent=nullptr):QObject(parent) {}

    /* 搜索: 入参 songs 为条目数组, 每项取 songname 与 singer, 原始文件名称取 filename,
     * 没有 filename 时退回取 path(本地绝对路径或在线地址); 可选 hot 为质量分;
     * 返回 indices 为命中条目在入参数组里的下标, 以及本次搜索的统计 */
    Q_INVOKABLE QVariantMap search(const QString &keyword,const QVariantList &songs) const {
        QVector<SongSearchMatcher::Candidate> candidates;
        candidates.reserve(songs.size());
        for (const QVariant &item : songs) {
            const QVariantMap one=item.toMap();
            SongSearchMatcher::Candidate c;
            c.songname=one.value(QStringLiteral("songname")).toString();
            c.singer=one.value(QStringLiteral("singer")).toString();
            const QString name=one.value(QStringLiteral("filename")).toString();
            c.filename=(name.isEmpty()? one.value(QStringLiteral("path")).toString():name);
            const QVariant hot=one.value(QStringLiteral("hot"));
            if (hot.isValid()) {
                c.hot=hot.toDouble();
            }
            candidates.append(c);
        }
        const SongSearchMatcher matcher;
        SongSearchMatcher::Stats stats;
        const QVector<SongSearchMatcher::Hit> hits=matcher.search(keyword,candidates,&stats);
        QVariantList indices;
        indices.reserve(hits.size());
        for (const SongSearchMatcher::Hit &hit : hits) {
            indices.append(hit.index);
        }
        QVariantMap out;
        out.insert(QStringLiteral("indices"),indices);
        out.insert(QStringLiteral("exact"),stats.exactHits);
        out.insert(QStringLiteral("fuzzy"),stats.fuzzyHits);
        out.insert(QStringLiteral("len"),stats.queryLen);
        out.insert(QStringLiteral("mode"),stats.mode);
        out.insert(QStringLiteral("query"),stats.normalized);
        return out;
    }

    /* 归一化一个字符串: 与搜索内部同一口径, 供界面调试与其它文本比对使用 */
    Q_INVOKABLE QString normalize(const QString &text) const {
        return TextNormalizer::normalize(text);
    }
};

#endif

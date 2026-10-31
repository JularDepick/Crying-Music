#ifndef SEARCHTUNING_H
#define SEARCHTUNING_H

#include <QString>
#include <QStringList>

/* 搜索匹配的设计常量: 长度分档, 编辑距离上限, 相似度阈值, 字段权重分,
 * 召回上限与歌手分隔符都集中在本文件, 调整搜索手感时只改这里 */
namespace SearchTuning {

/* 召回: 精确与模糊两路各自的条数上限, 短查询靠这两条截断候选爆炸 */
constexpr int exactRecallLimit = 200;
constexpr int fuzzyRecallLimit = 200;

/* 长度分档: 不超过 minExactOnlyLen 只做精确匹配; 不超过 strictFuzzyLen 只放行编辑距离 1 的严格模糊 */
constexpr int minExactOnlyLen = 2;
constexpr int strictFuzzyLen = 4;
constexpr int strictFuzzyMaxDistance = 1;

/* 长查询的编辑距离上限分档: 5 至 6 取 1, 7 至 10 取 2, 11 及以上取 3 */
constexpr int midLenLower = 5;
constexpr int midLenUpper = 6;
constexpr int midLenMaxDistance = 1;
constexpr int longLenLower = 7;
constexpr int longLenUpper = 10;
constexpr int longLenMaxDistance = 2;
constexpr int longestLenMaxDistance = 3;

/* 模糊命中的最低相似度: sim = 1 - 编辑距离 / max(查询长度, 窗口长度) */
constexpr double minSimilarity = 0.6;

/* 计分: 精确命中取基础分加字段权重分, 曲名最高, 歌手次之, 原始文件名最低;
 * 原始文件名命中另计一笔低权重加分, 模糊得分设上限以保证低于精确命中 */
constexpr double exactBaseScore = 90.0;
constexpr double songFieldBonus = 10.0;
constexpr double singerFieldBonus = 6.0;
constexpr double fileFieldBonus = 2.0;
constexpr double fileHitBonus = 1.0;
constexpr double fuzzyMaxScore = 99.0;

/* 模糊匹配的字段长度上限: 超长字段不做窗口枚举, 避免无谓开销 */
constexpr int maxFuzzyFieldLen = 128;

/* 去扩展名时认定的扩展名最大长度: 超过这个长度的末段不当作扩展名 */
constexpr int maxFileExtLen = 6;

/* 歌手行的分隔符: 命中任一字符即视为一个歌手的边界 */
inline const QString singerSeparators=QStringLiteral("/\\、,;|&+");

/* 歌手行里的连接词: 这些词本身不是歌手, 出现时只当分隔符 */
inline const QStringList singerConnectors=QStringList()<<QStringLiteral("feat")<<QStringLiteral("ft")
                                                      <<QStringLiteral("featuring")<<QStringLiteral("with")
                                                      <<QStringLiteral("vs");

}
#endif

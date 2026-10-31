#ifndef TEXTNORMALIZER_H
#define TEXTNORMALIZER_H

#include <QString>
#include <QStringList>
#include <QUrl>

#ifdef Q_OS_WIN
#include <qt_windows.h>
#endif

#include "./SearchTuning.hpp"

/* 文本归一化工具: 搜索的查询词与三个字段都先经这里处理, 保证两边同一口径;
 * 归一化顺序为 兼容合成与分解(统一全半角) -> 统一繁简 -> 去空白与标点 -> 大小写折叠 */
namespace TextNormalizer {

/* 是否含汉字: 不含汉字时无需做繁简转换, 省掉一次跨语言 API 调用 */
inline bool hasHanzi(const QString &text) {
    for (const QChar ch : text) {
        const ushort u=ch.unicode();
        if ((u>=0x3400 && u<=0x9FFF) || (u>=0xF900 && u<=0xFAFF)) {
            return true;
        }
    }
    return false;
}

/* 繁简统一: 把繁体转成简体. Windows 取系统 NLS 的简繁映射表,
 * 其它平台与调用失败时按原样返回, 不做转换 */
inline QString toSimplified(const QString &text) {
#ifdef Q_OS_WIN
    if (text.isEmpty() || hasHanzi(text)==false) {
        return text;
    }
    const int len=static_cast<int>(text.size());
    const wchar_t *src=reinterpret_cast<const wchar_t *>(text.utf16());
    const int need=::LCMapStringEx(L"zh-CN",LCMAP_SIMPLIFIED_CHINESE,src,len,nullptr,0,nullptr,nullptr,0);
    if (need<=0) {
        return text;
    }
    QString out;
    out.resize(need);
    const int got=::LCMapStringEx(L"zh-CN",LCMAP_SIMPLIFIED_CHINESE,src,len,
                                  reinterpret_cast<wchar_t *>(out.data()),need,nullptr,nullptr,0);
    if (got<=0) {
        return text;
    }
    out.resize(got);
    return out;
#else
    return text;
#endif
}

/* 只保留字母, 数字与组合记号: 空白, 标点与符号一律丢弃 */
inline bool keptChar(QChar ch) {
    const QChar::Category cat=ch.category();
    if (cat<=QChar::Mark_Enclosing) {
        return true;
    }
    if (cat>=QChar::Number_DecimalDigit && cat<=QChar::Number_Other) {
        return true;
    }
    if (cat>=QChar::Letter_Uppercase && cat<=QChar::Letter_Other) {
        return true;
    }
    return false;
}

/* 归一化: 全半角, 繁简, 空白, 标点与大小写全部统一, 结果只含字母数字 */
inline QString normalize(const QString &text) {
    if (text.isEmpty()) {
        return text;
    }
    const QString compat=text.normalized(QString::NormalizationForm_KC);
    const QString same=toSimplified(compat);
    QString out;
    out.reserve(same.size());
    for (const QChar ch : same) {
        if (keptChar(ch)) {
            out.append(ch);
        }
    }
    return out.toCaseFolded();
}

/* 取路径或地址的文件名末段: 兼容反斜杠与斜杠, 地址末段的百分号编码解码回原文 */
inline QString fileNameOf(const QString &path) {
    if (path.isEmpty()) {
        return path;
    }
    QString p=path;
    if (p.startsWith(QLatin1String("http://"),Qt::CaseInsensitive)
        || p.startsWith(QLatin1String("https://"),Qt::CaseInsensitive)
        || p.startsWith(QLatin1String("file://"),Qt::CaseInsensitive)) {
        p=QUrl::fromPercentEncoding(p.toUtf8());
    }
    const qsizetype a=p.lastIndexOf(QLatin1Char('/'));
    const qsizetype b=p.lastIndexOf(QLatin1Char('\\'));
    const qsizetype cut=(a>b? a:b);
    return (cut>=0? p.mid(cut+1):p);
}

/* 去扩展名: 仅当末段是 1 至 6 位字母数字时才认定为扩展名, 避免误砍歌名里的点 */
inline QString stripExtension(const QString &name) {
    const qsizetype dot=name.lastIndexOf(QLatin1Char('.'));
    if (dot<=0 || dot==name.size()-1) {
        return name;
    }
    const QString ext=name.mid(dot+1);
    if (ext.size()>SearchTuning::maxFileExtLen) {
        return name;
    }
    for (const QChar ch : ext) {
        if (ch.isLetterOrNumber()==false) {
            return name;
        }
    }
    return name.left(dot);
}

/* 统一分隔符: 下划线, 点, 横线, 间隔号与空白一律折成一个空格, 连续分隔符只留一个 */
inline QString unifySeparators(const QString &name) {
    QString out;
    out.reserve(name.size());
    bool prevSep=false;
    for (const QChar ch : name) {
        const bool sep=(ch==QLatin1Char('_') || ch==QLatin1Char('.') || ch==QLatin1Char('-')
                        || ch==QChar(0x00B7) || ch.isSpace());
        if (sep) {
            if (prevSep==false) {
                out.append(QLatin1Char(' '));
            }
            prevSep=true;
        } else {
            out.append(ch);
            prevSep=false;
        }
    }
    return out;
}

/* 歌手行拆成单个歌手: 先把全角分隔符统一成半角, 再按分隔符切段,
 * 段内的 feat 一类连接词当作边界; 返回的段不再做繁简与大小写处理, 由调用方按需再做 */
inline QStringList splitSingers(const QString &singers) {
    QStringList out;
    QString cur;
    const QString source=singers.normalized(QString::NormalizationForm_KC);
    const auto flush=[&out,&cur]() {
        const QString part=cur.simplified();
        cur.clear();
        if (part.isEmpty()) {
            return;
        }
        /* 段内的连接词 (feat. 一类) 本身不是歌手, 出现处即切成两个歌手 */
        QString name;
        const auto push=[&out,&name]() {
            const QString one=name.trimmed();
            name.clear();
            if (one.isEmpty()==false) {
                out.append(one);
            }
        };
        const QStringList words=part.split(QLatin1Char(' '),Qt::SkipEmptyParts);
        for (const QString &word : words) {
            QString key=word.toCaseFolded();
            while (key.endsWith(QLatin1Char('.')) || key.endsWith(QLatin1Char(','))) {
                key.chop(1);
            }
            if (SearchTuning::singerConnectors.contains(key)) {
                push();
                continue;
            }
            if (name.isEmpty()==false) {
                name.append(QLatin1Char(' '));
            }
            name.append(word);
        }
        push();
    };
    for (const QChar ch : source) {
        if (SearchTuning::singerSeparators.contains(ch)) {
            flush();
        } else {
            cur.append(ch);
        }
    }
    flush();
    return out;
}

}
#endif

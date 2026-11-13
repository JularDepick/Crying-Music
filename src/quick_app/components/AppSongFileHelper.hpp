#ifndef APPSONGFILEHELPER_H
#define APPSONGFILEHELPER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QCryptographicHash>
#include <QTimer>
#include <QImage>
#include <QByteArray>
#include <QUrl>
#include <QRegularExpression>
#include <QElapsedTimer>
#include <qdebug.h>
#include <string>

#include "AppDebugHelper.hpp"

#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/audioproperties.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/id3v1tag.h>
#include <taglib/attachedpictureframe.h>
#include <taglib/unsynchronizedlyricsframe.h>
#include <taglib/synchronizedlyricsframe.h>
#include <taglib/vorbisfile.h>
#include <taglib/xiphcomment.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/mp4file.h>
#include <taglib/mp4tag.h>
#include <taglib/mp4coverart.h>
#include <taglib/wavfile.h>
#include <taglib/tbytevector.h>
#include <taglib/tstring.h>

/* 本地音频的标签读取与缓存: 只处理扫描器支持的五种格式(mp3, m4a, wav, flac, ogg).
 * 调用方给出封面目录与歌词目录, 本类把内嵌封面与歌词转成缓存文件落盘, 再把一份记录
 * 交给 QML 侧的容器; QML 只读缓存, 不再为每个文件重复解析.
 * 歌词统一转 LRC; 带词级时间戳(SYLT)时另存一份 ELRC, 行内用 <mm:ss.xx> 标出每个词的起点;
 * 没有歌词时写一条占位文本, 让调用方少一层空判断.
 * 队列逐个推进, 每处理完一个发一次 songReady, 全部完成发 finished, 不阻塞界面线程.
 * 调试: 每个文件的路径形态, 容器, 音频属性, 标签字段与取值, 封面与歌词来源, 结果与耗时
 * 成块输出, 行首标签为 [本地标签]; 命令行带 --debug 才输出, 不带即静默 */
class AppSongFileHelper : public QObject {
    Q_OBJECT
public:
    explicit AppSongFileHelper(QObject *parent=nullptr):QObject(parent) {
        pump.setSingleShot(true);
        pump.setInterval(0);
        connect(&pump,&QTimer::timeout,this,&AppSongFileHelper::processNext);
    }

    /* 支持的格式: 与扫描器的格式清单同源 */
    Q_INVOKABLE QStringList supportedSuffixes() const {
        return {QStringLiteral("mp3"),QStringLiteral("m4a"),QStringLiteral("wav"),
                QStringLiteral("flac"),QStringLiteral("ogg")};
    }

    /* 是否支持某个文件: 只看扩展名, 在线条目不会被传进来 */
    Q_INVOKABLE bool supportsFile(const QString &absfpath) const {
        return supportedSuffixes().contains(QFileInfo(absfpath).suffix().toLower());
    }

    /* 处理一批本地文件: 逐个解析并落盘缓存, 结果经 songReady 逐个交回 */
    Q_INVOKABLE void processFiles(const QStringList &absfpaths, const QString &coverDir,
                                  const QString &lyricsDir) {
        pump.stop();
        queue.clear();
        if (!coverDir.trimmed().isEmpty()) {
            queueCoverDir = QDir::cleanPath(coverDir);
        }
        if (!lyricsDir.trimmed().isEmpty()) {
            queueLyricsDir = QDir::cleanPath(lyricsDir);
        }
        for (const QString &one : absfpaths) {
            const QString path = QString(one).trimmed();
            if (!path.isEmpty() && !queue.contains(path)) {
                queue.append(path);
            }
        }
        totalCount = queue.size();
        doneCount = 0;
        okCount = 0;
        failCount = 0;
        trace(QStringLiteral("批次开始: %1 个文件, 封面目录 '%2', 歌词目录 '%3'")
              .arg(totalCount).arg(queueCoverDir, queueLyricsDir));
        flushTrace();
        if (!queue.isEmpty()) {
            pump.start();
        } else {
            logBatchEnd();
            emit finished(0);
        }
    }

    /* 取消未处理的部分: 已完成的记录仍然有效 */
    Q_INVOKABLE void cancel() {
        queue.clear();
        pump.stop();
        logBatchEnd();
        emit finished(doneCount);
    }

    Q_INVOKABLE bool busy() const {
        return (!queue.isEmpty() || pump.isActive());
    }

signals:
    /* 单个文件的处理结果: 字段见 readOne 里插入的那些键 */
    void songReady(const QVariantMap &record);
    /* 全部处理结束: 已完成的个数 */
    void finished(int count);

private:
    /* 没有歌词时写进缓存的占位文本 */
    static constexpr char lyricsPlaceholder[] = "暂无歌词";
    /* 词级时间戳拆行的时间间隔阈值(毫秒): 间隔超过它视为换行 */
    static constexpr int syltLineGapMs = 1500;
    /* 没有换行线索时每行最多容纳的词数 */
    static constexpr int syltWordsPerLine = 10;
    /* 调试轨迹的开关取自命令行 --debug(见 AppDebug::enabled); 关掉后本类不再输出轨迹,
     * 失败告警(qWarning)仍照常输出 */
    /* 单条字段值的展示上限(字符) */
    static constexpr int debugValueLimit = 60;
    /* 一次最多列出多少个标签字段 */
    static constexpr int debugFieldLimit = 16;

    QStringList queue;
    QTimer pump;
    QString queueCoverDir;
    QString queueLyricsDir;
    int totalCount=0;
    int doneCount=0;
    int okCount=0;
    int failCount=0;
    /* 当前文件的调试轨迹: 整份文件处理完再一次性输出, 控制台里成块可读 */
    mutable QStringList traceBuf;

    /* 追加一行轨迹: 关掉开关时不记录 */
    void trace(const QString &line) const {
        if (AppDebug::enabled()) {
            traceBuf.append(line);
        }
    }

    /* 输出并清空本次文件的轨迹 */
    void flushTrace() const {
        if (AppDebug::enabled()) {
            for (const QString &one : traceBuf) {
                qInfo().noquote() << (QStringLiteral("[本地标签]") + one);
            }
        }
        traceBuf.clear();
    }

    /* 批次收尾: 汇总成功与失败个数 */
    void logBatchEnd() const {
        if (!AppDebug::enabled()) {
            return;
        }
        qInfo().noquote() << (QStringLiteral("[本地标签]")
                              + QStringLiteral("批次结束: 共 %1 个文件, 成功 %2 个, 失败 %3 个")
                                    .arg(totalCount).arg(okCount).arg(failCount));
    }

    /* 路径里是否含非 ASCII 字符: 中文路径是 TagLib 在 Windows 上最容易踩的坑, 单独标出来 */
    static bool hasNonAscii(const QString &text) {
        for (const QChar &one : text) {
            if (one.unicode() > 0x7f) {
                return true;
            }
        }
        return false;
    }

    /* 字段值压缩成一行并截断, 免得一张长值把控制台刷掉 */
    static QString clipValue(const QString &text) {
        QString one = text;
        one.replace(QLatin1Char('\n'), QLatin1Char(' '));
        one.replace(QLatin1Char('\r'), QLatin1Char(' '));
        if (one.size() > debugValueLimit) {
            one = one.left(debugValueLimit) + QStringLiteral("...");
        }
        return one;
    }

    /* 容器类型名: 只用于调试输出, 看出 TagLib 把文件认成了哪一种 */
    static QString containerName(TagLib::File *file) {
        if (dynamic_cast<TagLib::MPEG::File *>(file) != nullptr) {
            return QStringLiteral("MPEG(mp3)");
        }
        if (dynamic_cast<TagLib::Ogg::Vorbis::File *>(file) != nullptr) {
            return QStringLiteral("OggVorbis(ogg)");
        }
        if (dynamic_cast<TagLib::FLAC::File *>(file) != nullptr) {
            return QStringLiteral("FLAC");
        }
        if (dynamic_cast<TagLib::MP4::File *>(file) != nullptr) {
            return QStringLiteral("MP4(m4a)");
        }
        if (dynamic_cast<TagLib::RIFF::WAV::File *>(file) != nullptr) {
            return QStringLiteral("RIFF-WAV");
        }
        return QStringLiteral("未知容器");
    }

    /* 标签对象类型名: 只用于调试输出 */
    static QString tagKindName(TagLib::Tag *tag) {
        if (dynamic_cast<TagLib::ID3v2::Tag *>(tag) != nullptr) {
            return QStringLiteral("ID3v2");
        }
        if (dynamic_cast<TagLib::Ogg::XiphComment *>(tag) != nullptr) {
            return QStringLiteral("XiphComment");
        }
        if (dynamic_cast<TagLib::MP4::Tag *>(tag) != nullptr) {
            return QStringLiteral("MP4Tag");
        }
        if (dynamic_cast<TagLib::ID3v1::Tag *>(tag) != nullptr) {
            return QStringLiteral("ID3v1");
        }
        return QStringLiteral("其它");
    }

    /* Xiph 注释的字段清单: 键与值, 用于判断字段名是否被认作标题与歌手 */
    static QStringList xiphFieldParts(TagLib::Ogg::XiphComment *tag) {
        QStringList parts;
        if (tag == nullptr) {
            return parts;
        }
        const auto map = tag->fieldListMap();
        for (auto it = map.begin(); it != map.end(); ++it) {
            const QString key = fromTagString(it->first);
            const QString value = (it->second.isEmpty() ? QString() : fromTagString(it->second.front()));
            parts.append(key + QStringLiteral("=") + clipValue(value));
        }
        return parts;
    }

    /* ID3v2 的帧清单: 帧号与长度, 用于判断标签里到底有什么 */
    static QStringList id3FieldParts(TagLib::ID3v2::Tag *tag) {
        QStringList parts;
        if (tag == nullptr) {
            return parts;
        }
        const TagLib::ID3v2::FrameList frames = tag->frameList();
        for (TagLib::ID3v2::Frame *frame : frames) {
            if (frame == nullptr) {
                continue;
            }
            parts.append(fromTagString(frame->frameID()) + QStringLiteral("(")
                         + QString::number(int(frame->size())) + QStringLiteral("B)"));
        }
        return parts;
    }

    /* 按容器给出字段清单, 统一成一个字符串 */
    static QString fieldSummary(TagLib::File *file) {
        QStringList parts;
        if (auto *vorbis = dynamic_cast<TagLib::Ogg::Vorbis::File *>(file)) {
            parts = xiphFieldParts(vorbis->tag());
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(file)) {
            parts = xiphFieldParts(flac->xiphComment());
        } else if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(file)) {
            parts = (mpeg->hasID3v2Tag() ? id3FieldParts(mpeg->ID3v2Tag()) : QStringList());
        } else if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) {
            parts = (wav->hasID3v2Tag() ? id3FieldParts(wav->ID3v2Tag()) : QStringList());
        } else if (auto *mp4 = dynamic_cast<TagLib::MP4::File *>(file)) {
            if (mp4->tag() != nullptr) {
                const TagLib::MP4::ItemMap items = mp4->tag()->itemMap();
                for (auto it = items.begin(); it != items.end(); ++it) {
                    parts.append(fromTagString(it->first));
                }
            }
        }
        if (parts.isEmpty()) {
            return QStringLiteral("空");
        }
        const int shown = (int(parts.size()) > debugFieldLimit ? debugFieldLimit : int(parts.size()));
        QString out = parts.mid(0, shown).join(QStringLiteral(" | "));
        if (int(parts.size()) > shown) {
            out += QStringLiteral(" | ...(共 %1 项)").arg(parts.size());
        }
        return out;
    }

    void processNext() {
        if (queue.isEmpty()) {
            logBatchEnd();
            emit finished(doneCount);
            return;
        }
        const QString absfpath = queue.takeFirst();
        const QVariantMap record = readOne(absfpath);
        ++doneCount;
        emit songReady(record);
        if (queue.isEmpty()) {
            logBatchEnd();
            emit finished(doneCount);
            return;
        }
        pump.start();
    }

    /* 处理单个文件: 读标签与内嵌资源, 落盘缓存, 返回一条记录 */
    QVariantMap readOne(const QString &absfpath) {
        QElapsedTimer elapsed;
        elapsed.start();
        traceBuf.clear();
        trace(QStringLiteral("文件 %1/%2 %3").arg(doneCount+1).arg(totalCount).arg(absfpath));

        QVariantMap rec;
        rec.insert(QStringLiteral("absfpath"), absfpath);
        rec.insert(QStringLiteral("suffix"), QFileInfo(absfpath).suffix().toLower());
        rec.insert(QStringLiteral("ok"), false);
        rec.insert(QStringLiteral("songname"), QString());
        rec.insert(QStringLiteral("singer"), QString());
        rec.insert(QStringLiteral("album"), QString());
        rec.insert(QStringLiteral("durationMs"), qint64(0));
        rec.insert(QStringLiteral("hasTitle"), false);
        rec.insert(QStringLiteral("hasArtist"), false);
        rec.insert(QStringLiteral("coverPath"), QString());
        rec.insert(QStringLiteral("coverUrl"), QString());
        rec.insert(QStringLiteral("hasCover"), false);
        rec.insert(QStringLiteral("lyricsPath"), QString());
        rec.insert(QStringLiteral("lyricsEnhancedPath"), QString());
        rec.insert(QStringLiteral("lyricsFormat"), QStringLiteral("none"));

        /* 入参可能是 file:// 形式的 URL(列表里存的就是这种), 统一转成本地路径再交给 TagLib;
         * 记录键与缓存命名仍用原始键, 与 AppFileHelper 的哈希口径保持一致 */
        const bool fromUrl = absfpath.startsWith(QStringLiteral("file:"));
        const QString local = (fromUrl ? QUrl(absfpath).toLocalFile() : absfpath);
        if (local.isEmpty() || !QFile::exists(local)) {
            trace(QStringLiteral("  路径: 原始键是%1, 本地路径 '%2', 文件不存在")
                  .arg(fromUrl ? QStringLiteral(" file url") : QStringLiteral("本地路径"), local));
            trace(QStringLiteral("  结果: 失败(文件不存在)"));
            flushTrace();
            ++failCount;
            qWarning() << "AppSongFileHelper readOne failed: file not exists" << local;
            return rec;
        }
        if (!supportsFile(local)) {
            trace(QStringLiteral("  路径: 本地 '%1', 后缀不在支持清单内").arg(local));
            trace(QStringLiteral("  结果: 失败(后缀不支持)"));
            flushTrace();
            ++failCount;
            qWarning() << "AppSongFileHelper readOne skipped: unsupported suffix" << local;
            return rec;
        }
        rec.insert(QStringLiteral("localPath"), local);
        trace(QStringLiteral("  路径: 本地 '%1', 非 ASCII 字符 %2, 大小 %3 字节, 后缀 %4")
              .arg(local)
              .arg(hasNonAscii(local) ? QStringLiteral("有") : QStringLiteral("无"))
              .arg(QFileInfo(local).size())
              .arg(QFileInfo(local).suffix().toLower()));

        /* TagLib 的 FileName 在 Windows 上也能接窄字符串, 但它按系统 ANSI 代码页解释,
         * 中文路径会被曲解成另一个不存在的名字, FileRef 直接打不开;
         * 因此 Windows 一律传宽字符路径(QString 本身就是 UTF-16, 不必再经代码页转换),
         * 其它平台按本地 8 位编码传 */
#ifdef Q_OS_WIN
        const std::wstring nativePath = local.toStdWString();
        trace(QStringLiteral("  打开: 宽字符路径, %1 个字符").arg(int(nativePath.size())));
        TagLib::FileRef ref(nativePath.c_str(), true, TagLib::AudioProperties::Fast);
#else
        const QByteArray nativePath = local.toLocal8Bit();
        trace(QStringLiteral("  打开: 本地 8 位路径, %1 字节").arg(nativePath.size()));
        TagLib::FileRef ref(nativePath.constData(), true, TagLib::AudioProperties::Fast);
#endif
        if (ref.isNull() || ref.file() == nullptr) {
            trace(QStringLiteral("  结果: 失败(TagLib 打不开, FileRef 为空)"));
            flushTrace();
            ++failCount;
            qWarning() << "AppSongFileHelper readOne failed: taglib cannot open" << local;
            return rec;
        }
        TagLib::File *file = ref.file();
        trace(QStringLiteral("  打开: 成功, 容器 %1").arg(containerName(file)));

        qint64 durationMs = 0;
        if (ref.audioProperties() != nullptr) {
            const TagLib::AudioProperties *props = ref.audioProperties();
            durationMs = props->lengthInMilliseconds();
            trace(QStringLiteral("  音频: 时长 %1 ms, 采样率 %2 Hz, 声道 %3, 码率 %4 kbps")
                  .arg(durationMs).arg(props->sampleRate()).arg(props->channels()).arg(props->bitrate()));
        } else {
            trace(QStringLiteral("  音频: 没有音频属性"));
        }
        rec.insert(QStringLiteral("durationMs"), durationMs);

        /* 标题与歌手: 标签里有就用标签, 没有就留空, 由调用方回退到文件名与未知歌手 */
        QString title;
        QString artist;
        QString album;
        if (ref.tag() != nullptr) {
            trace(QStringLiteral("  标签: 类型 %1, 字段 %2")
                  .arg(tagKindName(ref.tag()), fieldSummary(file)));
            title = fromTagString(ref.tag()->title()).trimmed();
            artist = fromTagString(ref.tag()->artist()).trimmed();
            album = fromTagString(ref.tag()->album()).trimmed();
        } else {
            trace(QStringLiteral("  标签: 没有标签对象"));
        }
        trace(QStringLiteral("  取值: 曲名 '%1', 歌手 '%2', 专辑 '%3'").arg(title, artist, album));
        rec.insert(QStringLiteral("songname"), title);
        rec.insert(QStringLiteral("singer"), artist);
        rec.insert(QStringLiteral("album"), album);
        rec.insert(QStringLiteral("hasTitle"), !title.isEmpty());
        rec.insert(QStringLiteral("hasArtist"), !artist.isEmpty());

        /* 封面: 转成 PNG 落盘, 与本地封面缓存同一套命名 */
        const QByteArray coverData = coverBytesOf(file);
        if (coverData.isEmpty()) {
            trace(QStringLiteral("  封面: 没有可用的内嵌图片"));
        } else {
            trace(QStringLiteral("  封面: 内嵌图片 %1 字节").arg(coverData.size()));
            QString coverPath;
            if (saveCover(coverData, absfpath, coverPath)) {
                rec.insert(QStringLiteral("coverPath"), coverPath);
                /* QML 侧直接用它, 免得自己拼 file:// 与百分号转义 */
                rec.insert(QStringLiteral("coverUrl"), QUrl::fromLocalFile(coverPath).toString());
                rec.insert(QStringLiteral("hasCover"), true);
                trace(QStringLiteral("  封面: 已落盘 '%1'").arg(coverPath));
            }
        }

        /* 歌词缓存主名: 与列表页登记给歌词页的名字同一口径 */
        const QString lyricsName = QStringLiteral("local_") + shortHash(absfpath);
        rec.insert(QStringLiteral("lyricsName"), lyricsName);

        /* 歌词: 统一转 LRC, 有词级时间戳时另存 ELRC; 都没有时写占位文本 */
        QString plain;
        QString elrc;
        lyricsOf(file, durationMs, plain, elrc);
        QString lyricsPath;
        QString lyricsEnhancedPath;
        if (!elrc.isEmpty()) {
            const QString base = QDir(queueLyricsDir).filePath(QStringLiteral("local_") + shortHash(absfpath));
            if (saveText(elrc, base + QStringLiteral(".elrc"))) {
                lyricsEnhancedPath = base + QStringLiteral(".elrc");
            }
            const QString lrcText = (plain.isEmpty() ? elrcToPlainLrc(elrc) : plain);
            if (saveText(lrcText, base + QStringLiteral(".lrc"))) {
                lyricsPath = base + QStringLiteral(".lrc");
            }
            rec.insert(QStringLiteral("lyricsFormat"), QStringLiteral("elrc"));
        } else if (!plain.isEmpty()) {
            const QString base = QDir(queueLyricsDir).filePath(QStringLiteral("local_") + shortHash(absfpath));
            if (saveText(plain, base + QStringLiteral(".lrc"))) {
                lyricsPath = base + QStringLiteral(".lrc");
            }
            rec.insert(QStringLiteral("lyricsFormat"), QStringLiteral("lrc"));
        } else {
            const QString base = QDir(queueLyricsDir).filePath(QStringLiteral("local_") + shortHash(absfpath));
            if (saveText(QString::fromUtf8(lyricsPlaceholder), base + QStringLiteral(".lrc"))) {
                lyricsPath = base + QStringLiteral(".lrc");
            }
            rec.insert(QStringLiteral("lyricsFormat"), QStringLiteral("placeholder"));
        }
        rec.insert(QStringLiteral("lyricsPath"), lyricsPath);
        rec.insert(QStringLiteral("lyricsEnhancedPath"), lyricsEnhancedPath);
        trace(QStringLiteral("  歌词: 档位 %1, 普通 '%2', 增强 '%3'")
              .arg(rec.value(QStringLiteral("lyricsFormat")).toString())
              .arg(lyricsPath, lyricsEnhancedPath));
        rec.insert(QStringLiteral("ok"), true);
        ++okCount;
        trace(QStringLiteral("  结果: 成功, 耗时 %1 ms").arg(elapsed.elapsed()));
        flushTrace();
        return rec;
    }

    /* TagLib 的字符串统一按 UTF-8 取出 */
    static QString fromTagString(const TagLib::String &text) {
        return QString::fromUtf8(text.to8Bit(true).c_str());
    }

    /* Qt 字符串转 TagLib 的键名: 一律按 UTF-8 解释, 免得非 ASCII 键(如 MP4 的版权符歌词键)走 Latin1 */
    static TagLib::String tagKey(const QString &text) {
        return TagLib::String(text.toUtf8().constData(), TagLib::String::UTF8);
    }

    /* 路径的短哈希: 与 AppFileHelper 的本地封面与歌词缓存同一算法(SHA-256 前 16 位),
     * 因此两边写出的缓存文件名一致, 旧缓存也能直接命中 */
    static QString shortHash(const QString &absfpath) {
        return QString::fromUtf8(QCryptographicHash::hash(absfpath.toUtf8(),
                                                          QCryptographicHash::Sha256).toHex().left(16));
    }

    /* 毫秒转 LRC 行首时间戳 [mm:ss.cc] */
    static QString lrcStamp(qint64 ms) {
        const qint64 total = (ms < 0 ? 0 : ms);
        const qint64 minutes = total / 60000;
        const qint64 seconds = (total % 60000) / 1000;
        const qint64 centis = (total % 1000) / 10;
        return QStringLiteral("[%1:%2.%3]")
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds, 2, 10, QLatin1Char('0'))
            .arg(centis, 2, 10, QLatin1Char('0'));
    }

    /* 毫秒转 ELRC 词级时间戳 <mm:ss.cc> */
    static QString wordStamp(qint64 ms) {
        const qint64 total = (ms < 0 ? 0 : ms);
        const qint64 minutes = total / 60000;
        const qint64 seconds = (total % 60000) / 1000;
        const qint64 centis = (total % 1000) / 10;
        return QStringLiteral("<%1:%2.%3>")
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds, 2, 10, QLatin1Char('0'))
            .arg(centis, 2, 10, QLatin1Char('0'));
    }

    /* 写文本文件: UTF-8, 原子写 */
    static bool saveText(const QString &text, const QString &filePath) {
        if (filePath.isEmpty()) {
            return false;
        }
        QDir().mkpath(QFileInfo(filePath).absolutePath());
        QSaveFile out(filePath);
        if (!out.open(QIODevice::WriteOnly)) {
            qWarning() << "AppSongFileHelper saveText failed:" << filePath << out.errorString();
            return false;
        }
        out.write(text.toUtf8());
        if (!out.commit()) {
            qWarning() << "AppSongFileHelper saveText commit failed:" << filePath << out.errorString();
            return false;
        }
        return true;
    }

    /* 封面落盘: 统一转 PNG, 命名与本地封面缓存一致(local_<短哈希>.png) */
    bool saveCover(const QByteArray &data, const QString &absfpath, QString &outPath) {
        if (data.isEmpty() || queueCoverDir.isEmpty()) {
            trace(QStringLiteral("  封面: 跳过(没有图片数据或封面目录为空)"));
            return false;
        }
        QImage image;
        if (!image.loadFromData(data)) {
            trace(QStringLiteral("  封面: 图片无法解码, 只跳过封面"));
            qWarning() << "AppSongFileHelper saveCover failed: image cannot be decoded" << absfpath;
            return false;
        }
        trace(QStringLiteral("  封面: 解码为 %1x%2").arg(image.width()).arg(image.height()));
        QDir().mkpath(queueCoverDir);
        const QString file = QDir(queueCoverDir).filePath(QStringLiteral("local_") + shortHash(absfpath)
                                                          + QStringLiteral(".png"));
        QSaveFile out(file);
        if (!out.open(QIODevice::WriteOnly)) {
            qWarning() << "AppSongFileHelper saveCover failed:" << file << out.errorString();
            return false;
        }
        if (!image.save(&out, "PNG") || !out.commit()) {
            out.cancelWriting();
            qWarning() << "AppSongFileHelper saveCover commit failed:" << file;
            return false;
        }
        outPath = file;
        return true;
    }

    /* ID3v2 的 APIC 帧: 优先正面封面 */
    static QByteArray apicBytes(TagLib::ID3v2::Tag *tag) {
        if (tag == nullptr) {
            return {};
        }
        QByteArray fallback;
        const TagLib::ID3v2::FrameList frames = tag->frameList("APIC");
        for (TagLib::ID3v2::Frame *frame : frames) {
            auto *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frame);
            if (picture == nullptr) {
                continue;
            }
            const QByteArray data(picture->picture().data(), int(picture->picture().size()));
            if (data.isEmpty()) {
                continue;
            }
            if (picture->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) {
                return data;
            }
            if (fallback.isEmpty()) {
                fallback = data;
            }
        }
        return fallback;
    }

    /* Xiph comment 里的封面: 图片块优先, 其次旧式的 COVERART */
    static QByteArray xiphCoverBytes(TagLib::Ogg::XiphComment *tag) {
        if (tag == nullptr) {
            return {};
        }
        const TagLib::List<TagLib::FLAC::Picture *> pictures = tag->pictureList();
        for (TagLib::FLAC::Picture *one : pictures) {
            if (one == nullptr) {
                continue;
            }
            const QByteArray data(one->data().data(), int(one->data().size()));
            if (!data.isEmpty()) {
                return data;
            }
        }
        const auto map = tag->fieldListMap();
        const TagLib::String blockKey = tagKey(QStringLiteral("METADATA_BLOCK_PICTURE"));
        if (map.contains(blockKey) && !map[blockKey].isEmpty()) {
            const QByteArray raw = QByteArray::fromBase64(fromTagString(map[blockKey].front()).toUtf8());
            if (!raw.isEmpty()) {
                TagLib::FLAC::Picture picture;
                if (picture.parse(TagLib::ByteVector(raw.constData(), uint(raw.size())))) {
                    return QByteArray(picture.data().data(), int(picture.data().size()));
                }
            }
        }
        const TagLib::String artKey = tagKey(QStringLiteral("COVERART"));
        if (map.contains(artKey) && !map[artKey].isEmpty()) {
            return QByteArray::fromBase64(fromTagString(map[artKey].front()).toUtf8());
        }
        return {};
    }

    /* 按格式取内嵌封面字节: 只覆盖扫描器支持的这五种容器 */
    QByteArray coverBytesOf(TagLib::File *file) {
        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(file)) {
            if (!mpeg->hasID3v2Tag()) {
                trace(QStringLiteral("  封面: mp3 没有 ID3v2 标签"));
                return {};
            }
            trace(QStringLiteral("  封面: mp3 APIC 帧 %1 个")
                  .arg(int(mpeg->ID3v2Tag()->frameList("APIC").size())));
            return apicBytes(mpeg->ID3v2Tag());
        }
        if (auto *vorbis = dynamic_cast<TagLib::Ogg::Vorbis::File *>(file)) {
            if (vorbis->tag() == nullptr) {
                trace(QStringLiteral("  封面: ogg 没有 Xiph 注释"));
                return {};
            }
            trace(QStringLiteral("  封面: ogg 图片块 %1 个")
                  .arg(int(vorbis->tag()->pictureList().size())));
            return xiphCoverBytes(vorbis->tag());
        }
        if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(file)) {
            const TagLib::List<TagLib::FLAC::Picture *> pictures = flac->pictureList();
            trace(QStringLiteral("  封面: flac 图片块 %1 个").arg(int(pictures.size())));
            for (TagLib::FLAC::Picture *one : pictures) {
                if (one == nullptr) {
                    continue;
                }
                const QByteArray data(one->data().data(), int(one->data().size()));
                if (!data.isEmpty()) {
                    return data;
                }
            }
            return xiphCoverBytes(flac->xiphComment());
        }
        if (auto *mp4 = dynamic_cast<TagLib::MP4::File *>(file)) {
            if (mp4->tag() != nullptr) {
                const TagLib::MP4::Item item = mp4->tag()->item(tagKey(QStringLiteral("covr")));
                const TagLib::MP4::CoverArtList covers = item.toCoverArtList();
                trace(QStringLiteral("  封面: mp4 covr 项 %1 个").arg(int(covers.size())));
                for (const TagLib::MP4::CoverArt &one : covers) {
                    const QByteArray data(one.data().data(), int(one.data().size()));
                    if (!data.isEmpty()) {
                        return data;
                    }
                }
            }
            return {};
        }
        if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) {
            if (!wav->hasID3v2Tag()) {
                trace(QStringLiteral("  封面: wav 没有 ID3v2 标签"));
                return {};
            }
            trace(QStringLiteral("  封面: wav APIC 帧 %1 个")
                  .arg(int(wav->ID3v2Tag()->frameList("APIC").size())));
            return apicBytes(wav->ID3v2Tag());
        }
        trace(QStringLiteral("  封面: 该容器不支持内嵌封面读取"));
        return {};
    }

    /* 文本里是否已经带 LRC 行首时间戳 */
    static bool looksLikeLrc(const QString &text) {
        return text.contains(QRegularExpression(QStringLiteral("\\[\\d{1,3}:\\d{2}")));
    }

    /* 纯文本歌词转 LRC: 已有时间戳原样保留, 没有时按整曲时长均分补出 */
    static QString plainToLrc(const QString &text, qint64 durationMs) {
        const QString trimmed = text.trimmed();
        if (trimmed.isEmpty()) {
            return {};
        }
        if (looksLikeLrc(trimmed)) {
            return trimmed + QStringLiteral("\n");
        }
        const QStringList lines = trimmed.split(QLatin1Char('\n'));
        QString out;
        const int count = lines.size();
        for (int i = 0; i < count; ++i) {
            const QString one = lines.at(i).trimmed();
            if (one.isEmpty()) {
                continue;
            }
            if (durationMs > 0 && count > 0) {
                out += lrcStamp(durationMs * i / count);
            }
            out += one;
            out += QLatin1Char('\n');
        }
        return out;
    }

    /* ELRC 转普通 LRC: 去掉词级标记, 只留行首时间戳与整行文本 */
    static QString elrcToPlainLrc(const QString &elrc) {
        QString out;
        const QStringList lines = elrc.split(QLatin1Char('\n'));
        for (const QString &one : lines) {
            if (one.trimmed().isEmpty()) {
                continue;
            }
            QString line = one;
            line.remove(QRegularExpression(QStringLiteral("<\\d{1,3}:\\d{2}\\.\\d{2}>")));
            out += line.trimmed();
            out += QLatin1Char('\n');
        }
        return out;
    }

    /* 取歌词: 同步歌词转 ELRC(同时给出纯文本 LRC), 非同步歌词转 LRC */
    void lyricsOf(TagLib::File *file, qint64 durationMs, QString &plain, QString &elrc) const {
        plain.clear();
        elrc.clear();
        QString uslt;
        QString sylt;
        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(file)) {
            if (mpeg->hasID3v2Tag()) {
                int usltFrames = 0;
                int syltFrames = 0;
                id3Lyrics(mpeg->ID3v2Tag(), uslt, sylt, &usltFrames, &syltFrames);
                trace(QStringLiteral("  歌词: mp3 USLT 帧 %1 个(%2 字), SYLT 帧 %3 个(%4 字)")
                      .arg(usltFrames).arg(uslt.size()).arg(syltFrames).arg(sylt.size()));
            } else {
                trace(QStringLiteral("  歌词: mp3 没有 ID3v2 标签"));
            }
        } else if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) {
            if (wav->hasID3v2Tag()) {
                int usltFrames = 0;
                int syltFrames = 0;
                id3Lyrics(wav->ID3v2Tag(), uslt, sylt, &usltFrames, &syltFrames);
                trace(QStringLiteral("  歌词: wav USLT 帧 %1 个(%2 字), SYLT 帧 %3 个(%4 字)")
                      .arg(usltFrames).arg(uslt.size()).arg(syltFrames).arg(sylt.size()));
            } else {
                trace(QStringLiteral("  歌词: wav 没有 ID3v2 标签"));
            }
        } else if (auto *vorbis = dynamic_cast<TagLib::Ogg::Vorbis::File *>(file)) {
            QString keyFound;
            uslt = xiphLyrics(vorbis->tag(), &keyFound);
            trace(QStringLiteral("  歌词: ogg 命中字段 %1, %2 字")
                  .arg(keyFound.isEmpty() ? QStringLiteral("无") : keyFound).arg(uslt.size()));
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(file)) {
            QString keyFound;
            uslt = xiphLyrics(flac->xiphComment(), &keyFound);
            trace(QStringLiteral("  歌词: flac 命中字段 %1, %2 字")
                  .arg(keyFound.isEmpty() ? QStringLiteral("无") : keyFound).arg(uslt.size()));
        } else if (auto *mp4 = dynamic_cast<TagLib::MP4::File *>(file)) {
            if (mp4->tag() != nullptr) {
                const TagLib::MP4::Item item = mp4->tag()->item(tagKey(QStringLiteral("©lyr")));
                const TagLib::StringList values = item.toStringList();
                if (!values.isEmpty()) {
                    uslt = fromTagString(values.front());
                }
            }
            trace(QStringLiteral("  歌词: m4a 歌词项 %1 字").arg(uslt.size()));
        }
        if (!sylt.isEmpty()) {
            elrc = sylt;
        }
        if (!uslt.isEmpty()) {
            plain = plainToLrc(uslt, durationMs);
        }
        trace(QStringLiteral("  歌词: 转出普通 %1 字, 增强 %2 字").arg(plain.size()).arg(elrc.size()));
    }

    /* ID3v2 里的 USLT 与 SYLT: SYLT 直接转成 ELRC 文本 */
    static void id3Lyrics(TagLib::ID3v2::Tag *tag, QString &uslt, QString &sylt,
                          int *usltCount = nullptr, int *syltCount = nullptr) {
        if (usltCount != nullptr) {
            *usltCount = 0;
        }
        if (syltCount != nullptr) {
            *syltCount = 0;
        }
        if (tag == nullptr) {
            return;
        }
        const TagLib::ID3v2::FrameList usltFrames = tag->frameList("USLT");
        if (usltCount != nullptr) {
            *usltCount = int(usltFrames.size());
        }
        for (TagLib::ID3v2::Frame *frame : usltFrames) {
            auto *one = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame);
            if (one != nullptr) {
                const QString text = fromTagString(one->text()).trimmed();
                if (!text.isEmpty()) {
                    uslt = text;
                    break;
                }
            }
        }
        const TagLib::ID3v2::FrameList syltFrames = tag->frameList("SYLT");
        if (syltCount != nullptr) {
            *syltCount = int(syltFrames.size());
        }
        for (TagLib::ID3v2::Frame *frame : syltFrames) {
            auto *one = dynamic_cast<TagLib::ID3v2::SynchronizedLyricsFrame *>(frame);
            if (one == nullptr) {
                continue;
            }
            if (one->timestampFormat() != TagLib::ID3v2::SynchronizedLyricsFrame::AbsoluteMilliseconds) {
                continue;
            }
            const QString text = syltToElrc(one->synchedText());
            if (!text.isEmpty()) {
                sylt = text;
                break;
            }
        }
    }

    /* Xiph comment 里的歌词字段: 几个常见的键都认 */
    static QString xiphLyrics(TagLib::Ogg::XiphComment *tag, QString *keyFound = nullptr) {
        if (keyFound != nullptr) {
            keyFound->clear();
        }
        if (tag == nullptr) {
            return {};
        }
        const auto map = tag->fieldListMap();
        const char *keys[] = {"LYRICS", "UNSYNCEDLYRICS", "LYRIC", "UNSYNCED LYRICS"};
        for (const char *key : keys) {
            const TagLib::String fieldKey = tagKey(QString::fromLatin1(key));
            if (map.contains(fieldKey) && !map[fieldKey].isEmpty()) {
                const QString text = fromTagString(map[fieldKey].front()).trimmed();
                if (!text.isEmpty()) {
                    if (keyFound != nullptr) {
                        *keyFound = QString::fromLatin1(key);
                    }
                    return text;
                }
            }
        }
        return {};
    }

    /* 同步歌词转 ELRC: 行首 [mm:ss.cc], 行内每个词前 <mm:ss.cc>;
     * 换行线索是词文本里的换行符, 以及相邻词之间超过阈值的时间间隔 */
    static QString syltToElrc(const TagLib::ID3v2::SynchronizedLyricsFrame::SynchedTextList &list) {
        QString out;
        QString lineText;
        qint64 lineStartMs = -1;
        qint64 lastMs = -1;
        int wordsInLine = 0;
        const auto flush = [&]() {
            if (lineText.isEmpty()) {
                return;
            }
            out += lrcStamp(lineStartMs < 0 ? 0 : lineStartMs);
            out += lineText;
            out += QLatin1Char('\n');
            lineText.clear();
            lineStartMs = -1;
            wordsInLine = 0;
        };
        for (const TagLib::ID3v2::SynchronizedLyricsFrame::SynchedText &one : list) {
            QString word = fromTagString(one.text);
            const qint64 ms = qint64(one.time);
            const bool gapBreak = (lastMs >= 0 && ms - lastMs > syltLineGapMs);
            const bool countBreak = (wordsInLine >= syltWordsPerLine);
            if (!lineText.isEmpty() && (gapBreak || countBreak || word.contains(QLatin1Char('\n')))) {
                flush();
            }
            if (lineText.isEmpty()) {
                lineStartMs = ms;
            }
            const bool hadNewline = word.contains(QLatin1Char('\n'));
            word.replace(QStringLiteral("\r"), QString());
            word.replace(QStringLiteral("\n"), QString());
            lineText += wordStamp(ms);
            lineText += word;
            ++wordsInLine;
            lastMs = ms;
            if (hadNewline) {
                flush();
            }
        }
        flush();
        return out;
    }
};

#endif

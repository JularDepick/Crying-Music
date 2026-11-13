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
#include <qdebug.h>
#include <string>

#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/audioproperties.h>
#include <taglib/mpegfile.h>
#include <taglib/id3v2tag.h>
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
 * 队列逐个推进, 每处理完一个发一次 songReady, 全部完成发 finished, 不阻塞界面线程 */
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
        if (!queue.isEmpty()) {
            pump.start();
        } else {
            emit finished(0);
        }
    }

    /* 取消未处理的部分: 已完成的记录仍然有效 */
    Q_INVOKABLE void cancel() {
        queue.clear();
        pump.stop();
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

    QStringList queue;
    QTimer pump;
    QString queueCoverDir;
    QString queueLyricsDir;
    int totalCount=0;
    int doneCount=0;

    void processNext() {
        if (queue.isEmpty()) {
            emit finished(doneCount);
            return;
        }
        const QString absfpath = queue.takeFirst();
        const QVariantMap record = readOne(absfpath);
        ++doneCount;
        emit songReady(record);
        if (queue.isEmpty()) {
            emit finished(doneCount);
            return;
        }
        pump.start();
    }

    /* 处理单个文件: 读标签与内嵌资源, 落盘缓存, 返回一条记录 */
    QVariantMap readOne(const QString &absfpath) {
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
        const QString local = (absfpath.startsWith(QStringLiteral("file:"))
                               ? QUrl(absfpath).toLocalFile() : absfpath);
        if (local.isEmpty() || !QFile::exists(local)) {
            qWarning() << "AppSongFileHelper readOne failed: file not exists" << local;
            return rec;
        }
        if (!supportsFile(local)) {
            qWarning() << "AppSongFileHelper readOne skipped: unsupported suffix" << local;
            return rec;
        }
        rec.insert(QStringLiteral("localPath"), local);
        /* TagLib 的 FileName 在 Windows 上也能接窄字符串, 但它按系统 ANSI 代码页解释,
         * 中文路径会被曲解成另一个不存在的名字, FileRef 直接打不开;
         * 因此 Windows 一律传宽字符路径(QString 本身就是 UTF-16, 不必再经代码页转换),
         * 其它平台按本地 8 位编码传 */
#ifdef Q_OS_WIN
        const std::wstring nativePath = local.toStdWString();
        TagLib::FileRef ref(nativePath.c_str(), true, TagLib::AudioProperties::Fast);
#else
        const QByteArray nativePath = local.toLocal8Bit();
        TagLib::FileRef ref(nativePath.constData(), true, TagLib::AudioProperties::Fast);
#endif
        if (ref.isNull() || ref.file() == nullptr) {
            qWarning() << "AppSongFileHelper readOne failed: taglib cannot open" << local;
            return rec;
        }
        TagLib::File *file = ref.file();
        qint64 durationMs = 0;
        if (ref.audioProperties() != nullptr) {
            durationMs = ref.audioProperties()->lengthInMilliseconds();
        }
        rec.insert(QStringLiteral("durationMs"), durationMs);

        /* 标题与歌手: 标签里有就用标签, 没有就留空, 由调用方回退到文件名与未知歌手 */
        QString title;
        QString artist;
        QString album;
        if (ref.tag() != nullptr) {
            title = fromTagString(ref.tag()->title()).trimmed();
            artist = fromTagString(ref.tag()->artist()).trimmed();
            album = fromTagString(ref.tag()->album()).trimmed();
        }
        rec.insert(QStringLiteral("songname"), title);
        rec.insert(QStringLiteral("singer"), artist);
        rec.insert(QStringLiteral("album"), album);
        rec.insert(QStringLiteral("hasTitle"), !title.isEmpty());
        rec.insert(QStringLiteral("hasArtist"), !artist.isEmpty());

        /* 封面: 转成 PNG 落盘, 与本地封面缓存同一套命名 */
        const QByteArray coverData = coverBytesOf(file);
        if (!coverData.isEmpty()) {
            QString coverPath;
            if (saveCover(coverData, absfpath, coverPath)) {
                rec.insert(QStringLiteral("coverPath"), coverPath);
                /* QML 侧直接用它, 免得自己拼 file:// 与百分号转义 */
                rec.insert(QStringLiteral("coverUrl"), QUrl::fromLocalFile(coverPath).toString());
                rec.insert(QStringLiteral("hasCover"), true);
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
        rec.insert(QStringLiteral("ok"), true);
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
            return false;
        }
        QImage image;
        if (!image.loadFromData(data)) {
            qWarning() << "AppSongFileHelper saveCover failed: image cannot be decoded" << absfpath;
            return false;
        }
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
    static QByteArray coverBytesOf(TagLib::File *file) {
        if (auto *mpeg = dynamic_cast<TagLib::MPEG::File *>(file)) {
            return (mpeg->hasID3v2Tag() ? apicBytes(mpeg->ID3v2Tag()) : QByteArray());
        }
        if (auto *vorbis = dynamic_cast<TagLib::Ogg::Vorbis::File *>(file)) {
            return xiphCoverBytes(vorbis->tag());
        }
        if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(file)) {
            const TagLib::List<TagLib::FLAC::Picture *> pictures = flac->pictureList();
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
            return (wav->hasID3v2Tag() ? apicBytes(wav->ID3v2Tag()) : QByteArray());
        }
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
                id3Lyrics(mpeg->ID3v2Tag(), uslt, sylt);
            }
        } else if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) {
            if (wav->hasID3v2Tag()) {
                id3Lyrics(wav->ID3v2Tag(), uslt, sylt);
            }
        } else if (auto *vorbis = dynamic_cast<TagLib::Ogg::Vorbis::File *>(file)) {
            uslt = xiphLyrics(vorbis->tag());
        } else if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(file)) {
            uslt = xiphLyrics(flac->xiphComment());
        } else if (auto *mp4 = dynamic_cast<TagLib::MP4::File *>(file)) {
            if (mp4->tag() != nullptr) {
                const TagLib::MP4::Item item = mp4->tag()->item(tagKey(QStringLiteral("©lyr")));
                const TagLib::StringList values = item.toStringList();
                if (!values.isEmpty()) {
                    uslt = fromTagString(values.front());
                }
            }
        }
        if (!sylt.isEmpty()) {
            elrc = sylt;
        }
        if (!uslt.isEmpty()) {
            plain = plainToLrc(uslt, durationMs);
        }
    }

    /* ID3v2 里的 USLT 与 SYLT: SYLT 直接转成 ELRC 文本 */
    static void id3Lyrics(TagLib::ID3v2::Tag *tag, QString &uslt, QString &sylt) {
        if (tag == nullptr) {
            return;
        }
        const TagLib::ID3v2::FrameList usltFrames = tag->frameList("USLT");
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
    static QString xiphLyrics(TagLib::Ogg::XiphComment *tag) {
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

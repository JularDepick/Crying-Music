#ifndef APPFILEHELPER_H
#define APPFILEHELPER_H

#include <QObject>
#include <QUrl>
#include <QFile>
#include <QSaveFile>
#include <QDir>
#include <QFileInfo>
#include <QStringList>
#include <QStringConverter>
#include <QCryptographicHash>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QMediaPlayer>
#include <QMediaMetaData>
#include <QTimer>
#include <QImage>
#include <QBuffer>
#include <qdebug.h>

class AppFileHelper : public QObject {
    Q_OBJECT
public:
    explicit AppFileHelper(QObject *parent=nullptr):QObject(parent) {}

    /* 判断目录是否存在: 入参为绝对路径带 file:/// */
    Q_INVOKABLE bool existsDir(const QUrl &url) const {
        return QFileInfo(url.toLocalFile()).isDir();
    }

    /* 判断文件是否存在: 入参为绝对路径带 file:/// */
    Q_INVOKABLE bool existsFile(const QUrl &url) const {
        return QFile::exists(url.toLocalFile());
    }

    /* 判断目录是否可读: 入参为标准化绝对路径;
     * 目录不存在或当前进程无读取权限时返回 false。 */
    Q_INVOKABLE bool canReadDir(const QUrl &url) const {
        const QString path = url.toLocalFile();
        if (path.isEmpty()) {
            qWarning() << "AppFileHelper canReadDir failed: empty path";
            return false;
        }
        const QFileInfo info(path);
        return (info.exists() && info.isDir() && info.isReadable());
    }

    /* 判断目录是否可写: 入参为标准化绝对路径;
     * 目录不存在时返回 false, 创建目录请先用 makeDir;
     * 判定方式为在目录内建立临时文件后立即删除, 因此能反映真实的写入权限。 */
    Q_INVOKABLE bool canWriteDir(const QUrl &url) const {
        const QString path = url.toLocalFile();
        if (path.isEmpty()) {
            qWarning() << "AppFileHelper canWriteDir failed: empty path";
            return false;
        }
        const QDir dir(path);
        if (!dir.exists()) {
            return false;
        }
        const QString probePath = dir.absoluteFilePath(QStringLiteral(".cryingmusic_write_probe"));
        QFile probe(probePath);
        if (!probe.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            return false;
        }
        probe.close();
        return QFile::remove(probePath);
    }

    /* 标准化路径(仅面向外部输入):
     * 入参为非标准化的绝对路径,不接受相对路径;
     * 可能带也可能不带 file:// 协议头,可能包含反斜杠;
     * 返回带 file:/// 的绝对路径,反斜杠变为普通斜杠,返回值兼容 QUrl;
     * 除根目录外,标准化路径无末位斜杠,失败返回空字符串。 */
    Q_INVOKABLE QString formatPath(const QString &path) const {
        QString local = path.trimmed();
        if (local.isEmpty()) {
            qWarning() << "AppFileHelper formatPath failed: empty path";
            return {};
        }
        if (local.startsWith("file:", Qt::CaseInsensitive)) {
            const QUrl url(local);
            if (!url.isValid() || url.scheme().compare("file", Qt::CaseInsensitive) != 0) {
                qWarning() << "AppFileHelper formatPath failed: invalid file url" << path;
                return {};
            }
            local = url.toLocalFile();
        }
        local.replace('\\', '/');
        if (!QDir::isAbsolutePath(local)) {
            qWarning() << "AppFileHelper formatPath failed: not an absolute path" << path;
            return {};
        }
        local = QDir::cleanPath(local);
        return QUrl::fromLocalFile(local).toString();
    }

    /* 清理路径(仅面向标准化路径):
     * 入参为带 file:/// 的标准化绝对路径;
     * 返回去除 file:/// 协议头后的本地绝对路径,反斜杠为普通斜杠,适合 UI 展示;
     * 失败返回空字符串。 */
    Q_INVOKABLE QString clearPath(const QUrl &url) const {
        if (!url.isValid() || url.scheme().compare("file", Qt::CaseInsensitive) != 0) {
            qWarning() << "AppFileHelper clearPath failed: invalid file url" << url;
            return {};
        }
        const QString local = url.toLocalFile();
        if (local.isEmpty()) {
            qWarning() << "AppFileHelper clearPath failed: empty path" << url;
            return {};
        }
        return QDir::cleanPath(local);
    }

    /* 获取文件大小: 入参为标准化绝对路径, 返回字节数, 失败返回 -1 */
    Q_INVOKABLE qint64 fileSize(const QUrl &url) const {
        const QFileInfo fileInfo(url.toLocalFile());
        if (!fileInfo.isFile()) {
            qWarning() << "AppFileHelper fileSize failed: " << url << " not a file";
            return -1;
        }
        return fileInfo.size();
    }

    /* 获取应用安装路径,返回标准化绝对路径 */
    Q_INVOKABLE QString getAppPath() const {
        return QUrl::fromLocalFile(QCoreApplication::applicationDirPath()).toString();
    }

    /* 获取用户目录路径:
     * Windows 系统中指 %USERPROFILE%,优先使用 Qt 跨平台方法实现;
     * 返回标准化绝对路径。 */
    Q_INVOKABLE QString getUserPath() const {
        QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
        if (home.isEmpty()) {
            home = QDir::homePath();
        }
        return QUrl::fromLocalFile(home).toString();
    }

    /* 获取应用数据目录路径:
     * 使用 Qt 跨平台方法, Windows 下对应 %APPDATA%\<org>\<app>;
     * 返回标准化绝对路径。 */
    Q_INVOKABLE QString getAppDataPath() const {
        const QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        if (path.isEmpty()) {
            qWarning() << "AppFileHelper getAppDataPath failed";
            return {};
        }
        return QUrl::fromLocalFile(path).toString();
    }

    /* 读: 入参为标准化绝对路径,默认 GBK,操作对象为非二进制文件 */
    Q_INVOKABLE QString readFile(const QUrl &url) const {
        return readFile(url, "GBK");
    }

    /* 读: 入参为标准化绝对路径,指定编码,操作对象为非二进制文件 */
    Q_INVOKABLE QString readFile(const QUrl &url, const QString &codecName) const {
        QFile fin(url.toLocalFile());
        if (!fin.open(QIODevice::ReadOnly)) {
            qWarning() << "AppFileHelper readFile failed: " << url << fin.errorString();
            return {};
        }
        const QByteArray data = fin.readAll();
        auto decoder = QStringDecoder(codecName.toUtf8().constData());
        if (!decoder.isValid()) {
            qWarning() << "AppFileHelper invalid codec: " << codecName;
            return {};
        }
        return decoder(data);
    }

    /* 写: 入参为标准化绝对路径,默认 GBK,覆写模式,操作对象为非二进制文件。
     * 若父目录不存在,会自动补全各级目录。
     * 采用原子写: 先写同目录临时文件, 校验写入字节数后再改名覆盖目标文件,
     * 因此磁盘满或中途失败时目标原文件保持原样。
     * 成功 true,失败 false。 */
    Q_INVOKABLE bool writeFile(const QUrl &url, const QString &content) const {
        return writeFile(url, content, "GBK");
    }

    /* 写: 入参为标准化绝对路径,指定编码,覆写模式,操作对象为非二进制文件。
     * 若父目录不存在,会自动补全各级目录。
     * 采用原子写, 任一步失败都返回 false 且不破坏目标原文件。
     * 成功 true,失败 false。 */
    Q_INVOKABLE bool writeFile(const QUrl &url, const QString &content, const QString &codecName) const {
        const QString filePath = url.toLocalFile();
        if (filePath.isEmpty()) {
            qWarning() << "AppFileHelper writeFile failed: empty path" << url;
            return false;
        }
        /* 编码转换先做: 编码名非法时目标文件不应被触碰 */
        auto encoder = QStringEncoder(codecName.toUtf8().constData());
        if (!encoder.isValid()) {
            qWarning() << "AppFileHelper invalid codec: " << codecName;
            return false;
        }
        const QByteArray data = encoder(content);
        /* 自动补全缺失的父目录 */
        const QDir parentDir = QFileInfo(filePath).absoluteDir();
        if (!parentDir.exists()) {
            if (!parentDir.mkpath(".")) {
                qWarning() << "AppFileHelper writeFile failed: cannot create dir "
                           << parentDir.absolutePath();
                return false;
            }
        }
        QSaveFile fout(filePath);
        if (!fout.open(QIODevice::WriteOnly)) {
            qWarning() << "AppFileHelper writeFile failed: " << url << fout.errorString();
            return false;
        }
        const qint64 written = fout.write(data);
        if (written != qint64(data.size())) {
            qWarning() << "AppFileHelper writeFile failed: short write " << url
                       << written << data.size();
            fout.cancelWriting();
            return false;
        }
        /* commit 内部会刷新并原子改名, 失败时目标文件保持原样 */
        if (!fout.commit()) {
            qWarning() << "AppFileHelper writeFile failed: cannot commit " << url
                       << fout.errorString();
            return false;
        }
        return true;
    }

    /* 新建文件夹: 入参为标准化绝对路径。
     * 默认不递归创建各级文件夹。成功 true,失败 false。 */
    Q_INVOKABLE bool makeDir(const QUrl &url) const {
        return makeDir(url, false);
    }

    /* 新建文件夹: 入参为标准化绝对路径。
     * recursive 为 true 时递归补全各级文件夹。成功 true,失败 false。 */
    Q_INVOKABLE bool makeDir(const QUrl &url, bool recursive) const {
        QDir dir;
        if (recursive) {
            return dir.mkpath(url.toLocalFile());
        }
        return dir.mkdir(url.toLocalFile());
    }

    /* 复制文件: srcPath 可以是程序资源路径(如 :/licenses/LICENSE)或本地绝对路径,
     * dstUrl 为标准化绝对路径; 目标父目录不存在时自动补全, 目标已存在时覆盖;
     * 按二进制复制, 因此不受文本编码影响。成功 true,失败 false。 */
    Q_INVOKABLE bool copyFile(const QString &srcPath, const QUrl &dstUrl) const {
        QFile fin(srcPath);
        if (!fin.open(QIODevice::ReadOnly)) {
            qWarning() << "AppFileHelper copyFile failed: cannot read " << srcPath
                       << fin.errorString();
            return false;
        }
        const QByteArray data = fin.readAll();
        fin.close();
        const QString dstPath = dstUrl.toLocalFile();
        if (dstPath.isEmpty()) {
            qWarning() << "AppFileHelper copyFile failed: empty destination";
            return false;
        }
        const QDir parentDir = QFileInfo(dstPath).absoluteDir();
        if (!parentDir.exists() && !parentDir.mkpath(".")) {
            qWarning() << "AppFileHelper copyFile failed: cannot create dir "
                       << parentDir.absolutePath();
            return false;
        }
        /* 与 writeFile 同一口径: 临时文件写完校验字节数再原子改名, 失败不破坏已有目标 */
        QSaveFile fout(dstPath);
        if (!fout.open(QIODevice::WriteOnly)) {
            qWarning() << "AppFileHelper copyFile failed: cannot write " << dstUrl
                       << fout.errorString();
            return false;
        }
        const qint64 written = fout.write(data);
        if (written != qint64(data.size())) {
            qWarning() << "AppFileHelper copyFile failed: short write " << dstUrl
                       << written << data.size();
            fout.cancelWriting();
            return false;
        }
        if (!fout.commit()) {
            qWarning() << "AppFileHelper copyFile failed: cannot commit " << dstUrl
                       << fout.errorString();
            return false;
        }
        return true;
    }

    /* 删除文件: 入参为标准化绝对路径, 文件本就不存在时视为成功 */
    Q_INVOKABLE bool removeFile(const QUrl &url) const {
        const QString path = url.toLocalFile();
        if (path.isEmpty() || !QFile::exists(path)) {
            return true;
        }
        if (!QFile::remove(path)) {
            qWarning() << "AppFileHelper removeFile failed: " << url;
            return false;
        }
        return true;
    }

    /* 删除文件夹: 入参为标准化绝对路径, recursive 为 true 时连同其中内容一起删除,
     * 调用方需自行确认路径, 该操作不可撤销。文件夹本就不存在时视为成功。 */
    Q_INVOKABLE bool removeDir(const QUrl &url, bool recursive) const {
        const QString path = url.toLocalFile();
        if (path.isEmpty()) {
            return true;
        }
        QDir dir(path);
        if (!dir.exists()) {
            return true;
        }
        if (recursive) {
            return dir.removeRecursively();
        }
        return dir.remove(path);
    }

    /* 列出: 入参为标准化绝对路径,返回直接子文件标准化绝对路径列表 */
    Q_INVOKABLE QStringList listFiles(const QUrl &url) const {
        QDir dir(url.toLocalFile());
        if (!dir.exists()) {
            qWarning() << "AppFileHelper listFiles failed: " << url << " not exists";
            return {};
        }
        const QStringList names = dir.entryList(QDir::Files, QDir::Name);
        QStringList result;
        result.reserve(names.size());
        for (const QString &name : names) {
            result << QUrl::fromLocalFile(dir.absoluteFilePath(name)).toString();
        }
        return result;
    }

    /* 列出: 入参为标准化绝对路径,按后缀过滤,返回直接子文件标准化绝对路径列表。
     * flag: 0 表示剔除指定后缀名,1 表示只要指定后缀名。
     * 后缀名列表如 .mp3、.mp4,大小写不敏感。 */
    Q_INVOKABLE QStringList listFiles(const QUrl &url, int flag, const QStringList &suffixes) const {
        if (flag != 0 && flag != 1) {
            qWarning() << "AppFileHelper listFiles failed: invalid flag " << flag;
            return {};
        }
        QDir dir(url.toLocalFile());
        if (!dir.exists()) {
            qWarning() << "AppFileHelper listFiles failed: " << url << " not exists";
            return {};
        }
        const QStringList names = dir.entryList(QDir::Files, QDir::Name);
        QStringList result;
        result.reserve(names.size());
        for (const QString &name : names) {
            const QString suffix = QFileInfo(name).suffix();
            bool match = false;
            for (const QString &item : suffixes) {
                QString target = item;
                if (target.startsWith('.')) {
                    target.remove(0, 1);
                }
                if (suffix.compare(target, Qt::CaseInsensitive) == 0) {
                    match = true;
                    break;
                }
            }
            if ((flag == 1 && match) || (flag == 0 && !match)) {
                result << QUrl::fromLocalFile(dir.absoluteFilePath(name)).toString();
            }
        }
        return result;
    }

    /* 列出: 入参为标准化绝对路径,返回直接子文件夹标准化绝对路径列表 */
    Q_INVOKABLE QStringList listDirs(const QUrl &url) const {
        QDir dir(url.toLocalFile());
        if (!dir.exists()) {
            qWarning() << "AppFileHelper listDirs failed: " << url << " not exists";
            return {};
        }
        const QStringList names = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
        QStringList result;
        result.reserve(names.size());
        for (const QString &name : names) {
            result << QUrl::fromLocalFile(dir.absoluteFilePath(name)).toString();
        }
        return result;
    }

    /* SHA-256 摘要: 入参为待摘要的文本, 回 64 位十六进制小写串 */
    Q_INVOKABLE QString sha256Hex(const QString &text) const {
        return QString::fromLatin1(
            QCryptographicHash::hash(text.toUtf8(), QCryptographicHash::Sha256).toHex());
    }

    /* HMAC-SHA256: 入参为密钥与待签文本, 回 64 位十六进制小写串,
     * 客户端与服务端按同一口径算登录凭证的签名 */
    Q_INVOKABLE QString hmacSha256Hex(const QString &key, const QString &message) const {
        constexpr int blockSize = 64;
        QByteArray k = key.toUtf8();
        if (k.size() > blockSize) {
            k = QCryptographicHash::hash(k, QCryptographicHash::Sha256);
        }
        k = k.leftJustified(blockSize, '\0', true);
        QByteArray innerPad(blockSize, '\0');
        QByteArray outerPad(blockSize, '\0');
        for (int i = 0; i < blockSize; ++i) {
            innerPad[i] = static_cast<char>(k.at(i) ^ 0x36);
            outerPad[i] = static_cast<char>(k.at(i) ^ 0x5c);
        }
        const QByteArray inner =
            QCryptographicHash::hash(innerPad + message.toUtf8(), QCryptographicHash::Sha256);
        const QByteArray outer =
            QCryptographicHash::hash(outerPad + inner, QCryptographicHash::Sha256);
        return QString::fromLatin1(outer.toHex());
    }

    /* 读取音频元数据(兜底): 入参为标准化绝对路径, 异步返回;
     * 结果由 audioMetaReady 信号给出, 超时或无法解析时时长为 -1;
     * 顺带把内嵌封面落盘, 结果由 audioCoverReady 单独给出 */
    Q_INVOKABLE void readAudioMeta(const QUrl &url) {
        if (!QFile::exists(url.toLocalFile())) {
            qWarning() << "AppFileHelper readAudioMeta failed: " << url << " not exists";
            emit audioMetaReady(url.toString(), -1, QString(), QString());
            return;
        }
        ensureMetaReader();
        metaAbsfpath = url.toString();
        metaPlayer->setSource(url);
        metaTimeout->start();
    }

    /* 读取内嵌封面: 入参为标准化绝对路径, 异步返回;
     * 已缓存时立刻回缓存路径, 否则排队交给内部播放器读取 QMediaMetaData 的 CoverArtImage,
     * 只加载媒体头不播放, 队列与超时都在类内管理, 因此不会卡住界面线程;
     * 结果由 audioCoverReady 信号给出, 该文件没有内嵌封面时封面路径为空字符串 */
    Q_INVOKABLE void readAudioCover(const QUrl &url) {
        const QString absfpath = url.toString();
        const QString local = url.toLocalFile();
        if (local.isEmpty() || !QFile::exists(local)) {
            qWarning() << "AppFileHelper readAudioCover failed: " << url << " not exists";
            emit audioCoverReady(absfpath, QString());
            return;
        }
        /* 缓存命中: 不占用播放器, 直接回路径 */
        const QString cached = cachedCoverPath(url);
        if (!cached.isEmpty()) {
            emit audioCoverReady(absfpath, cached);
            return;
        }
        if (coverAbsfpath == absfpath || coverQueue.contains(absfpath)) {
            return;
        }
        coverQueue.append(absfpath);
        pumpCoverQueue();
    }

    /* 本地内嵌封面的缓存目录: 供 QML 交给 AppSongFileHelper 落盘封面用;
     * 与内嵌封面缓存是同一个目录, 因此两边写出的文件名不会分叉 */
    Q_INVOKABLE QString localCoverDir() const {
        return coverCacheDir();
    }

    /* 已缓存的内嵌封面路径: 入参为标准化绝对路径, 返回封面文件的标准化绝对路径,
     * 没有缓存时返回空字符串; 供列表构造时同步取用, 不触发读取 */
    Q_INVOKABLE QString cachedCoverPath(const QUrl &url) const {
        const QString path = coverCachePathOf(url.toString());
        if (path.isEmpty() || !QFile::exists(path)) {
            return {};
        }
        return QUrl::fromLocalFile(path).toString();
    }

    /* 读取内嵌歌词: 入参为标准化绝对路径与该曲时长(毫秒), 同步返回 LRC 文本;
     * 只解析 MP3 的 ID3v2.3 与 ID3v2.4 里的 USLT(非同步歌词)与 SYLT(同步歌词),
     * 输出与在线歌词同一套带时间戳的 LRC, 歌词页可以直接复用;
     * SYLT 自带毫秒时间戳时直接转写, 只有 USLT 时按歌词行把整曲时长均分补出时间戳,
     * 时长未知时无法定位歌词行, 返回空字符串;
     * 只按帧长跳跃读取标签头, 内嵌封面这类大帧不会被读进内存, 解析不认识时同样返回空字符串 */
    Q_INVOKABLE QString readAudioLyrics(const QUrl &url, qint64 durationMs) const {
        const QString local = url.toLocalFile();
        if (local.isEmpty()) {
            return {};
        }
        QFile fin(local);
        if (!fin.open(QIODevice::ReadOnly)) {
            qWarning() << "AppFileHelper readAudioLyrics failed: " << url << fin.errorString();
            return {};
        }
        /* ID3v2 标签头固定十个字节: 标识, 主版本, 副版本, 标志, 同步安全整数表示的标签体长度 */
        unsigned char head[10] = {0};
        if (!readBytes(fin, head, 10) || head[0] != 'I' || head[1] != 'D' || head[2] != '3') {
            return {};
        }
        /* 只做 2.3 与 2.4: 2.2 的帧头是三字节, 结构与这里不同 */
        const int version = int(head[3]);
        if (version != 3 && version != 4) {
            return {};
        }
        const unsigned char flags = head[5];
        qint64 bodySize = qint64(syncSafeInt(head + 6));
        if (bodySize <= 0) {
            return {};
        }
        bodySize = qMin(bodySize, qMin<qint64>(fin.size() - 10, id3BodyLimit));
        if (bodySize <= 0) {
            return {};
        }
        QString uslt;
        QString sylt;
        if ((flags & 0x80) != 0) {
            /* 整个标签体做过去同步化: 读进内存还原字节后按帧扫描, 标签体大小已有上限 */
            const QByteArray raw = fin.read(bodySize);
            QByteArray body = removeUnsynchronisation(raw);
            QBuffer buffer(&body);
            if (buffer.open(QIODevice::ReadOnly)) {
                scanId3Frames(buffer, version, flags, uslt, sylt);
            }
        } else {
            /* 常见的无去同步化标签直接按帧长跳跃扫描, 只读 USLT 与 SYLT 两个帧 */
            scanId3Frames(fin, version, flags, uslt, sylt);
        }
        /* 同步歌词自带真实时间轴, 优先用它; 没有时再用非同步歌词均分补时间戳 */
        if (!sylt.isEmpty()) {
            return sylt;
        }
        return usltToLrc(uslt, durationMs);
    }

signals:
    /* 音频元数据读取结果: 标准化路径, 时长毫秒, 曲名, 歌手 */
    void audioMetaReady(const QString &absfpath, qint64 duration, const QString &title, const QString &artist);

    /* 内嵌封面读取结果: 标准化路径, 封面文件标准化路径(该文件没有内嵌封面时为空字符串) */
    void audioCoverReady(const QString &absfpath, const QString &coverPath);

private:
    /* 元数据兜底读取的超时阈值(毫秒) */
    static constexpr int metaTimeoutMs = 3000;
    QMediaPlayer *metaPlayer=nullptr;
    QTimer *metaTimeout=nullptr;
    QString metaAbsfpath;
    /* 内嵌封面读取的超时阈值(毫秒): 与元数据兜底同一口径 */
    static constexpr int coverTimeoutMs = 3000;
    /* ID3v2 标签体整体读取上限: 只有整标签去同步化时才整体读, 正常标签按帧长跳跃, 不受此限 */
    static constexpr qint64 id3BodyLimit = 8 * 1024 * 1024;
    /* 单个 ID3 帧的解析上限: 超过上限的帧按不关心处理 */
    static constexpr int id3FrameLimit = 4 * 1024 * 1024;
    QMediaPlayer *coverPlayer=nullptr;
    QTimer *coverTimeout=nullptr;
    /* 正在读取封面的文件: 为空表示播放器空闲 */
    QString coverAbsfpath;
    QStringList coverQueue;

    /* 首次使用时创建元数据读取器 */
    void ensureMetaReader() {
        if (metaPlayer != nullptr) {
            return;
        }
        metaPlayer = new QMediaPlayer(this);
        metaTimeout = new QTimer(this);
        metaTimeout->setSingleShot(true);
        metaTimeout->setInterval(metaTimeoutMs);
        connect(metaPlayer, &QMediaPlayer::mediaStatusChanged,
                this, &AppFileHelper::onMetaStatusChanged);
        connect(metaTimeout, &QTimer::timeout, this, &AppFileHelper::onMetaTimeout);
    }

    /* 元数据读取状态变化: 只关心加载完成与无法解析 */
    void onMetaStatusChanged(QMediaPlayer::MediaStatus status) {
        if (status != QMediaPlayer::LoadedMedia
            && status != QMediaPlayer::BufferedMedia
            && status != QMediaPlayer::InvalidMedia) {
            return;
        }
        metaTimeout->stop();
        if (status == QMediaPlayer::InvalidMedia) {
            qWarning() << "AppFileHelper readAudioMeta failed: " << metaAbsfpath;
            emit audioMetaReady(metaAbsfpath, -1, QString(), QString());
            return;
        }
        const QMediaMetaData meta = metaPlayer->metaData();
        emit audioMetaReady(metaAbsfpath,
                            metaPlayer->duration(),
                            meta.stringValue(QMediaMetaData::Title),
                            readArtist(meta));
        /* 兜底读取已经加载了同一个文件, 顺带把内嵌封面落盘, 结果走封面信号 */
        emitEmbeddedCover(metaAbsfpath, meta);
    }

    /* 元数据读取超时: 按无法解析返回 */
    void onMetaTimeout() {
        qWarning() << "AppFileHelper readAudioMeta timeout: " << metaAbsfpath;
        emit audioMetaReady(metaAbsfpath, -1, QString(), QString());
    }

    /* 歌手优先取贡献艺术家, 依次回退到专辑艺术家与作者 */
    static QString readArtist(const QMediaMetaData &meta) {
        const QVariant artists = meta.value(QMediaMetaData::ContributingArtist);
        const QStringList artistList = artists.toStringList();
        if (!artistList.isEmpty()) {
            return artistList.join(", ");
        }
        if (!artists.toString().isEmpty()) {
            return artists.toString();
        }
        const QString albumArtist = meta.stringValue(QMediaMetaData::AlbumArtist);
        if (!albumArtist.isEmpty()) {
            return albumArtist;
        }
        return meta.stringValue(QMediaMetaData::Author);
    }

    /* 应用缓存目录下的封面目录: 与在线封面缓存同名同构, 但单独放在应用缓存目录下,
     * 不参与在线封面按生命周期做的清理; 缓存目录取不到时退化到应用数据目录 */
    static QString coverCacheDir() {
        QString root = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        if (root.isEmpty()) {
            root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        }
        if (root.isEmpty()) {
            return {};
        }
        const QString path = root + QStringLiteral("/covers");
        if (!QDir().mkpath(path)) {
            qWarning() << "AppFileHelper coverCacheDir failed: cannot create " << path;
            return {};
        }
        return path;
    }

    /* 某音频文件的内嵌封面缓存路径: 文件名沿用缓存命名习惯, 用路径摘要做键,
     * 保证同一个文件每次得到同一个名字, 不同文件之间不会互相覆盖 */
    static QString coverCachePathOf(const QString &absfpath) {
        const QString dir = coverCacheDir();
        if (dir.isEmpty() || absfpath.isEmpty()) {
            return {};
        }
        const QString key = QString::fromLatin1(
            QCryptographicHash::hash(absfpath.toUtf8(), QCryptographicHash::Sha256).toHex().left(16));
        return dir + QStringLiteral("/local_") + key + QStringLiteral(".png");
    }

    /* 内嵌封面落盘: 与 writeFile 同一口径的原子写, 中途失败不会留下半张图,
     * 也不会出现目标文件已被删除而新文件尚未就位的空档 */
    static bool saveCoverImage(const QString &absfpath, const QImage &image) {
        if (image.isNull()) {
            return false;
        }
        const QString path = coverCachePathOf(absfpath);
        if (path.isEmpty()) {
            return false;
        }
        QSaveFile out(path);
        if (!out.open(QIODevice::WriteOnly)) {
            qWarning() << "AppFileHelper saveCoverImage failed: cannot open " << path
                       << out.errorString();
            return false;
        }
        if (!image.save(&out, "PNG")) {
            qWarning() << "AppFileHelper saveCoverImage failed: cannot write " << path;
            out.cancelWriting();
            return false;
        }
        if (!out.commit()) {
            qWarning() << "AppFileHelper saveCoverImage failed: cannot commit " << path
                       << out.errorString();
            return false;
        }
        return true;
    }

    /* 从元数据里取内嵌封面: 先取封面图, 没有再退到缩略图, 都没有时返回空图像 */
    static QImage readCoverImage(const QMediaMetaData &meta) {
        const QImage cover = meta.value(QMediaMetaData::CoverArtImage).value<QImage>();
        if (!cover.isNull()) {
            return cover;
        }
        return meta.value(QMediaMetaData::ThumbnailImage).value<QImage>();
    }

    /* 内嵌封面落盘并回报: 已有缓存时不重复写 */
    void emitEmbeddedCover(const QString &absfpath, const QMediaMetaData &meta) {
        if (absfpath.isEmpty() || !cachedCoverPath(QUrl(absfpath)).isEmpty()) {
            return;
        }
        if (!saveCoverImage(absfpath, readCoverImage(meta))) {
            return;
        }
        emit audioCoverReady(absfpath, QUrl::fromLocalFile(coverCachePathOf(absfpath)).toString());
    }

    /* 首次使用时创建内嵌封面读取器 */
    void ensureCoverReader() {
        if (coverPlayer != nullptr) {
            return;
        }
        coverPlayer = new QMediaPlayer(this);
        coverTimeout = new QTimer(this);
        coverTimeout->setSingleShot(true);
        coverTimeout->setInterval(coverTimeoutMs);
        connect(coverPlayer, &QMediaPlayer::mediaStatusChanged,
                this, &AppFileHelper::onCoverStatusChanged);
        connect(coverTimeout, &QTimer::timeout, this, &AppFileHelper::onCoverTimeout);
    }

    /* 封面队列调度: 同一时刻只让一个文件占用播放器, 空闲时取下一项 */
    void pumpCoverQueue() {
        if (coverPlayer != nullptr && !coverAbsfpath.isEmpty()) {
            return;
        }
        if (coverQueue.isEmpty()) {
            return;
        }
        ensureCoverReader();
        coverAbsfpath = coverQueue.takeFirst();
        coverTimeout->start();
        coverPlayer->setSource(QUrl(coverAbsfpath));
    }

    /* 封面读取状态变化: 只关心加载完成与无法解析 */
    void onCoverStatusChanged(QMediaPlayer::MediaStatus status) {
        if (coverAbsfpath.isEmpty()) {
            return;
        }
        if (status != QMediaPlayer::LoadedMedia
            && status != QMediaPlayer::BufferedMedia
            && status != QMediaPlayer::InvalidMedia) {
            return;
        }
        coverTimeout->stop();
        const QString absfpath = coverAbsfpath;
        coverAbsfpath.clear();
        QString coverPath;
        if (status != QMediaPlayer::InvalidMedia) {
            const QMediaMetaData meta = coverPlayer->metaData();
            if (saveCoverImage(absfpath, readCoverImage(meta))) {
                coverPath = QUrl::fromLocalFile(coverCachePathOf(absfpath)).toString();
            }
        }
        /* 先放开播放器再回调, 下一个文件接着读 */
        coverPlayer->setSource(QUrl());
        emit audioCoverReady(absfpath, coverPath);
        pumpCoverQueue();
    }

    /* 封面读取超时: 按没有内嵌封面处理, 继续队列 */
    void onCoverTimeout() {
        if (coverAbsfpath.isEmpty()) {
            return;
        }
        const QString absfpath = coverAbsfpath;
        coverAbsfpath.clear();
        qWarning() << "AppFileHelper readAudioCover timeout: " << absfpath;
        coverPlayer->setSource(QUrl());
        emit audioCoverReady(absfpath, QString());
        pumpCoverQueue();
    }

    /* 读满指定字节数: 文件提前结束时返回 false */
    static bool readBytes(QIODevice &device, void *dst, int size) {
        if (size <= 0) {
            return false;
        }
        return (device.read(static_cast<char *>(dst), size) == size);
    }

    /* 同步安全整数: 每个字节只用低七位, 用于标签体长度与 2.4 的帧长 */
    static int syncSafeInt(const unsigned char *data) {
        return (int(data[0] & 0x7f) << 21) | (int(data[1] & 0x7f) << 14)
               | (int(data[2] & 0x7f) << 7) | int(data[3] & 0x7f);
    }

    /* 大端四字节整数: 2.3 的帧长与扩展头长度 */
    static int bigEndianInt(const unsigned char *data) {
        return (int(data[0]) << 24) | (int(data[1]) << 16) | (int(data[2]) << 8) | int(data[3]);
    }

    /* 去同步化还原: 每个 0xff 后面插入的 0x00 一律去掉 */
    static QByteArray removeUnsynchronisation(const QByteArray &raw) {
        QByteArray out;
        out.reserve(raw.size());
        const int n = int(raw.size());
        for (int i = 0; i < n; ++i) {
            out.append(raw.at(i));
            if (static_cast<unsigned char>(raw.at(i)) == 0xff && i + 1 < n
                && raw.at(i + 1) == '\0') {
                ++i;
            }
        }
        return out;
    }

    /* 帧标识是否由大写字母与数字组成 */
    static bool isFrameId(const QByteArray &id) {
        if (id.size() != 4) {
            return false;
        }
        for (int i = 0; i < 4; ++i) {
            const char c = id.at(i);
            const bool upper = (c >= 'A' && c <= 'Z');
            const bool digit = (c >= '0' && c <= '9');
            if (!upper && !digit) {
                return false;
            }
        }
        return true;
    }

    /* 逐帧扫描标签体: 只取 USLT 与 SYLT 的载荷, 其余帧按帧长跳过, 帧头不合法即停止 */
    static void scanId3Frames(QIODevice &body, int version, unsigned char flags,
                              QString &uslt, QString &sylt) {
        /* 扩展头: 2.3 的长度不含自身四字节, 2.4 为同步安全整数且含自身四字节 */
        if ((flags & 0x40) != 0) {
            unsigned char ext[4] = {0};
            if (!readBytes(body, ext, 4)) {
                return;
            }
            const int extSize = (version == 4 ? syncSafeInt(ext) : bigEndianInt(ext));
            const qint64 skip = (version == 4 ? qint64(extSize) - 4 : qint64(extSize));
            if (extSize < 0 || skip < 0) {
                return;
            }
            if (!body.seek(body.pos() + skip)) {
                return;
            }
        }
        while (true) {
            unsigned char frameHead[10] = {0};
            if (!readBytes(body, frameHead, 10)) {
                return;
            }
            /* 帧标识为空即进入填充区, 后面不会再有帧 */
            if (frameHead[0] == 0) {
                return;
            }
            const QByteArray frameId(reinterpret_cast<const char *>(frameHead), 4);
            if (!isFrameId(frameId)) {
                return;
            }
            const int frameSize = (version == 4 ? syncSafeInt(frameHead + 4)
                                                : bigEndianInt(frameHead + 4));
            if (frameSize <= 0) {
                return;
            }
            /* 帧格式标志: 压缩, 加密, 分组, 逐帧去同步化与带数据长度指示的帧都不按明文解析 */
            const unsigned char formatFlags = frameHead[9];
            const bool opaque = (version == 3
                                 ? ((formatFlags & 0xc0) != 0 || (formatFlags & 0x20) != 0)
                                 : ((formatFlags & 0x4f) != 0));
            const bool wanted = (frameId == "USLT" || frameId == "SYLT");
            if (!opaque && wanted && frameSize <= id3FrameLimit) {
                const QByteArray payload = body.read(frameSize);
                if (payload.size() != frameSize) {
                    return;
                }
                if (frameId == "USLT" && uslt.isEmpty()) {
                    uslt = parseUslt(payload);
                } else if (frameId == "SYLT" && sylt.isEmpty()) {
                    sylt = parseSylt(payload);
                }
            } else if (!body.seek(body.pos() + frameSize)) {
                return;
            }
            if (!uslt.isEmpty() && !sylt.isEmpty()) {
                return;
            }
        }
    }

    /* 读一个以零字节结尾的 ID3 字符串: 读完后 pos 落在结尾符之后, 没有结尾符时读到末尾 */
    static QString readId3String(const QByteArray &data, int &pos, int encoding) {
        /* UTF-16 的结尾符是两个字节, 其余编码是一个字节 */
        const int unit = ((encoding == 1 || encoding == 2) ? 2 : 1);
        const int n = int(data.size());
        int end = pos;
        while (end + unit <= n) {
            bool zero = true;
            for (int i = 0; i < unit; ++i) {
                if (data.at(end + i) != '\0') {
                    zero = false;
                    break;
                }
            }
            if (zero) {
                break;
            }
            end += unit;
        }
        const QString text = decodeId3Text(data.mid(pos, end - pos), encoding);
        pos = int(qMin(qint64(n), qint64(end + unit)));
        return text;
    }

    /* 按 ID3 的编码字节解码文本: 0 为 ISO-8859-1, 1 为带 BOM 的 UTF-16, 2 为 UTF-16BE, 3 为 UTF-8 */
    static QString decodeId3Text(const QByteArray &raw, int encoding) {
        if (raw.isEmpty()) {
            return {};
        }
        QString text;
        if (encoding == 1) {
            /* UTF-16 由 BOM 定字节序, 没有 BOM 时按小端处理 */
            QByteArray body = raw;
            QStringConverter::Encoding order = QStringConverter::Utf16LE;
            if (body.size() >= 2) {
                const unsigned char b0 = static_cast<unsigned char>(body.at(0));
                const unsigned char b1 = static_cast<unsigned char>(body.at(1));
                if (b0 == 0xfe && b1 == 0xff) {
                    order = QStringConverter::Utf16BE;
                    body.remove(0, 2);
                } else if (b0 == 0xff && b1 == 0xfe) {
                    order = QStringConverter::Utf16LE;
                    body.remove(0, 2);
                }
            }
            QStringDecoder decoder(order);
            text = decoder(body);
        } else if (encoding == 2) {
            QStringDecoder decoder(QStringConverter::Utf16BE);
            text = decoder(raw);
        } else if (encoding == 3) {
            QStringDecoder decoder(QStringConverter::Utf8);
            text = decoder(raw);
        } else {
            QStringDecoder decoder(QStringConverter::Latin1);
            text = decoder(raw);
        }
        /* 去掉解码可能留下的 BOM 与零填充 */
        if (text.startsWith(QChar(u'\ufeff'))) {
            text.remove(0, 1);
        }
        while (text.endsWith(QChar(u'\0'))) {
            text.chop(1);
        }
        return text;
    }

    /* USLT 帧解析: 编码字节, 三字节语言, 内容描述, 正文 */
    static QString parseUslt(const QByteArray &payload) {
        if (payload.size() <= 4) {
            return {};
        }
        const int encoding = int(static_cast<unsigned char>(payload.at(0)));
        if (encoding > 3) {
            return {};
        }
        int pos = 4;
        /* 内容描述不用, 但必须按编码宽度跳过去 */
        readId3String(payload, pos, encoding);
        return normalizeLyricText(decodeId3Text(payload.mid(pos), encoding));
    }

    /* SYLT 帧解析: 编码字节, 三字节语言, 时间格式, 内容类型, 内容描述, 之后是若干(文本, 四字节时间)对 */
    static QString parseSylt(const QByteArray &payload) {
        if (payload.size() < 7) {
            return {};
        }
        const int encoding = int(static_cast<unsigned char>(payload.at(0)));
        if (encoding > 3) {
            return {};
        }
        /* 时间格式 1 表示 MPEG 帧号, 没有帧率换算成毫秒, 这一档直接放弃 */
        const int timeFormat = int(static_cast<unsigned char>(payload.at(4)));
        if (timeFormat != 2) {
            return {};
        }
        int pos = 6;
        readId3String(payload, pos, encoding);
        QString lrc;
        while (pos < payload.size()) {
            const QString text = readId3String(payload, pos, encoding);
            if (pos + 4 > payload.size()) {
                break;
            }
            const qint64 stamp = (qint64(static_cast<unsigned char>(payload.at(pos))) << 24)
                                 | (qint64(static_cast<unsigned char>(payload.at(pos + 1))) << 16)
                                 | (qint64(static_cast<unsigned char>(payload.at(pos + 2))) << 8)
                                 | qint64(static_cast<unsigned char>(payload.at(pos + 3)));
            pos += 4;
            const QString line = text.trimmed();
            if (line.isEmpty()) {
                continue;
            }
            lrc.append(lrcStamp(stamp));
            lrc.append(line);
            lrc.append(QLatin1Char('\n'));
        }
        return lrc;
    }

    /* LRC 时间戳: [分:秒.百分秒] */
    static QString lrcStamp(qint64 ms) {
        const qint64 safe = (ms > 0 ? ms : 0);
        return QStringLiteral("[%1:%2.%3]")
            .arg(safe / 60000, 2, 10, QLatin1Char('0'))
            .arg((safe % 60000) / 1000, 2, 10, QLatin1Char('0'))
            .arg((safe % 1000) / 10, 2, 10, QLatin1Char('0'));
    }

    /* 歌词正文按行归一: 去掉回车与行首尾空白, 丢掉空行 */
    static QStringList splitLyricLines(const QString &text) {
        QStringList lines;
        const QStringList raw = text.split(QLatin1Char('\n'));
        for (const QString &one : raw) {
            QString line = one;
            line.remove(QLatin1Char('\r'));
            line = line.trimmed();
            if (!line.isEmpty()) {
                lines.append(line);
            }
        }
        return lines;
    }

    /* 歌词正文归一: 按行去空白并丢掉空行, 再用换行拼回 */
    static QString normalizeLyricText(const QString &text) {
        const QStringList lines = splitLyricLines(text);
        QString out;
        for (const QString &line : lines) {
            out.append(line);
            out.append(QLatin1Char('\n'));
        }
        return out;
    }

    /* 歌词正文是否已经是 LRC: 找一行形如 [分:秒] 或 [分:秒.小数] 的时间戳 */
    static bool hasLrcStamp(const QStringList &lines) {
        for (const QString &line : lines) {
            const int open = line.indexOf(QLatin1Char('['));
            if (open < 0) {
                continue;
            }
            const int colon = line.indexOf(QLatin1Char(':'), open + 1);
            const int close = line.indexOf(QLatin1Char(']'), open + 1);
            if (colon <= open + 1 || close <= colon + 1) {
                continue;
            }
            bool okMin = false;
            bool okSec = false;
            const QString minPart = line.mid(open + 1, colon - open - 1);
            QString secPart = line.mid(colon + 1, close - colon - 1);
            const int dot = secPart.indexOf(QLatin1Char('.'));
            if (dot >= 0) {
                secPart = secPart.left(dot);
            }
            minPart.toInt(&okMin);
            secPart.toInt(&okSec);
            if (okMin && okSec && minPart.size() <= 3 && secPart.size() <= 2) {
                return true;
            }
        }
        return false;
    }

    /* 非同步歌词转 LRC: 正文自带时间戳时原样输出, 否则把歌词行均分到整曲时长上补时间戳;
     * 时长未知时补不出时间戳, 无时间戳的歌词既无法定位也不能写进歌词缓存, 因此返回空字符串 */
    static QString usltToLrc(const QString &text, qint64 durationMs) {
        const QStringList lines = splitLyricLines(text);
        if (lines.isEmpty()) {
            return {};
        }
        if (hasLrcStamp(lines)) {
            QString lrc;
            for (const QString &line : lines) {
                lrc.append(line);
                lrc.append(QLatin1Char('\n'));
            }
            return lrc;
        }
        if (durationMs <= 0) {
            return {};
        }
        const int count = int(lines.size());
        QString lrc;
        for (int i = 0; i < count; ++i) {
            lrc.append(lrcStamp(durationMs * i / count));
            lrc.append(lines.at(i));
            lrc.append(QLatin1Char('\n'));
        }
        return lrc;
    }
};

#endif
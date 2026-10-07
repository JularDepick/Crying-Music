#ifndef APPFILEHELPER_H
#define APPFILEHELPER_H

#include <QObject>
#include <QUrl>
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QStringList>
#include <QStringConverter>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QMediaPlayer>
#include <QMediaMetaData>
#include <QTimer>
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
     * 成功 true,失败 false。 */
    Q_INVOKABLE bool writeFile(const QUrl &url, const QString &content) const {
        return writeFile(url, content, "GBK");
    }

    /* 写: 入参为标准化绝对路径,指定编码,覆写模式,操作对象为非二进制文件。
     * 若父目录不存在,会自动补全各级目录。
     * 成功 true,失败 false。 */
    Q_INVOKABLE bool writeFile(const QUrl &url, const QString &content, const QString &codecName) const {
        const QString filePath = url.toLocalFile();
        const QFileInfo fileInfo(filePath);
        /* 自动补全缺失的父目录 */
        const QDir parentDir = fileInfo.absoluteDir();
        if (!parentDir.exists()) {
            if (!parentDir.mkpath(".")) {
                qWarning() << "AppFileHelper writeFile failed: cannot create dir "
                           << parentDir.absolutePath();
                return false;
            }
        }
        QFile fout(filePath);
        if (!fout.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            qWarning() << "AppFileHelper writeFile failed: " << url << fout.errorString();
            return false;
        }
        auto encoder = QStringEncoder(codecName.toUtf8().constData());
        if (!encoder.isValid()) {
            qWarning() << "AppFileHelper invalid codec: " << codecName;
            return false;
        }
        const QByteArray data = encoder(content);
        return (fout.write(data) != -1);
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
        QFile fout(dstPath);
        if (!fout.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            qWarning() << "AppFileHelper copyFile failed: cannot write " << dstUrl
                       << fout.errorString();
            return false;
        }
        const bool ok = (fout.write(data) != -1);
        fout.close();
        return ok;
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

    /* 读取音频元数据(兜底): 入参为标准化绝对路径, 异步返回;
     * 结果由 audioMetaReady 信号给出, 超时或无法解析时时长为 -1。 */
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

signals:
    /* 音频元数据读取结果: 标准化路径, 时长毫秒, 曲名, 歌手 */
    void audioMetaReady(const QString &absfpath, qint64 duration, const QString &title, const QString &artist);

private:
    /* 元数据兜底读取的超时阈值(毫秒) */
    static constexpr int metaTimeoutMs = 3000;
    QMediaPlayer *metaPlayer=nullptr;
    QTimer *metaTimeout=nullptr;
    QString metaAbsfpath;

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
};

#endif
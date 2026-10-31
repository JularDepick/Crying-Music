#ifndef APPNETHELPER_H
#define APPNETHELPER_H

#include <QObject>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QSet>
#include <QDateTime>
#include <QTimer>
#include <QCoreApplication>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <qdebug.h>

/* 网络辅助类: 只做单次请求与落盘, 不做地址轮换与业务判断。
 * 图标缓存: 目标目录已有同名文件时直接回调成功, 因此同一图标只会真正下载一次;
 * 音频下载: 边收边写, 进度按时间节流上报, 取消时删除未完成的文件。
 * 地址轮换(多个备用源)由 QML 侧按 Server 单例里的候选清单依次尝试。 */
class AppNetHelper : public QObject {
    Q_OBJECT
public:
    explicit AppNetHelper(QObject *parent=nullptr):QObject(parent) {}

    /* 拉取小文件到缓存目录(封面与歌词共用): url 为完整地址, cacheKey 为本次尝试的键,
     * cacheDir 为缓存目录的标准化绝对路径, dstName 为落盘文件名(缺省与 cacheKey 相同);
     * 同一个 dstName 只认第一个写成功的响应, 其余响应即使到齐也丢弃, 因此多个备用源
     * 可以并行拉同一个文件而不会写出交错内容; 命中缓存时同样以信号回调, 调用方无需分支。 */
    Q_INVOKABLE void fetchCachedFile(const QString &url, const QString &cacheKey, const QUrl &cacheDir,
                               bool force = false, const QString &dstName = QString()) {
        const QString targetName = (dstName.isEmpty() ? cacheKey : dstName);
        if (url.isEmpty() || cacheKey.isEmpty() || cacheDir.isEmpty() || targetName.isEmpty()) {
            emit cachedFileFailed(cacheKey, QStringLiteral("参数不完整"));
            return;
        }
        const QString dirPath = cacheDir.toLocalFile();
        if (dirPath.isEmpty()) {
            emit cachedFileFailed(cacheKey, QStringLiteral("缓存目录无效"));
            return;
        }
        const QString targetPath = QDir(dirPath).absoluteFilePath(targetName);
        /* 命中缓存直接回调; 过期刷新时由调用方要求忽略缓存, 重新下载并覆盖同一文件 */
        if (!force && QFileInfo(targetPath).isFile() && QFileInfo(targetPath).size() > 0) {
            const QString localUrl = QUrl::fromLocalFile(targetPath).toString();
            QTimer::singleShot(0, this, [this, cacheKey, localUrl]() {
                emit cachedFileReady(cacheKey, localUrl);
            });
            return;
        }
        if (m_cachedFileReplies.contains(cacheKey)) {
            return;
        }
        QNetworkReply *reply = m_nam.get(buildRequest(url));
        m_cachedFileReplies.insert(cacheKey, reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply, cacheKey, targetPath, targetName]() {
            m_cachedFileReplies.remove(cacheKey);
            reply->deleteLater();
            if (reply->error()!=QNetworkReply::NoError) {
                emit cachedFileFailed(cacheKey, reply->errorString());
                return;
            }
            /* 另一个源已经写过同一个文件: 丢弃本次响应, 既不落盘也不通知成功 */
            if (m_cachedFileWon.contains(targetName)) {
                emit cachedFileFailed(cacheKey, QStringLiteral("已被其它源抢先"));
                return;
            }
            const QByteArray data = reply->readAll();
            if (data.isEmpty()) {
                emit cachedFileFailed(cacheKey, QStringLiteral("空响应"));
                return;
            }
            QDir().mkpath(QFileInfo(targetPath).absolutePath());
            QFile out(targetPath);
            if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate) || out.write(data)<0) {
                emit cachedFileFailed(cacheKey, QStringLiteral("缓存写入失败"));
                return;
            }
            out.close();
            m_cachedFileWon.insert(targetName);
            emit cachedFileReady(cacheKey, QUrl::fromLocalFile(targetPath).toString());
        });
    }

    /* 中止一次小文件拉取: 未在途时静默返回; 被中止的请求仍会以 cachedFileFailed 回调,
     * 调用方按自己是否已关闭该次尝试来决定丢弃即可 */
    Q_INVOKABLE void cancelCachedFile(const QString &cacheKey) {
        QNetworkReply *reply = m_cachedFileReplies.value(cacheKey);
        if (reply!=nullptr) {
            reply->abort();
        }
    }

    /* 清空"该文件已有源写成功"的记录: 清理缓存时调用, 让同名文件可以重新落盘 */
    Q_INVOKABLE void clearCachedFileWon() {
        m_cachedFileWon.clear();
    }

    /* 下载音频到目标位置: url 为完整地址, dstUrl 为目标文件的标准化绝对路径,
     * taskKey 由调用方给出, 后续信号都带回同一个标识; 父目录不存在时自动补全。 */
    Q_INVOKABLE void downloadAudio(const QString &url, const QUrl &dstUrl, const QString &taskKey) {
        if (url.isEmpty() || dstUrl.isEmpty() || taskKey.isEmpty()) {
            emit downloadFailed(taskKey, QStringLiteral("参数不完整"));
            return;
        }
        if (m_downloads.contains(taskKey)) {
            return;
        }
        const QString dstPath = dstUrl.toLocalFile();
        if (dstPath.isEmpty()) {
            emit downloadFailed(taskKey, QStringLiteral("目标路径无效"));
            return;
        }
        QDir().mkpath(QFileInfo(dstPath).absolutePath());
        QFile *out = new QFile(dstPath, this);
        if (!out->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            emit downloadFailed(taskKey, QStringLiteral("目标文件无法写入"));
            delete out;
            return;
        }
        DownloadTask task;
        task.file = out;
        task.dstPath = dstPath;
        task.received = 0;
        task.total = -1;
        task.cancelled = false;
        task.lastStamp = QDateTime::currentMSecsSinceEpoch();
        QNetworkReply *reply = m_nam.get(buildRequest(url));
        task.reply = reply;
        m_downloads.insert(taskKey, task);
        connect(reply, &QNetworkReply::readyRead, this, [this, reply, taskKey]() {
            writeChunk(taskKey, reply);
        });
        connect(reply, &QNetworkReply::downloadProgress, this,
                [this, taskKey](qint64 received, qint64 total) {
            emitDownloadProgress(taskKey, received, total);
        });
        connect(reply, &QNetworkReply::finished, this, [this, reply, taskKey]() {
            finishDownload(taskKey, reply);
        });
        emit downloadStarted(taskKey);
    }

    /* 探测远端音频的字节数: 先发 HEAD 读 Content-Length, 服务器不支持时改发只取首字节的范围请求;
     * taskKey 由调用方给出, 结果以 sizeReady 或 sizeFailed 回调, 同一 taskKey 只保留一个在途请求。 */
    Q_INVOKABLE void probeAudioSize(const QString &url, const QString &taskKey) {
        if (url.isEmpty() || taskKey.isEmpty()) {
            emit sizeFailed(taskKey, QStringLiteral("参数不完整"));
            return;
        }
        if (m_sizeReplies.contains(taskKey)) {
            return;
        }
        QNetworkReply *reply = m_nam.head(buildRequest(url));
        m_sizeReplies.insert(taskKey, reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply, taskKey, url]() {
            m_sizeReplies.remove(taskKey);
            if (reply->error()==QNetworkReply::NoError) {
                const qint64 len = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
                reply->deleteLater();
                if (len>0) {
                    emit sizeReady(taskKey, len);
                    return;
                }
                probeAudioSizeByRange(url, taskKey);
                return;
            }
            reply->deleteLater();
            probeAudioSizeByRange(url, taskKey);
        });
    }

    /* 取消下载: 中止请求并删除未完成的文件, 随后以 downloadFailed 回调 */
    Q_INVOKABLE void cancelDownload(const QString &taskKey) {
        if (!m_downloads.contains(taskKey)) {
            return;
        }
        m_downloads[taskKey].cancelled = true;
        QNetworkReply *reply = m_downloads.value(taskKey).reply;
        if (reply!=nullptr) {
            reply->abort();
        }
    }

signals:
    /* 图标已就绪: localPath 为缓存文件的标准化绝对路径 */
    void cachedFileReady(const QString &cacheKey, const QString &localPath);
    /* 图标拉取失败: reason 为网络错误或落盘错误的说明 */
    void cachedFileFailed(const QString &cacheKey, const QString &reason);
    void downloadStarted(const QString &taskKey);
    /* 下载进度: total 为 -1 表示总长度未知 */
    void downloadProgress(const QString &taskKey, qint64 received, qint64 total);
    void downloadFinished(const QString &taskKey, const QString &localPath);
    /* 远端音频的字节数就绪与探测失败 */
    void sizeReady(const QString &taskKey, qint64 bytes);
    void sizeFailed(const QString &taskKey, const QString &reason);
    void downloadFailed(const QString &taskKey, const QString &reason);

private:
    struct DownloadTask {
        QNetworkReply *reply = nullptr;
        QFile *file = nullptr;
        QString dstPath;
        qint64 received = 0;
        qint64 total = -1;
        bool cancelled = false;
        qint64 lastStamp = 0;
    };

    /* 统一构造请求: 带上应用标识, 遵循安全重定向 */
    QNetworkRequest buildRequest(const QString &url) const {
        QNetworkRequest request{QUrl(url)};
        request.setHeader(QNetworkRequest::UserAgentHeader,
                          QCoreApplication::applicationName() + "/"
                              + QCoreApplication::applicationVersion());
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                             QNetworkRequest::NoLessSafeRedirectPolicy);
        request.setTransferTimeout(30000);
        return request;
    }

    /* 兜底探测: 发只取首字节的范围请求, 从 Content-Range 里读出总长度 */
    void probeAudioSizeByRange(const QString &url, const QString &taskKey) {
        if (m_sizeReplies.contains(taskKey)) {
            return;
        }
        QNetworkRequest request = buildRequest(url);
        request.setRawHeader("Range", "bytes=0-0");
        QNetworkReply *reply = m_nam.get(request);
        m_sizeReplies.insert(taskKey, reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply, taskKey]() {
            m_sizeReplies.remove(taskKey);
            const bool netOk = (reply->error()==QNetworkReply::NoError);
            const QString errText = reply->errorString();
            const qint64 total = totalFromContentRange(reply->rawHeader("Content-Range"));
            const qint64 declared = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
            reply->readAll();
            reply->deleteLater();
            if (total>0) {
                emit sizeReady(taskKey, total);
                return;
            }
            if (netOk && declared>0) {
                emit sizeReady(taskKey, declared);
                return;
            }
            emit sizeFailed(taskKey, (netOk? QStringLiteral("服务器未给出总长度"):errText));
        });
    }

    /* 从 Content-Range 头解析总长度: 形如 bytes 0-0/5242880 */
    static qint64 totalFromContentRange(const QByteArray &value) {
        const int slash = value.indexOf('/');
        if (slash<0) {
            return -1;
        }
        const QByteArray tail = value.mid(slash+1).trimmed();
        if (tail.isEmpty() || tail=="*") {
            return -1;
        }
        bool ok = false;
        const qint64 total = tail.toLongLong(&ok);
        return (ok? total:-1);
    }

    /* 把已到达的数据写入目标文件 */
    void writeChunk(const QString &taskKey, QNetworkReply *reply) {
        if (!m_downloads.contains(taskKey)) {
            reply->readAll();
            return;
        }
        DownloadTask &task = m_downloads[taskKey];
        const QByteArray data = reply->readAll();
        if (data.isEmpty()) {
            return;
        }
        const qint64 written = task.file->write(data);
        if (written>0) {
            task.received += written;
        }
    }

    /* 进度上报: 按时间节流, 避免逐块刷新界面 */
    void emitDownloadProgress(const QString &taskKey, qint64 received, qint64 total) {
        Q_UNUSED(received);
        if (!m_downloads.contains(taskKey)) {
            return;
        }
        DownloadTask &task = m_downloads[taskKey];
        task.total = (total>0? total:task.total);
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        if ((now-task.lastStamp)<200) {
            return;
        }
        task.lastStamp = now;
        emit downloadProgress(taskKey, task.received, task.total);
    }

    /* 收尾: 校验结果并落盘, 失败或取消时删除半成品文件 */
    void finishDownload(const QString &taskKey, QNetworkReply *reply) {
        if (!m_downloads.contains(taskKey)) {
            reply->deleteLater();
            return;
        }
        DownloadTask task = m_downloads.take(taskKey);
        writeChunkFinal(task, reply);
        reply->deleteLater();
        if (task.file!=nullptr) {
            task.file->close();
            task.file->deleteLater();
        }
        if (task.cancelled) {
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, QStringLiteral("已取消"));
            return;
        }
        if (reply->error()!=QNetworkReply::NoError) {
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, reply->errorString());
            return;
        }
        const QFileInfo info(task.dstPath);
        if (!info.isFile() || info.size()<=0) {
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, QStringLiteral("下载结果为空"));
            return;
        }
        emit downloadFinished(taskKey, QUrl::fromLocalFile(task.dstPath).toString());
    }

    /* 收尾前的最后一次写入: 此时 take 已把任务移出表, 因此单独处理 */
    void writeChunkFinal(DownloadTask &task, QNetworkReply *reply) {
        const QByteArray data = reply->readAll();
        if (data.isEmpty() || task.file==nullptr) {
            return;
        }
        if (task.file->write(data)>0) {
            task.received += data.size();
        }
    }

    QNetworkAccessManager m_nam;
    QHash<QString, QNetworkReply *> m_cachedFileReplies;
    /* 已经写成功的目标文件名: 并行尝试时只认第一个写成功的响应 */
    QSet<QString> m_cachedFileWon;
    QHash<QString, QNetworkReply *> m_sizeReplies;
    QHash<QString, DownloadTask> m_downloads;
};

#endif // APPNETHELPER_H

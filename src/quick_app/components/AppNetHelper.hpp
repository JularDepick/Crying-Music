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

    /* 拉取小文件到缓存目录(封面与 QQ 头像共用; 歌词走 QML 侧的 XHR 通道, 不经过这里,
     * 因为本方法会把 text 与 json 响应判成错误页而拒绝落盘): url 为完整地址, cacheKey 为本次尝试的键,
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
        /* 强制刷新要求覆盖同名文件: 先撤回本轮已胜出的记录,
         * 否则响应回来会被“另一个源已经写过”判为抢占而丢弃, 封面永远刷不新 */
        if (force) {
            m_cachedFileWon.remove(targetName);
        }
        QNetworkReply *reply = m_nam.get(buildRequest(url));
        m_cachedFileReplies.insert(cacheKey, reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply, cacheKey, targetPath, targetName]() {
            m_cachedFileReplies.remove(cacheKey);
            reportHttpStatusIfBad(reply);
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
            /* 响应体上限: 封面与头像不会到这个量级, 超出说明地址异常或响应被替换,
             * 不再整包读进内存 */
            const qint64 declaredBytes =
                reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
            if (declaredBytes > cachedFileMaxBytes || reply->bytesAvailable() > cachedFileMaxBytes) {
                emit cachedFileFailed(cacheKey, QStringLiteral("响应体过大"));
                return;
            }
            const QByteArray data = reply->readAll();
            if (data.isEmpty()) {
                emit cachedFileFailed(cacheKey, QStringLiteral("空响应"));
                return;
            }
            if (data.size() > cachedFileMaxBytes) {
                emit cachedFileFailed(cacheKey, QStringLiteral("响应体过大"));
                return;
            }
            /* 挡掉镜像用 200 返回的错误页: 文本与 JSON 一定不是图片, 未声明类型的照旧接受 */
            const QString contentType =
                reply->header(QNetworkRequest::ContentTypeHeader).toString().toLower();
            if (contentType.startsWith(QStringLiteral("text/"))
                || contentType.startsWith(QStringLiteral("application/json"))) {
                emit cachedFileFailed(cacheKey, QStringLiteral("内容不是图片: ") + contentType);
                return;
            }
            QDir().mkpath(QFileInfo(targetPath).absolutePath());
            QFile out(targetPath);
            if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                emit cachedFileFailed(cacheKey, QStringLiteral("缓存写入失败"));
                return;
            }
            /* 写入字节数不足时删掉半成品, 否则下次命中缓存会读到残缺文件 */
            const qint64 written = out.write(data);
            out.close();
            if (written != qint64(data.size())) {
                QFile::remove(targetPath);
                emit cachedFileFailed(cacheKey, QStringLiteral("缓存写入失败"));
                return;
            }
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
            if (verifyAudioContentType(taskKey, reply)) {
                writeChunk(taskKey, reply);
            }
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
            reportHttpStatusIfBad(reply);
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
    /* 请求返回 4xx 或 5xx: url 为请求地址, status 为 HTTP 状态码 */
    void httpError(const QString &url, int status);

private:
    /* 单次小文件响应(封面与头像)的内存上限: 32 MB 已远超实际图片体积,
     * 超过即判为响应异常, 避免异常地址把整个响应体读进内存 */
    static constexpr qint64 cachedFileMaxBytes = 32 * 1024 * 1024;

    struct DownloadTask {
        QNetworkReply *reply = nullptr;
        QFile *file = nullptr;
        QString dstPath;
        /* 取消或拒收的具体原因: 非空时取代默认的已取消上报 */
        QString failReason;
        qint64 received = 0;
        qint64 total = -1;
        bool cancelled = false;
        /* 响应头的内容类型是否已经判定过, 只判一次 */
        bool contentChecked = false;
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

    /* 把已到达的数据写入目标文件: 写入字节数与数据长度不一致即视为写失败,
     * 立即中止该任务, 避免磁盘满时把残缺音频当成下载成功 */
    void writeChunk(const QString &taskKey, QNetworkReply *reply) {
        if (!m_downloads.contains(taskKey)) {
            reply->readAll();
            return;
        }
        DownloadTask &task = m_downloads[taskKey];
        const QByteArray data = reply->readAll();
        if (data.isEmpty() || task.file==nullptr || task.cancelled) {
            return;
        }
        const qint64 written = task.file->write(data);
        if (written>0) {
            task.received += written;
        }
        if (written != qint64(data.size())) {
            qWarning() << "AppNetHelper writeChunk failed: " << task.dstPath
                       << written << data.size() << fileErrorText(task.file);
            /* failDownload 会中止请求并可能同步触发收尾, 之后不能再访问 task */
            failDownload(task, QStringLiteral("写入失败: ") + fileErrorText(task.file));
        }
    }

    /* 写失败的中止处理: 先记原因再中止请求, 半成品文件与失败信号由收尾统一处理 */
    void failDownload(DownloadTask &task, const QString &reason) {
        task.cancelled = true;
        if (task.failReason.isEmpty()) {
            task.failReason = reason;
        }
        QNetworkReply *reply = task.reply;
        if (reply!=nullptr) {
            reply->abort();
        }
    }

    /* 写失败的可读原因: 文件对象给出具体错误, 没有错误信息时回退到通用说明 */
    static QString fileErrorText(const QFile *file) {
        const QString text = (file==nullptr? QString():file->errorString());
        return (text.isEmpty()? QStringLiteral("磁盘写入失败"):text);
    }

    /* 音频下载的内容类型校验: 镜像用 200 返回的 HTML 或 JSON 错误页不是音频,
     * 一旦识别立即中止请求并记下原因, 避免把错误页原样落盘成音频文件;
     * 未声明类型或声明为二进制流的照旧接受, 只拦明确是文本的两类 */
    bool verifyAudioContentType(const QString &taskKey, QNetworkReply *reply) {
        if (!m_downloads.contains(taskKey)) {
            return false;
        }
        DownloadTask &task = m_downloads[taskKey];
        if (task.contentChecked) {
            return !task.cancelled;
        }
        task.contentChecked = true;
        const QString contentType =
            reply->header(QNetworkRequest::ContentTypeHeader).toString().toLower();
        if (!contentType.startsWith(QStringLiteral("text/"))
            && !contentType.startsWith(QStringLiteral("application/json"))) {
            return true;
        }
        task.cancelled = true;
        task.failReason = QStringLiteral("内容不是音频: ") + contentType;
        reply->abort();
        return false;
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
        /* 响应声明的总长度先取好, 收尾时与已收字节数比对 */
        const qint64 declared =
            reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
        writeChunkFinal(task, reply);
        reportHttpStatusIfBad(reply);
        reply->deleteLater();
        if (task.file!=nullptr) {
            /* 落盘结果以 flush 与错误码为准: 磁盘满一类错误可能延后到刷新时才暴露 */
            const bool flushed = task.file->flush();
            task.file->close();
            const QFileDevice::FileError fileError = task.file->error();
            const QString fileErrorDesc = fileErrorText(task.file);
            task.file->deleteLater();
            if ((!flushed || fileError!=QFileDevice::NoError) && !task.cancelled) {
                task.cancelled = true;
                task.failReason = QStringLiteral("写入失败: ") + fileErrorDesc;
            }
        }
        if (task.cancelled) {
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, (task.failReason.isEmpty()
                                          ? QStringLiteral("已取消"):task.failReason));
            return;
        }
        if (reply->error()!=QNetworkReply::NoError) {
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, reply->errorString());
            return;
        }
        /* 收尾再确认一次内容类型: 首字节到达前就结束的响应不会走 readyRead */
        const QString finalContentType =
            reply->header(QNetworkRequest::ContentTypeHeader).toString().toLower();
        if (finalContentType.startsWith(QStringLiteral("text/"))
            || finalContentType.startsWith(QStringLiteral("application/json"))) {
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, QStringLiteral("内容不是音频: ") + finalContentType);
            return;
        }
        const QFileInfo info(task.dstPath);
        if (!info.isFile() || info.size()<=0) {
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, QStringLiteral("下载结果为空"));
            return;
        }
        /* 已收字节数必须与文件实际大小以及响应声明的总长度一致, 不一致说明文件残缺,
         * 删除后按失败上报, 不能写进下载记录;
         * 压缩传输时 Content-Length 是压缩后的大小, 与已收的解压字节不可比, 这一档只比文件大小 */
        const bool encoded = !reply->rawHeader("Content-Encoding").isEmpty();
        const qint64 expected = (encoded? -1:(declared>0? declared:task.total));
        if (info.size()!=task.received || (expected>0 && task.received!=expected)) {
            qWarning() << "AppNetHelper finishDownload incomplete: " << task.dstPath
                       << task.received << info.size() << expected;
            QFile::remove(task.dstPath);
            emit downloadFailed(taskKey, (expected>0
                ? QStringLiteral("下载不完整: 已收 %1 字节, 应为 %2 字节")
                      .arg(task.received).arg(expected)
                : QStringLiteral("下载不完整: 已收 %1 字节, 落盘 %2 字节")
                      .arg(task.received).arg(info.size())));
            return;
        }
        emit downloadFinished(taskKey, QUrl::fromLocalFile(task.dstPath).toString());
    }

    /* 上报一次 HTTP 状态: 仅当响应状态为 4xx 或 5xx 时发出, 供上层判断资源是否已失效 */
    void reportHttpStatusIfBad(QNetworkReply *reply) {
        if (reply==nullptr) {
            return;
        }
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status>=400) {
            emit httpError(reply->url().toString(), status);
        }
    }

    /* 收尾前的最后一次写入: 此时 take 已把任务移出表, 因此单独处理;
     * 与 writeChunk 同一口径, 写入字节数不足时按写失败记原因 */
    void writeChunkFinal(DownloadTask &task, QNetworkReply *reply) {
        const QByteArray data = reply->readAll();
        if (data.isEmpty() || task.file==nullptr || task.cancelled) {
            return;
        }
        const qint64 written = task.file->write(data);
        if (written>0) {
            task.received += written;
        }
        if (written != qint64(data.size())) {
            qWarning() << "AppNetHelper writeChunkFinal failed: " << task.dstPath
                       << written << data.size() << fileErrorText(task.file);
            task.cancelled = true;
            if (task.failReason.isEmpty()) {
                task.failReason = QStringLiteral("写入失败: ") + fileErrorText(task.file);
            }
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

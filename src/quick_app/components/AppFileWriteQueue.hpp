#pragma once

#include <QByteArray>
#include <QDeadlineTimer>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QMutex>
#include <QMutexLocker>
#include <QSaveFile>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QWaitCondition>

/* 落盘写入队列: 数据文件交给一条后台线程顺序写入, 界面线程只做入队.
 * 同一路径的多次入队只保留最后一次, 因此播放进度这类高频写入不会在磁盘上
 * 留下中间态, 也不会因为磁盘慢而卡住界面; 需要立刻看到文件时调用 flush 等它写完 */
class AppFileWriteQueue : public QThread
{
public:
    /* 进程内唯一实例: 首次取用时创建并启动线程 */
    static AppFileWriteQueue *instance()
    {
        static AppFileWriteQueue *queue = []() {
            auto *one = new AppFileWriteQueue;
            one->start();
            return one;
        }();
        return queue;
    }

    /* 入队一次写入: 同一路径已有待写内容时只替换内容, 不追加第二次 */
    void enqueue(const QString &path, const QByteArray &data)
    {
        if (path.isEmpty()) {
            return;
        }
        QMutexLocker locker(&m_mutex);
        if (m_pending.contains(path)) {
            m_pending[path] = data;
        } else {
            m_pending.insert(path, data);
            m_order.append(path);
        }
        m_workReady.wakeOne();
    }

    /* 等队列排空: 超时返回 false, 调用方据此决定是否继续等待 */
    bool flush(int timeoutMs)
    {
        QMutexLocker locker(&m_mutex);
        if (m_pending.isEmpty() && m_busy == false) {
            return true;
        }
        QDeadlineTimer deadline(timeoutMs > 0 ? timeoutMs : 5000);
        while (m_pending.isEmpty() == false || m_busy == true) {
            if (m_idle.wait(&m_mutex, deadline) == false) {
                return false;
            }
        }
        return true;
    }

protected:
    void run() override
    {
        forever {
            QString path;
            QByteArray data;
            {
                QMutexLocker locker(&m_mutex);
                while (m_pending.isEmpty() && m_stopping == false) {
                    m_workReady.wait(&m_mutex);
                }
                if (m_stopping == true && m_pending.isEmpty()) {
                    return;
                }
                path = m_order.takeFirst();
                data = m_pending.take(path);
                m_busy = true;
            }
            if (writeAtomically(path, data) == false) {
                qWarning() << "AppFileWriteQueue: write failed" << path;
            }
            {
                QMutexLocker locker(&m_mutex);
                m_busy = false;
                if (m_pending.isEmpty()) {
                    m_idle.wakeAll();
                }
            }
        }
    }

private:
    AppFileWriteQueue() = default;

    /* 原子写: 先写同目录临时文件再改名, 与同步写同一口径 */
    static bool writeAtomically(const QString &path, const QByteArray &data)
    {
        const QDir parentDir = QFileInfo(path).absoluteDir();
        if (parentDir.exists() == false && parentDir.mkpath(QStringLiteral(".")) == false) {
            qWarning() << "AppFileWriteQueue: cannot create dir" << parentDir.absolutePath();
            return false;
        }
        QSaveFile out(path);
        if (out.open(QIODevice::WriteOnly) == false) {
            qWarning() << "AppFileWriteQueue: cannot open" << path << out.errorString();
            return false;
        }
        if (out.write(data) != qint64(data.size())) {
            qWarning() << "AppFileWriteQueue: short write" << path;
            out.cancelWriting();
            return false;
        }
        if (out.commit() == false) {
            qWarning() << "AppFileWriteQueue: cannot commit" << path << out.errorString();
            return false;
        }
        return true;
    }

    QMutex m_mutex;
    QWaitCondition m_workReady;
    QWaitCondition m_idle;
    QHash<QString, QByteArray> m_pending;
    QStringList m_order;
    bool m_busy = false;
    bool m_stopping = false;
};

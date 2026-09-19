#ifndef APPFILEHELPER_H
#define APPFILEHELPER_H

#include <QObject>
#include <QUrl>
#include <QFile>
#include <QDir>
#include <QStringList>
#include <QStringConverter>
#include <qdebug.h>

class AppFileHelper : public QObject {
    Q_OBJECT
public:
    explicit AppFileHelper(QObject *parent=nullptr):QObject(parent) {}
    /* 判断目录是否存在: 入参为绝对路径带 file:// */
    Q_INVOKABLE bool existsDir(const QUrl &url) const {
        return QFileInfo(url.toLocalFile()).isDir();
    }
    /* 判断文件是否存在: 入参为绝对路径带 file:// */
    Q_INVOKABLE bool exists(const QUrl &url) const {
        return QFile::exists(url.toLocalFile());
    }
    /* 读: 入参为绝对路径带 file://, 默认 GBK */
    Q_INVOKABLE QString read(const QUrl &url) const {
        return read(url,"GBK");
    }
    /* 读: 指定编码 */
    Q_INVOKABLE QString read(const QUrl &url,const QString &codecName) const {
        QFile fin(url.toLocalFile());
        if (!fin.open(QIODevice::ReadOnly)) {
            qWarning()<<"AppFileHelper read failed: "<<url<<fin.errorString();
            return {};
        }
        QByteArray data=fin.readAll();
        auto decoder=QStringDecoder(codecName.toUtf8().constData());
        if (!decoder.isValid()) {
            qWarning()<<"AppFileHelper invalid codec: "<<codecName;
            return {};
        }
        return decoder(data);
    }
    /* 写: 入参为绝对路径带 file://, 默认 GBK */
    Q_INVOKABLE bool write(const QUrl &url,const QString &content) const {
        return write(url,content,"GBK");
    }
    /* 写: 指定编码 */
    Q_INVOKABLE bool write(const QUrl &url,const QString &content,const QString &codecName) const {
        QFile fout(url.toLocalFile());
        if (!fout.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            qWarning()<<"AppFileHelper write failed: "<<url<<fout.errorString();
            return false;
        }
        auto encoder=QStringEncoder(codecName.toUtf8().constData());
        if (!encoder.isValid()) {
            qWarning()<<"AppFileHelper invalid codec: "<<codecName;
            return false;
        }
        QByteArray data=encoder(content);
        return fout.write(data)!=-1;
    }
    /* 列出: 入参为绝对路径(不含 file://), 返回直接子文件名称列表 (Qt 的 json 数组) */
    Q_INVOKABLE QStringList listFiles(const QString &path) const {
        QDir dir(path);
        if (!dir.exists()) {
            qWarning()<<"AppFileHelper listFiles failed: "<<path<<" not exists";
            return {};
        }
        return dir.entryList(QDir::Files, QDir::Name);
    }
    /* 列出: 入参为绝对路径(不含 file://), 返回直接子文件夹名称列表 (Qt 的 json 数组) */
    Q_INVOKABLE QStringList listDirs(const QString &path) const {
        QDir dir(path);
        if (!dir.exists()) {
            qWarning()<<"AppFileHelper listDirs failed: "<<path<<" not exists";
            return {};
        }
        return dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    }
};

#endif
#ifndef APPPATHHELPER_H
#define APPPATHHELPER_H

#include <QObject>
#include <QUrl>
#include <QDir>
#include <QCoreApplication>

class AppPathHelper : public QObject {
    Q_OBJECT
public:
    explicit AppPathHelper(QObject *parent=nullptr):QObject(parent) {}
    /* 无参重载: 返回带 file:// */
    Q_INVOKABLE QString getAppPath() const {
        return getAppPath(true);
    }
    /* 有参重载: 自指定是否带 file:// */
    Q_INVOKABLE QString getAppPath(bool withFileScheme) const {
        const QString dir=QCoreApplication::applicationDirPath();
        return (withFileScheme? (QUrl::fromLocalFile(dir).toString()):dir);
    }
    /* 无参重载: 返回带 file:// */
    Q_INVOKABLE QString getAbsolutePath(const QString &relativePath) const {
        return (getAbsolutePath(relativePath,true));
    }
    /* 有参重载: 自指定是否带 file:// */
    Q_INVOKABLE QString getAbsolutePath(const QString &relativePath,bool withFileScheme) const {
        QDir dir(QCoreApplication::applicationDirPath());
        const QString abs=dir.filePath(relativePath);
        return (withFileScheme? (QUrl::fromLocalFile(abs).toString()):abs);
    }
};

#endif
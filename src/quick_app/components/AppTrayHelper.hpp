#ifndef APPTRAYHELPER_H
#define APPTRAYHELPER_H

#include <QObject>
#include <QUrl>
#include <QIcon>
#include <QMenu>
#include <QAction>
#include <QSystemTrayIcon>

class AppTrayHelper : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool visible READ isVisible WRITE setVisible NOTIFY visibleChanged)
    Q_PROPERTY(QString tooltip READ tooltip WRITE setTooltip NOTIFY tooltipChanged)
    Q_PROPERTY(QUrl iconSource READ iconSource WRITE setIconSource NOTIFY iconSourceChanged)
    Q_PROPERTY(QString quitText READ quitText WRITE setQuitText NOTIFY quitTextChanged)
public:
    explicit AppTrayHelper(QObject *parent=nullptr):QObject(parent) {
        m_quitAction=m_menu.addAction(QString());
        m_menu.addSeparator();
        m_tray.setContextMenu(&m_menu);
        connect(&m_tray,&QSystemTrayIcon::activated,this,[this](QSystemTrayIcon::ActivationReason reason) {
            if (reason==QSystemTrayIcon::Trigger) {
                emit triggered();
            }
        });
        connect(m_quitAction,&QAction::triggered,this,[this]() { emit quitTriggered(); });
    }
    bool isVisible() const {
        return m_tray.isVisible();
    }
    void setVisible(bool value) {
        if (m_tray.isVisible()==value) {
            return;
        }
        m_tray.setVisible(value);
        emit visibleChanged();
    }
    QString tooltip() const {
        return m_tooltip;
    }
    void setTooltip(const QString &value) {
        if (m_tooltip==value) {
            return;
        }
        m_tooltip=value;
        m_tray.setToolTip(value);
        emit tooltipChanged();
    }
    QUrl iconSource() const {
        return m_iconSource;
    }
    void setIconSource(const QUrl &value) {
        if (m_iconSource==value) {
            return;
        }
        m_iconSource=value;
        m_tray.setIcon(QIcon(toResourcePath(value)));
        emit iconSourceChanged();
    }
    QString quitText() const {
        return m_quitAction->text();
    }
    void setQuitText(const QString &value) {
        if (m_quitAction->text()==value) {
            return;
        }
        m_quitAction->setText(value);
        emit quitTextChanged();
    }
signals:
    void visibleChanged();
    void tooltipChanged();
    void iconSourceChanged();
    void quitTextChanged();
    void triggered();
    void quitTriggered();
private:
    static QString toResourcePath(const QUrl &source) {
        return (source.scheme()==QStringLiteral("qrc")? QStringLiteral(":")+source.path():(source.isLocalFile()? source.toLocalFile():source.toString()));
    }
    QSystemTrayIcon m_tray;
    QMenu m_menu;
    QAction *m_quitAction=nullptr;
    QString m_tooltip;
    QUrl m_iconSource;
};

#endif

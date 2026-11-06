#ifndef SYSTEMTRAYHELPER_H
#define SYSTEMTRAYHELPER_H

#include <QObject>
#include <QIcon>
#include <QMenu>
#include <QAction>
#include <QSystemTrayIcon>

/* 系统托盘辅助类: 用 QtWidgets 的 QSystemTrayIcon 取代 QML 的 Qt.labs.platform。
 * 该模块的类型不保证向后兼容, 且要求应用链接 QtWidgets 并以 QApplication 启动;
 * 菜单在 C++ 侧用 QMenu 构建, 激活原因归一成切换窗口与退出两个信号交给 QML,
 * 因此界面侧只保留收起与展开的判断, 不再持有托盘对象 */
class SystemTrayHelper : public QObject {
    Q_OBJECT
public:
    explicit SystemTrayHelper(QObject *parent=nullptr) : QObject(parent) {
        m_menu = new QMenu();
        QAction *quitAction = m_menu->addAction(QStringLiteral("退出"));
        QObject::connect(quitAction, &QAction::triggered, this, &SystemTrayHelper::quitRequested);
        m_tray = new QSystemTrayIcon(this);
        m_tray->setContextMenu(m_menu);
        QObject::connect(m_tray, &QSystemTrayIcon::activated, this,
                         [this](QSystemTrayIcon::ActivationReason reason) {
            /* 左键单击, 双击与中键都归一为切换窗口, 与迁移前的判定一致;
             * 右键由菜单自己接管, 不在这里处理 */
            if (reason==QSystemTrayIcon::Trigger
                || reason==QSystemTrayIcon::DoubleClick
                || reason==QSystemTrayIcon::MiddleClick) {
                emit toggleRequested();
            }
        });
    }
    ~SystemTrayHelper() override {
        delete m_menu;
        m_menu = nullptr;
    }

    /* 显示托盘图标: 图标固定取应用资源里的 favicon, 提示文本由调用方给出 */
    Q_INVOKABLE void show(const QString &tooltip) {
        const QIcon one(QStringLiteral(":/favicon.jpg"));
        if (!one.isNull()) {
            m_tray->setIcon(one);
        }
        m_tray->setToolTip(tooltip);
        m_tray->show();
    }
    Q_INVOKABLE void hide() {
        m_tray->hide();
    }
    Q_INVOKABLE void setToolTip(const QString &text) {
        m_tray->setToolTip(text);
    }
    Q_INVOKABLE bool visible() const {
        return m_tray->isVisible();
    }

signals:
    /* 托盘图标被点击: 界面据此在隐藏与显示之间切换窗口 */
    void toggleRequested();
    /* 托盘菜单选中退出: 界面据此结束进程 */
    void quitRequested();

private:
    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_menu = nullptr;
};

#endif // SYSTEMTRAYHELPER_H

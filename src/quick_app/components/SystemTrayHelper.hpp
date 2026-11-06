#ifndef SYSTEMTRAYHELPER_H
#define SYSTEMTRAYHELPER_H

#include <QObject>
#include <QIcon>
#include <QMenu>
#include <QAction>
#include <QStringList>
#include <QList>
#include <QSystemTrayIcon>

/* 系统托盘辅助类: 用 QtWidgets 的 QSystemTrayIcon 承载托盘图标与右键菜单。
 * 该模块的类型不保证向后兼容, 且要求应用链接 QtWidgets 并以 QApplication 启动;
 * 菜单在 C++ 侧用 QMenu 构建, 菜单项只负责发意图, 播放与窗口的状态由 QML 侧
 * 经 syncMenu 推回来, 因此本类不持有播放器, 也不做任何业务判断.
 *
 * 菜单结构: 正在播放(信息行) / 播放暂停, 上一曲, 下一曲, 播放顺序子菜单, 喜欢
 * / 显示或隐藏主窗口 / 退出 */
class SystemTrayHelper : public QObject {
    Q_OBJECT
public:
    explicit SystemTrayHelper(QObject *parent=nullptr) : QObject(parent) {
        m_menu = new QMenu();
        /* 正在播放: 只做信息展示, 不参与点击 */
        m_nowPlaying = m_menu->addAction(QStringLiteral("未在播放"));
        m_nowPlaying->setEnabled(false);
        m_menu->addSeparator();

        m_playPause = m_menu->addAction(QStringLiteral("播放"));
        QObject::connect(m_playPause, &QAction::triggered, this, &SystemTrayHelper::playPauseRequested);
        m_previous = m_menu->addAction(QStringLiteral("上一曲"));
        QObject::connect(m_previous, &QAction::triggered, this, &SystemTrayHelper::previousRequested);
        m_next = m_menu->addAction(QStringLiteral("下一曲"));
        QObject::connect(m_next, &QAction::triggered, this, &SystemTrayHelper::nextRequested);

        /* 播放顺序: 子菜单四选一, 顺序与播放模块的模式取值一致(0 随机, 1 顺序, 2 单曲, 3 列表) */
        m_orderMenu = m_menu->addMenu(QStringLiteral("播放顺序"));
        const QStringList orderLabels = {QStringLiteral("随机播放"), QStringLiteral("顺序播放"),
                                         QStringLiteral("单曲循环"), QStringLiteral("列表循环")};
        for (int i=0; i<orderLabels.size(); ++i) {
            QAction *one = m_orderMenu->addAction(orderLabels.at(i));
            one->setCheckable(true);
            const int mode = i;
            QObject::connect(one, &QAction::triggered, this, [this, mode]() {
                emit playModeRequested(mode);
            });
            m_orderActions.append(one);
        }

        m_like = m_menu->addAction(QStringLiteral("喜欢"));
        QObject::connect(m_like, &QAction::triggered, this, &SystemTrayHelper::likeRequested);

        m_menu->addSeparator();
        m_windowAction = m_menu->addAction(QStringLiteral("显示主窗口"));
        QObject::connect(m_windowAction, &QAction::triggered, this, &SystemTrayHelper::toggleRequested);
        m_menu->addSeparator();
        QAction *quitAction = m_menu->addAction(QStringLiteral("退出"));
        QObject::connect(quitAction, &QAction::triggered, this, &SystemTrayHelper::quitRequested);

        m_tray = new QSystemTrayIcon(this);
        m_tray->setContextMenu(m_menu);
        QObject::connect(m_tray, &QSystemTrayIcon::activated, this,
                         [this](QSystemTrayIcon::ActivationReason reason) {
            /* 左键单击, 双击与中键都归一为切换窗口; 右键由菜单自己接管 */
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

    /* 同步菜单的动态部分: 正在播放的曲目, 播放状态, 是否有当前项, 是否已喜欢,
     * 当前播放顺序与窗口可见性; 只改变化了的项, 避免菜单在展开时反复重排 */
    Q_INVOKABLE void syncMenu(const QString &trackText, bool playing, bool hasTrack,
                              bool liked, int playMode, bool windowShown) {
        const QString info = trackText.isEmpty() ? QStringLiteral("未在播放") : trackText;
        if (m_nowPlaying->text()!=info) {
            m_nowPlaying->setText(info);
        }
        const QString playLabel = playing ? QStringLiteral("暂停") : QStringLiteral("播放");
        if (m_playPause->text()!=playLabel) {
            m_playPause->setText(playLabel);
        }
        m_playPause->setEnabled(hasTrack);
        m_previous->setEnabled(hasTrack);
        m_next->setEnabled(hasTrack);
        m_like->setEnabled(hasTrack);
        const QString likeLabel = liked ? QStringLiteral("取消喜欢") : QStringLiteral("喜欢");
        if (m_like->text()!=likeLabel) {
            m_like->setText(likeLabel);
        }
        const int count = m_orderActions.size();
        for (int i=0; i<count; ++i) {
            m_orderActions.at(i)->setChecked(i==playMode);
        }
        const QString winLabel = windowShown ? QStringLiteral("隐藏主窗口")
                                             : QStringLiteral("显示主窗口");
        if (m_windowAction->text()!=winLabel) {
            m_windowAction->setText(winLabel);
        }
        /* 悬停提示同步带上当前曲目, 不必打开菜单就能看到在放什么 */
        const QString tip = trackText.isEmpty()
                             ? QStringLiteral("泣水音乐")
                             : (QStringLiteral("泣水音乐 · ") + trackText);
        if (m_tray->toolTip()!=tip) {
            m_tray->setToolTip(tip);
        }
    }

signals:
    /* 托盘图标被点击或菜单选中显示隐藏: 界面据此切换窗口 */
    void toggleRequested();
    /* 播放暂停, 上一曲, 下一曲 */
    void playPauseRequested();
    void previousRequested();
    void nextRequested();
    /* 播放顺序: 参数为模式取值 */
    void playModeRequested(int mode);
    /* 喜欢开关: 由界面按当前项状态取反 */
    void likeRequested();
    /* 菜单选中退出: 界面据此结束进程 */
    void quitRequested();

private:
    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_menu = nullptr;
    QMenu *m_orderMenu = nullptr;
    QAction *m_nowPlaying = nullptr;
    QAction *m_playPause = nullptr;
    QAction *m_previous = nullptr;
    QAction *m_next = nullptr;
    QAction *m_like = nullptr;
    QAction *m_windowAction = nullptr;
    QList<QAction *> m_orderActions;
};

#endif // SYSTEMTRAYHELPER_H

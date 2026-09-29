#ifndef APPCLICKHELPER_H
#define APPCLICKHELPER_H

#include <QObject>
#include <QEvent>
#include <QPointF>
#include <QWindow>
#include <QMouseEvent>
#include <QTimer>

class AppClickHelper : public QObject {
    Q_OBJECT
public:
    explicit AppClickHelper(QObject *parent=nullptr):QObject(parent) {}
    /* 绑定需要观察的窗口: 只旁路监听, 不消费任何事件 */
    void attach(QObject *window) {
        if (m_window) {
            m_window->removeEventFilter(this);
        }
        m_window=qobject_cast<QWindow *>(window);
        if (m_window) {
            m_window->installEventFilter(this);
        }
    }
signals:
    /* 左键按下后发出: 入参为按下时的场景坐标 */
    void mousePressed(const QPointF &scenePos);
protected:
    bool eventFilter(QObject *watched, QEvent *event) override {
        switch (event->type()) {
        /* 双击的第二次按下走 DblClick 而非 Press, 一并处理避免漏收 */
        case QEvent::MouseButtonPress:
        case QEvent::MouseButtonDblClick: {
            auto *me=static_cast<QMouseEvent *>(event);
            if (me->button()==Qt::LeftButton) {
                const QPointF pos=me->scenePosition();
                /* 延后一拍发出, 避免在事件派发中途改动界面可见性 */
                QTimer::singleShot(0, this, [this, pos]() { emit mousePressed(pos); });
            }
            break;
        }
        default:
            break;
        }
        /* 永不消费, 事件原样继续, 控件交互不受影响 */
        return false;
    }
private:
    QWindow *m_window=nullptr;
};

#endif

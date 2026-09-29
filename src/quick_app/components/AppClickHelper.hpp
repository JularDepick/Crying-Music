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
    void mousePressed(const QPointF &scenePos);
protected:
    bool eventFilter(QObject *watched, QEvent *event) override {
        switch (event->type()) {
        case QEvent::MouseButtonPress:
        case QEvent::MouseButtonDblClick: {
            auto *me=static_cast<QMouseEvent *>(event);
            if (me->button()==Qt::LeftButton) {
                const QPointF pos=me->scenePosition();
                QTimer::singleShot(0, this, [this, pos]() { emit mousePressed(pos); });
            }
            break;
        }
        default:
            break;
        }
        return false;
    }
private:
    QWindow *m_window=nullptr;
};

#endif

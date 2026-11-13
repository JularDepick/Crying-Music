#ifndef APPDEBUGHELPER_HPP
#define APPDEBUGHELPER_HPP

#include <QObject>

/* 运行期调试开关: 只有命令行带 --debug 时为真.
 * C++ 侧经 AppDebug::enabled() 取值, QML 侧经单例 AppDebug 的只读属性 enabled 取值.
 * 关掉时各处的调试轨迹全部短路; 可恢复异常的告警与致命错误不受它影响 */
namespace AppDebug {
inline bool &switchRef() {
    static bool on = false;
    return on;
}
inline void setEnabled(bool on) {
    switchRef() = on;
}
inline bool enabled() {
    return switchRef();
}
}

/* 调试开关的 QML 外观: 只读, 取值来自上面那个进程内开关, 启动时设定后不再变化 */
class AppDebugHelper : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled CONSTANT)
public:
    explicit AppDebugHelper(QObject *parent=nullptr):QObject(parent) {}

    bool enabled() const {
        return AppDebug::enabled();
    }
};

#endif

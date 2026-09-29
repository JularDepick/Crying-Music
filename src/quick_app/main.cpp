#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <qqml.h>

#include "./components/AppPathHelper.hpp"
#include "./components/AppFileHelper.hpp"
#include "./components/AppClickHelper.hpp"
#include "./components/AppTrayHelper.hpp"

/* using namespace std; */

int main(int argc, char *argv[])
{
    /* 创建GUI应用并接收命令行参数 */
    QApplication app(argc, argv);
    /* 设置GUI应用版本号 */
    QApplication::setApplicationVersion(VERSION);
    /* 注册AppHelpers实例 */
    AppPathHelper _aph_;
    AppFileHelper _afh_;
    AppClickHelper _ach_;
    AppTrayHelper _ath_;
    qmlRegisterSingletonInstance("AppHelpers",1,0,"AppPathHelper",&_aph_);
    qmlRegisterSingletonInstance("AppHelpers",1,0,"AppFileHelper",&_afh_);
    qmlRegisterSingletonInstance("AppHelpers",1,0,"AppClickHelper",&_ach_);
    qmlRegisterSingletonInstance("AppHelpers",1,0,"AppTrayHelper",&_ath_);
    /* 创建QML引擎 */
    QQmlApplicationEngine engine;
    /* 当QML引擎创建失败时自动退出应用 */
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    /* 加载根QML文件 */
    engine.load(QStringLiteral("qrc:/Main.qml"));
    if (!engine.rootObjects().isEmpty()) {
        _ach_.attach(engine.rootObjects().constFirst());
    }
    /* 进入应用消息循环 */
    return QApplication::exec();
}

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <qqml.h>

#include "./components/AppPathHelper.hpp"
#include "./components/AppFileHelper.hpp"

/* using namespace std; */

int main(int argc, char *argv[])
{
    /* 创建GUI应用并接收命令行参数 */
    QGuiApplication app(argc, argv);
    /* 设置GUI应用版本号 */
    QGuiApplication::setApplicationVersion(VERSION);
    /* 注册AppHelpers实例 */
    AppPathHelper _aph_;
    AppFileHelper _afh_;
    qmlRegisterSingletonInstance("AppHelpers",1,0,"AppPathHelper",&_aph_);
    qmlRegisterSingletonInstance("AppHelpers",1,0,"AppFileHelper",&_afh_);
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
    /* 进入应用消息循环 */
    return QGuiApplication::exec();
}

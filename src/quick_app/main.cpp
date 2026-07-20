#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>

int main(int argc, char *argv[])
{
    /* 创建GUI应用并接收命令行参数 */
    QGuiApplication app(argc, argv);
    /* 设置GUI应用版本号 */
    QGuiApplication::setApplicationVersion(VERSION);
    /* 创建QML引擎 */
    QQmlApplicationEngine engine;
    /* 当QML引擎创建失败时自动退出应用 */
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    /* 加载QML文件 */
    engine.load(QUrl("qrc:/Main.qml"));

    return QGuiApplication::exec();
}

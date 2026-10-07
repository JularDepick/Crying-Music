import QtQuick
import QtQuick.Controls
import "./"

/* 主内容区页面基类: 统一底色与圆角, 并提供各页可覆写的两个钩子 */
Rectangle {
    visible: false;
    color: Define.mainAreaColor;
    radius: Define.mainAreaRaduis;
    /* 播放器由主界面注入, 页面只调用它的播放命令, 读取播放数据一律走存储枢纽 */
    property var thePlayer;
    /* 钩子: 点界面空白处时收起本页子菜单; 顶栏刷新时重建本页列表 */
    function subsHide(scenePos) {}
    function refresh() {}
}
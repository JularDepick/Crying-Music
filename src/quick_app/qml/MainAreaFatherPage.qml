import QtQuick
import QtQuick.Controls
import "./"

/* 主内容区页面基类: 统一底色与圆角, 并提供各页可覆写的钩子 */
Rectangle {
    visible: false;
    color: Define.mainAreaColor;
    radius: Define.mainAreaRaduis;
    /* 播放器由主界面注入, 页面只调用它的播放命令, 读取播放数据一律走存储枢纽 */
    property var thePlayer;
    /* 内存枢纽由主界面注入, 承载元数据缓存与加载进度这类只存内存的临时状态 */
    property var theMemStorage;
    /* 钩子: 点界面空白处时收起本页子菜单; 顶栏刷新时重建本页列表;
     * 顶栏搜索时按关键字过滤本页列表并返回命中的条目数组, 无列表的页面返回空数组 */
    function subsHide(scenePos) {}
    function refresh() {}
    function search(keyword) {
        return [];
    }
    /* 钩子: 在列表里定位到指定条目并滚动过去高亮它, 供搜索结果页回跳时调用;
     * 无列表的页面返回 false, 结果页据此决定是否显示定位入口 */
    function locateSong(one) {
        return false;
    }
}
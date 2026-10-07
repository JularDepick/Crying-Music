pragma Singleton
import QtQuick

Item {
    visible: false;
    property int windowPadding: 10;
    property int windowRadius: 7;
    property int mainAreaRaduis: 7;
    property int edgeMouseAreaD: 5; /* 不要改变 */
    property int cornerMouseAreaD: 10; /* 不要改变 */
    property color windowBorderColor: "#aaaaaa";
    property color nocolor: "transparent";
    property color canvasColor: "#f0f0f0";
    property color leftSidebarColor: "#f0f0f0";
    property color leftSidebarHeaderColor: "#f0f0f0";
    property color mainAreaColor: "#f6f6f6";
    property color topNavBarColor: "#f6f6f6";
    property int btnSize: 20;
    property int btnSpacing: 20;
    property int recentListSize: 200; /* 最近播放列表的条数上限 */
    property int probeTimeoutMs: 1000; /* FakePlayer 探测元数据的超时阈值, 超时转 AppFileHelper 兜底 */
    property int probeFallbackMs: 4000; /* AppFileHelper 兜底读取的超时阈值 */
    property color btnIconColor: "#434343";
    property color btnHoverColor: "#00eb81";
    property color btnIconRed: "#f45555";
    property color btnHoverRed: "#e44545";
    property color hoverDarkColor: "#e8e8e8";
    property color choseDarkColor: "#d8d8d8";
    property color choseCyanColor: "#00cc65";
    property color forbdDarkColor: "#bcbcbc";
    property color subGrey: "#e0e0e0";
    property color warnRed: "#ff4411";
    property color vipRed: "#fe3610";
    property color vipGold: "#ffc400";
}
pragma Singleton
import QtQuick

Item {
    visible: false;
    property string initTitle: "CryingMusic";
    property int windowPadding: 10;
    property int windowRaduis: 7;
    property int mainAreaRaduis: 7;
    property int edgeMouseAreaD: 5; /* 不要改变 */
    property int cornerMouseAreaD: 10; /* 不要改变 */
    property color canvasColor: "#f0f0f0";
    property color leftSidebarColor: "#f0f0f0";
    property color leftSidebarHeaderColor: "#f0f0f0";
    property color mainAreaColor: "#f6f6f6";
    property color topNavBarColor: "#f6f6f6";
    property int btnSize: 20;
    property int btnSpacing: 20;
    property color btnIconColor: "#434343";
    property color btnHoverColor: "#00eea8";
    property color hoverDarkColor: "#bcbcbc";
    property color subGrey: "#e0e0e0";
}
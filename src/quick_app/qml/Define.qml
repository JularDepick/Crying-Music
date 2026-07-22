import QtQuick

Item {
    visible: false;
    property string initTitle: "";
    property int windowPadding: 10;
    property int windowRaduis: 7;
    property int mainAreaRaduis: 7;
    property int edgeMouseAreaD: 5; /* 不要改变 */
    property int cornerMouseAreaD: 10; /* 不要改变 */
    property color canvasColor: "yellow"; //"#f7f1f3";
    property color leftSidebarColor: "orange";
    property color mainAreaColor: "red";
    property color topNavBarColor: "green";
}
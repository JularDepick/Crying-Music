import QtQuick
import QtQuick.Controls
import "./"

Rectangle {
    topLeftRadius: Define.windowRadius;
    topRightRadius: Define.windowRadius;
    bottomLeftRadius: Define.windowRadius;
    bottomRightRadius: Define.windowRadius;
    border.width: 0.5;
    border.color: Define.windowBorderColor;
    color: Define.canvasColor;
    /* 拖动窗口 */
    MouseArea {
        id: canvasDrag;
        anchors.fill: parent;
        anchors.margins: Define.edgeMouseAreaD;
        acceptedButtons: Qt.LeftButton;
        onPressed: (mouse)=> {
            var mx=mouse.x;
            var my=mouse.y;
            var d=Define.windowPadding-Define.edgeMouseAreaD;
            if(mx<d || my<d || mx>(leftSidebar.width+mainArea.width+d) || my>(leftSidebar.height+d)) {
                window.startSystemMove();
            }
        }
    }
    MouseArea {
        anchors.fill: parent;
        anchors.margins: edgeMouseAreaD;
    }
    function show() {
        visible=true;
    }
    function hide() {
        visible=false;
    }
    function tshow() {
        visible=!visible;
    }
}
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Qt.labs.platform

import "qml/"

ApplicationWindow {
    id: window;
    width: 1000;
    height: 620;
    minimumWidth: 1000;
    minimumHeight: 620;
    color: "transparent";
    visible: true;
    title: qsTr(define.initTitle);
    flags: Qt.Window | Qt.FramelessWindowHint;
    Define {id:define;}
    Assist {id:assit;}

    /* 系统托盘 */
    SystemTrayIcon {
        id: stIcon;
        visible: true;
        icon.source: "qrc:/favicon.jpg";
        tooltip: "";
        menu: Menu {
            id: stMenu;
            MenuItem {
               text: "退出";
               onTriggered: Qt.exit(0);
           }
           MenuSeparator {}
       }
       onActivated: (reason)=> {
           if (reason === SystemTrayIcon.Trigger) {
               if(window.visible === false) {
                   window.show()
                   window.raise()
                   window.requestActivate()
               } else {
                   window.hide();
               }
           }
       }
    }
    onClosing: (close)=> {
        if (stIcon.visible) {
            close.accepted=false;
            window.hide();
        }
    }

    /* 窗口边框拖拽 */
    MouseArea {
        anchors {left:parent.left; right:parent.right; top: parent.top;}
        height: define.edgeMouseAreaD;
        cursorShape: Qt.SizeVerCursor;
        onPressed: window.startSystemResize(Qt.TopEdge);
    }
    MouseArea {
        anchors {left:parent.left; right:parent.right; bottom:parent.bottom;}
        height: define.edgeMouseAreaD;
        cursorShape: Qt.SizeVerCursor;
        onPressed: window.startSystemResize(Qt.BottomEdge);
    }
    MouseArea {
        anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
        width: define.edgeMouseAreaD;
        cursorShape: Qt.SizeHorCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge);
    }
    MouseArea {
        anchors {right:parent.right; top:parent.top; bottom:parent.bottom;}
        width: define.edgeMouseAreaD;
        cursorShape: Qt.SizeHorCursor;
        onPressed: window.startSystemResize(Qt.RightEdge);
    }
    MouseArea {
        anchors {left:parent.left; top:parent.top;}
        width: define.cornerMouseAreaD;
        height: define.cornerMouseAreaD;
        cursorShape: Qt.SizeFDiagCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge | Qt.TopEdge);
    }
    MouseArea {
        anchors {right:parent.right; top:parent.top;}
        width: define.cornerMouseAreaD;
        height: define.cornerMouseAreaD;
        cursorShape: Qt.SizeBDiagCursor;
        onPressed: window.startSystemResize(Qt.RightEdge | Qt.TopEdge);
    }
    MouseArea {
        anchors {left:parent.left; bottom:parent.bottom;}
        width: 10;
        height: 10;
        cursorShape: Qt.SizeBDiagCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge | Qt.BottomEdge);
    }
    MouseArea {
        anchors {right:parent.right; bottom:parent.bottom;}
        width: define.cornerMouseAreaD;
        height: define.cornerMouseAreaD;
        cursorShape: Qt.SizeFDiagCursor;
        onPressed: window.startSystemResize(Qt.RightEdge | Qt.BottomEdge);
    }

    /* 主页面容器 */
    Rectangle {
        id: canvas;
        anchors.fill: parent;
        topLeftRadius: define.windowRaduis;
        topRightRadius: define.windowRaduis;
        bottomLeftRadius: define.windowRaduis;
        bottomRightRadius: define.windowRaduis;
        color: define.canvasColor;
        /* 拖动窗口 */
        MouseArea {
            anchors.fill: parent;
            anchors.margins: define.edgeMouseAreaD;
            acceptedButtons: Qt.LeftButton;
            onPressed: (mouse)=> {
                var mx=mouse.x;
                var my=mouse.y;
                var d=define.windowPadding-define.edgeMouseAreaD;
                if(mx<d || my<d || mx>(leftSidebar.width+mainArea.width+d) || my>(leftSidebar.height+d)) {
                    window.startSystemMove();
                }
            }
        }
        Rectangle {
            id: leftSidebar;
            anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
            anchors.leftMargin: define.windowPadding;
            anchors.topMargin: define.windowPadding;
            anchors.bottomMargin: define.windowPadding;
            topLeftRadius: define.mainAreaRaduis;
            topRightRadius: define.mainAreaRaduis;
            bottomLeftRadius: define.mainAreaRaduis;
            bottomRightRadius: define.mainAreaRaduis;
            width: 200;
            property int bigWidth: 200;
            property int smallWidth: 75;
            color: define.leftSidebarColor;
            /* 左侧栏的右边框拖拽 */
            MouseArea {
                anchors {right:parent.right; top:parent.top; bottom:parent.bottom;}
                width: 5;
                cursorShape: Qt.SizeHorCursor;
                property int dragStartX: 0;
                property int dragEndX: 0;
                onPressed: (mouse)=> {
                    dragStartX=mouse.x;
                }
                onPositionChanged: (mouse)=> {
                    dragEndX=mouse.x;
                }
                onReleased: {
                    if(dragEndX<dragStartX) {
                        parent.width=parent.smallWidth;
                    } else if(dragEndX>dragStartX) {
                        parent.width=parent.bigWidth;
                    }
                }
            }
        }
        Rectangle {
            id: topNavBar;
            anchors {left:leftSidebar.right;right:parent.right; top:parent.top;}
            anchors.topMargin: define.windowPadding;
            anchors.rightMargin: define.windowPadding;
            height: 30;
            topLeftRadius: define.mainAreaRaduis;
            topRightRadius: define.mainAreaRaduis;
            bottomLeftRadius: define.mainAreaRaduis;
            bottomRightRadius: define.mainAreaRaduis;
            color: define.topNavBarColor;
            /* 拖动窗口 */
            MouseArea {
                anchors.fill: parent;
                acceptedButtons: Qt.LeftButton;
                onPressed: window.startSystemMove();
            }
        }
        Rectangle {
            id: mainArea;
            anchors {left:leftSidebar.right;right:parent.right; top:topNavBar.bottom; bottom:parent.bottom;}
            anchors.rightMargin: define.windowPadding;
            anchors.bottomMargin: define.windowPadding;
            topLeftRadius: define.mainAreaRaduis;
            topRightRadius: define.mainAreaRaduis;
            bottomLeftRadius: define.mainAreaRaduis;
            bottomRightRadius: define.mainAreaRaduis;
            color: define.mainAreaColor;
        }
    }
}

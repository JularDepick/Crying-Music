import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Qt.labs.platform

import "qml/"

ApplicationWindow {
    id: window;
    width: 1050;
    height: 690;
    minimumWidth: 1050;
    minimumHeight: 690;
    color: "transparent";
    visible: true;
    title: qsTr(Define.initTitle);
    flags: Qt.Window | Qt.FramelessWindowHint;

    /* 系统托盘 */
    SystemTrayIcon {
        id: stIcon;
        visible: true;
        icon.source: "qrc:/favicon.jpg";
        tooltip: "泣水音乐";
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
        height: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeVerCursor;
        onPressed: window.startSystemResize(Qt.TopEdge);
    }
    MouseArea {
        anchors {left:parent.left; right:parent.right; bottom:parent.bottom;}
        height: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeVerCursor;
        onPressed: window.startSystemResize(Qt.BottomEdge);
    }
    MouseArea {
        anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
        width: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeHorCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge);
    }
    MouseArea {
        anchors {right:parent.right; top:parent.top; bottom:parent.bottom;}
        width: Define.edgeMouseAreaD;
        cursorShape: Qt.SizeHorCursor;
        onPressed: window.startSystemResize(Qt.RightEdge);
    }
    MouseArea {
        anchors {left:parent.left; top:parent.top;}
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
        cursorShape: Qt.SizeFDiagCursor;
        onPressed: window.startSystemResize(Qt.LeftEdge | Qt.TopEdge);
    }
    MouseArea {
        anchors {right:parent.right; top:parent.top;}
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
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
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
        cursorShape: Qt.SizeFDiagCursor;
        onPressed: window.startSystemResize(Qt.RightEdge | Qt.BottomEdge);
    }

    /* 主页面容器 */
    Rectangle {
        id: canvas;
        anchors.fill: parent;
        topLeftRadius: Define.windowRaduis;
        topRightRadius: Define.windowRaduis;
        bottomLeftRadius: Define.windowRaduis;
        bottomRightRadius: Define.windowRaduis;
        border.width: 0.5;
        border.color: "#aaaaaa";
        color: Define.canvasColor;
        /* 拖动窗口 */
        MouseArea {
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
        Rectangle {
            id: leftSidebar;
            anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
            anchors.leftMargin: Define.windowPadding;
            anchors.topMargin: Define.windowPadding;
            anchors.bottomMargin: Define.windowPadding;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            clip: true;
            width: 220;
            property int bigWidth: 220;
            property int smallWidth: 75;
            color: Define.leftSidebarColor;
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
                        Define.leftSidebarSpreaded=false;
                    } else if(dragEndX>dragStartX) {
                        parent.width=parent.bigWidth;
                        Define.leftSidebarSpreaded=ture;
                    }
                }
            }
            Rectangle {
                id: leftSidebarHeader;
                anchors {left:parent.left; right:parent.right; top:parent.top;}
                height: 65;
                topLeftRadius: Define.mainAreaRaduis;
                topRightRadius: Define.mainAreaRaduis;
                bottomLeftRadius: Define.mainAreaRaduis;
                bottomRightRadius: Define.mainAreaRaduis;
                color: Define.leftSidebarHeaderColor;
            }
        }
        Rectangle {
            id: topNavBar;
            anchors {left:leftSidebar.right;right:parent.right; top:parent.top;}
            anchors.topMargin: Define.windowPadding;
            anchors.rightMargin: Define.windowPadding;
            height: 65;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            color: Define.topNavBarColor;
            /* 拖动窗口 */
            MouseArea {
                anchors.fill: parent;
                acceptedButtons: Qt.LeftButton;
                property bool isDragging: false;
                onPressed: {
                    isDragging=false;
                }
                onPositionChanged: {
                    if (pressed && (!isDragging)) {
                        isDragging=true;
                        window.startSystemMove();
                    }
                }
                onDoubleClicked: {
                    if (!isDragging) {
                        if (window.visibility !== Window.Maximized) {
                            window.showMaximized();
                        } else {
                            window.visibility=Window.Windowed;
                        }
                    }
                }
            }
            Row {
                id: hisButtons;
                anchors {top:parent.top; left:parent.left;}
                leftPadding: 30;
                height: 50;
                spacing: Define.btnSpacing;
                TopNavBarButton {
                    id: backwardBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/backward.svg";
                    onClicked: {
                    }
                }
                TopNavBarButton {
                    id: forwardBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/forward.svg";
                    onClicked: {
                    }
                }
                TopNavBarButton {
                    id: refreshBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/refresh.svg";
                    onClicked: {
                    }
                }
            }
            Row {
                id: searchArea;
                anchors {top:parent.top; left:hisButtons.right;}
                leftPadding: 30;
                height: 50;
                TextField {
                    id: searchInput;
                    width: 200;
                    background: Rectangle {
                        color: "#d5d5d5";
                        height:30;
                        topLeftRadius: 8;
                        bottomLeftRadius: 8;
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                    anchors.verticalCenter: parent.verticalCenter;

                    placeholderText: "搜索音乐";
                }
                TopNavBarButton {
                    id: searchBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/search.svg";
                    background: Rectangle {
                        color: "#d5d5d5";
                        height: 30;
                        width: 25;
                        topRightRadius: 8;
                        bottomRightRadius: 8;
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                    anchors.verticalCenter: parent.verticalCenter;
                    onClicked: {
                    }
                }
            }
            Row {
                id: sysButtons;
                anchors {top:parent.top; right:parent.right;}
                rightPadding: 20;
                height: 50;
                spacing: Define.btnSpacing;
                TopNavBarButton {
                    id: flowWindowBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/flowized.svg";
                    onClicked: {
                        /* build flow window */
                        window.hide();
                    }
                }
                TopNavBarButton {
                    id: minWindowBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/minimized.svg";
                    onClicked: window.showMinimized();
                }
                TopNavBarButton {
                    id: maxWindowBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/maximized.svg";
                    onClicked: {
                        if (window.visibility !== Window.Maximized) {
                            maxWindowBtn.icon.source="qrc:/assets/iconfont/topnavbar/normalized.svg";
                            window.showMaximized();
                        } else {
                            maxWindowBtn.icon.source="qrc:/assets/iconfont/topnavbar/maximized.svg";
                            window.showNormal();
                        }
                    }
                }
                TopNavBarButton {
                    id: closeWindowBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/closewin.svg";
                    onClicked: window.hide();
                }
            }
        }
        Rectangle {
            id: mainArea;
            anchors {left:leftSidebar.right; right:parent.right; top:topNavBar.bottom; bottom:playerBar.top;}
            anchors.rightMargin: Define.windowPadding;
            anchors.bottomMargin: Define.windowPadding;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            color: Define.mainAreaColor;
        }
        Rectangle {
            id: playerBar;
            anchors {left:leftSidebar.right; right:parent.right; bottom:parent.bottom;}
            anchors.rightMargin: Define.windowPadding;
            anchors.bottomMargin: Define.windowPadding;
            height: 80;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            color: Define.mainAreaColor;
            Row {
                id: controlRows;
                anchors {top:parent.top; bottom:parent.bottom}
                anchors.horizontalCenter: parent.horizontalCenter;
                Row {
                    id: controlRowA;
                    anchors {top:parent.top;}
                    anchors.topMargin: 20;
                    anchors.horizontalCenter: parent.horizontalCenter;
                    height: 30;
                    spacing: Define.btnSpacing;
                    PlayerBarButton {
                        id: playerSort;
                        icon.source: "qrc:/assets/iconfont/playerbar/listsort.svg";
                        onClicked: {
                        }
                    }
                    PlayerBarButton {
                        id: lastOne;
                        icon.source: "qrc:/assets/iconfont/playerbar/lastone.svg";
                        onClicked: {
                        }
                    }
                    PlayerBarButton {
                        id: play_pause;
                        icon.source: svgBase+"play.svg";
                        hoverEnabled: false;
                        property string svgBase: "qrc:/assets/iconfont/playerbar/";
                        property bool playing: false;
                        onClicked: {
                            if(playing) {
                                icon.source=svgBase+"play.svg";
                                playing=false;
                            } else {
                                icon.source=svgBase+"pause.svg";
                                playing=true;
                            }
                            console.log("click play_pause, playing=",playing);
                        }
                    }
                    PlayerBarButton {
                        id: nextOne;
                        icon.source: "qrc:/assets/iconfont/playerbar/nextone.svg";
                        onClicked: {
                        }
                    }
                    PlayerBarButton {
                        id: soundCtrl;
                        icon.source: "qrc:/assets/iconfont/playerbar/sound.svg";
                        property int volume: 100;
                        property bool sliderVisible: false;
                        onClicked: {
                            sliderVisible=!sliderVisible;
                        }
                        Rectangle {
                            id: soundSliderArea;
                            visible: soundCtrl.sliderVisible;
                            width: 40;
                            height: 150;
                            anchors.centerIn: parent;
                            anchors.verticalCenterOffset: -(parent.height/2+height/2);
                            color: Define.mainAreaColor;
                            radius: 4;
                            border.color: Define.hoverDarkColor;
                            border.width: 1;
                            Slider {
                                id: soundSlider;
                                orientation: Qt.Vertical;
                                anchors.centerIn: parent;
                                width: 30;
                                height: parent.height-20;
                                from: 0;
                                to: 100;
                                stepSize: 1;
                                value: soundCtrl.volume;
                                onValueChanged: {
                                    soundCtrl.volume=value;
                                    console.log("音量:", value);
                                }
                                background: Rectangle {
                                    x: soundSlider.leftPadding+(soundSlider.availableWidth-width)/2;
                                    y: soundSlider.topPadding;
                                    width: 4;
                                    height: soundSlider.availableHeight;
                                    radius: 2;
                                    color: Define.hoverDarkColor;
                                    Rectangle {
                                        width: parent.width;
                                        height: (soundSlider.value/soundSlider.to)*parent.height;
                                        y: parent.height-height;
                                        radius: parent.radius;
                                        color: Define.btnIconColor;
                                    }
                                }
                                handle: Rectangle {
                                    x: soundSlider.leftPadding+(soundSlider.availableWidth-width)/2;
                                    y: soundSlider.topPadding+(1-soundSlider.value/soundSlider.to)*soundSlider.availableHeight-height/2;
                                    width: 14;
                                    height: 14;
                                    radius: 7;
                                    color: Define.btnIconColor;
                                    border.color: "white";
                                    border.width: 1;
                                }
                            }
                        }
                    }
                }
                Row {
                    id: controlRowB;
                    anchors {top:controlRowA.bottom; bottom:parent.bottom}
                    anchors.bottomMargin: 10;
                    anchors.horizontalCenter: parent.horizontalCenter;
                    height: 20;
                    spacing: 10;
                    Text {
                        id: nowStamp;
                        text: controlRowB.int2mmss(stampSlider.value);
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                    Slider {
                        id: stampSlider;
                        width: 200;
                        from: 0;
                        to: maxStamp;
                        stepSize: 1;
                        value: 0;
                        property int maxStamp: 100;
                        anchors.verticalCenter: parent.verticalCenter;
                        background: Rectangle {
                            x: stampSlider.leftPadding;
                            y: stampSlider.topPadding+(stampSlider.availableHeight-height)/2;
                            width: stampSlider.availableWidth;
                            height: 4;
                            radius: 2;
                            color: Define.hoverDarkColor;
                            border.color: Define.hoverDarkColor;
                            border.width: 0.5;
                            Rectangle {
                                width: stampSlider.visualPosition*parent.width;
                                height: parent.height;
                                radius: parent.radius;
                                color: Define.btnIconColor;
                                border.color: Define.btnIconColor;
                                border.width: 0.5;
                            }
                        }
                        handle: Rectangle {
                               x: stampSlider.leftPadding+stampSlider.visualPosition*stampSlider.availableWidth-width/2;
                               y: stampSlider.topPadding+(stampSlider.availableHeight-height)/2;
                               width: 12;
                               height: 12;
                               radius: 6;
                               color: Define.btnIconColor;
                               border.color: "white";
                               border.width: 1;
                               visible: parent.hovered || parent.pressed;
                        }
                        onPressedChanged: {
                            if(!pressed) {
                                ;
                            }
                        }
                    }
                    Text {
                        id: endStamp;
                        text: controlRowB.int2mmss(stampSlider.maxStamp);
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                    function int2mmss(num) {
                        num=Math.floor(num);
                        if(num<=0) {
                            return "00:00";
                        }
                        var ss=num%60;
                        var mm=Math.floor(num/60);
                        if(mm>=60) {
                            console.error("出现错误: 音频长度达到一小时上限!");
                            return "00:00";
                        }
                        var res="";
                        if(mm<10) {
                            res+="0";
                        }
                        res+=String(mm)+":";
                        if(ss<10) {
                            res+="0";
                        }
                        res+=String(ss);
                        return res;
                    }
                }
            }
        }
    }
}
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtMultimedia
import Qt.labs.platform

import "qml/"

ApplicationWindow {
    id: window;
    width: 1050;
    height: 690;
    minimumWidth: 1050;
    minimumHeight: 690;
    color: Define.nocolor;
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
            property bool spreaded: true;
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
                    if(dragEndX<dragStartX && parent.spreaded) {
                        parent.width=parent.smallWidth;
                        parent.spreaded=false;
                        stampSlider.width*=1.5;
                    } else if(dragEndX>dragStartX && !parent.spreaded) {
                        parent.width=parent.bigWidth;
                        parent.spreaded=true;
                        stampSlider.width/=1.5;
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
                id: topNavBarDrag;
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
            property int rowsTopMargin: 10;
            property int rowsHeight: 30;
            Row {
                id: hisButtons;
                anchors {top:parent.top; left:parent.left;}
                anchors.topMargin: parent.rowsTopMargin;
                leftPadding: 30;
                height: parent.rowsHeight;
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
                anchors {top: parent.top; left:hisButtons.right;}
                anchors.topMargin: parent.rowsTopMargin;
                anchors.verticalCenter: parent.verticalCenter;
                leftPadding: 30;
                height: parent.rowsHeight;
                TextField {
                    id: searchInput;
                    width: 200;
                    height: 30;
                    background: Rectangle {
                        color: "#d5d5d5";
                        topLeftRadius: 8;
                        bottomLeftRadius: 8;
                        anchors.fill: parent;
                    }
                    placeholderText: "搜索音乐";
                }
                TopNavBarButton {
                    id: searchBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/search.svg";
                    anchors.verticalCenter: searchInput.verticalCenter;
                    background: Rectangle {
                        color: "#d5d5d5";
                        width: 25;
                        height: 30;
                        topRightRadius: 8;
                        bottomRightRadius: 8;
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                    onClicked: {
                    }
                }
            }
            Row {
                id: sysButtons;
                anchors {top:parent.top; right:parent.right;}
                anchors.topMargin: parent.rowsTopMargin;
                rightPadding: 20;
                height: parent.rowsHeight;
                spacing: Define.btnSpacing;
                TopNavBarButton {
                    id: flowCardWinBtn;
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
                id: functionRows;
                anchors {left:parent.left; top:parent.top; bottom:parent.bottom}
                leftPadding: 12.5;
                Rectangle {
                    id: lyricsOpener;
                    anchors {top:parent.top; bottom:parent.bottom}
                    anchors.margins: 12.5;
                    width: height;
                    radius: 5;
                    Image {
                        id: lyricsOpenerImage;
                        anchors.fill: parent;
                        source: "qrc:/favicon.jpg";
                    }
                    CustomButtonA {
                        id: lyricsOpenerBtn;
                        anchors.fill: parent;
                        icon.source: (hovered? "qrc:/assets/iconfont/playerbar/lyricsopen.svg":"");
                        icon.color: Define.mainAreaColor;
                        icon.width: parent.width-5;
                        icon.height: parent.width-5;
                        onClicked: {
                            canvas.visible=false;
                            lyricsSubTab.visible=true;
                            console.log("clicked lyricsOpenerBtn");
                        }
                        background: Rectangle {
                            color: (parent.hovered? Qt.rgba(0,0,0,0.4):Define.nocolor)  ;
                            border.color: Define.subGrey;
                            border.width: 1;
                            radius: parent.parent.radius;
                        }
                    }
                }
                Column {
                    id: functionSubRows;
                    anchors {top:parent.top; bottom:parent.bottom}
                    leftPadding: 12.5;
                    topPadding: 15;
                    spacing: 10;
                    Row {
                        id: functionSubRowA;
                        spacing: 5;
                        Text {
                            id: plsyingTitle;
                            anchors.verticalCenter: parent.verticalCenter;
                            text: `${song} - ${singer}`;
                            font.pixelSize: 14;
                            property string song: "曲名";
                            property string singer: "歌手";
                        }
                        PlayerBarButton {
                            id: playingVIP;
                            anchors.verticalCenter: parent.verticalCenter;
                            icon.source: "qrc:/assets/iconfont/vip/viptip.svg";
                            icon.color: Define.btnHoverColor;
                            transEnalbed: false;
                            height: 20;
                            width: 20;
                        }
                    }
                    Row {
                        id: functionSubRowB;
                        spacing: 10;
                        PlayerBarButton {
                            id: likeSongBtn;
                            icon.source: (liked? "qrc:/assets/iconfont/function/liked.svg":"qrc:/assets/iconfont/function/like.svg");
                            icon.color: (liked? (hovered? Define.btnHoverRed:Define.btnIconRed):(hovered? Define.btnIconRed:Define.btnIconColor));
                            property bool liked: false;
                            onClicked: {
                                liked=!liked;
                            }
                        }
                        PlayerBarButton {
                            id: moreFunBtn;
                            icon.source: "qrc:/assets/iconfont/function/more.svg";
                            property bool subTabVisible: false;
                            onClicked: {
                                subTabVisible=!subTabVisible;
                            }
                            Rectangle {
                                id: moreFunSubTab;
                                anchors.centerIn: parent;
                                anchors.verticalCenterOffset: -(parent.height/2+height/2+10);
                                width: 90;
                                height: (150);
                                visible: parent.subTabVisible;
                                color: Define.mainAreaColor;
                                radius: 8;
                                border.color: Define.subGrey;
                                border.width: 1;
                                Column {
                                    anchors {left:parent.left; right:parent.right;}
                                    anchors.verticalCenter: parent.verticalCenter;
                                    topPadding: 2;
                                    Repeater {
                                        model: ListModel {
                                            ListElement {name:"Fun"; svgname:"function"; num:0;}
                                        }
                                        delegate: CustomButtonA {
                                            anchors.horizontalCenter: parent.horizontalCenter;
                                            width: sortSubTab.width-8;
                                            height: 30;
                                            onClicked: {
                                            }
                                            background: Rectangle {
                                                anchors.fill: parent;
                                                color: (hovered? Define.canvasColor:Define.mainAreaColor);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
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
                        property int sortID: 0;
                        /* 0 randomsort
                           1 listsort
                           2 cycleone
                           3 cyclelist
                        */
                        property bool subTabVisible: false;
                        onClicked: {
                            subTabVisible=!subTabVisible;
                        }
                        Rectangle {
                            id: sortSubTab;
                            anchors.centerIn: parent;
                            anchors.verticalCenterOffset: -(parent.height/2+height/2+10);
                            width: 90;
                            height: (4*(30+2)+4);
                            visible: parent.subTabVisible;
                            color: Define.mainAreaColor;
                            radius: 8;
                            border.color: Define.subGrey;
                            border.width: 1;
                            Column {
                                anchors {left:parent.left; right:parent.right;}
                                topPadding: 2;
                                Repeater {
                                    model: ListModel {
                                        ListElement {name:"随机播放"; svgname:"randomsort"; num:0;}
                                        ListElement {name:"顺序播放"; svgname:"listsort"; num:1;}
                                        ListElement {name:"单曲循环"; svgname:"cycleone"; num:2;}
                                        ListElement {name:"列表循环"; svgname:"cyclelist"; num:3;}
                                    }
                                    delegate: Button {
                                        anchors.horizontalCenter: parent.horizontalCenter;
                                        width: sortSubTab.width-8;
                                        height: 30;
                                        onClicked: {
                                            playerSort.subTabVisible=false;
                                            playerSort.sortID=num;
                                            playerSort.icon.source=`qrc:/assets/iconfont/playerbar/${svgname}.svg`;
                                        }
                                        background: Rectangle {
                                            anchors.fill: parent;
                                            color: (hovered? Define.canvasColor:Define.mainAreaColor);
                                            radius: 4;
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter;
                                                anchors.verticalCenter: parent.verticalCenter;
                                                spacing: 4;
                                                Image {
                                                    anchors.verticalCenter: parent.verticalCenter;
                                                    width: 20;
                                                    height: 20;
                                                    source: `qrc:/assets/iconfont/playerbar/${svgname}.svg`;
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter;
                                                    text: name;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
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
                            } else {
                                icon.source=svgBase+"pause.svg";
                            }
                            playing=!playing;
                            console.log("click play_pause, playing=",playing);
                        }
                        transEnalbed: false;
                        background: Rectangle {
                            anchors.centerIn: parent;
                            width: parent.width+20;
                            height: parent.height+10;
                            color: Define.btnHoverColor;
                            topRightRadius: height/2;
                            topLeftRadius: height/2;
                            bottomRightRadius: height/2;
                            bottomLeftRadius: height/2;
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
                            anchors.centerIn: parent;
                            anchors.verticalCenterOffset: -(parent.height/2+height/2+5);
                            visible: soundCtrl.sliderVisible;
                            width: 36;
                            height: 160;
                            color: Define.mainAreaColor;
                            radius: 8;
                            border.color: Define.subGrey;
                            border.width: 1;
                            Column {
                                anchors.fill: parent;
                                anchors.topMargin: 8;
                                spacing: 5;
                                PlayerBarSliderB {
                                    id: soundSlider;
                                    anchors.horizontalCenter: parent.horizontalCenter;
                                    height: 120;
                                    value: soundCtrl.volume;
                                    onValueChanged: {
                                        soundCtrl.volume=value;
                                        console.log("音量:", value);
                                    }
                                }
                                PlayerBarButton {
                                    id: muteBtn;
                                    anchors.horizontalCenter: parent.horizontalCenter;
                                    icon.source: "qrc:/assets/iconfont/playerbar/sound.sub.svg";
                                    property bool muted: false;
                                    onClicked: {
                                        if(muted) {
                                            icon.source="qrc:/assets/iconfont/playerbar/sound.sub.svg";
                                            soundCtrl.icon.source="qrc:/assets/iconfont/playerbar/sound.svg";
                                            soundCtrl.volume=100;
                                        } else {
                                            icon.source="qrc:/assets/iconfont/playerbar/soundless.sub.svg";
                                            soundCtrl.icon.source="qrc:/assets/iconfont/playerbar/soundless.svg";
                                            soundCtrl.volume=0;
                                        }
                                        muted=!muted;
                                    }
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
                        text: Assist.int2mmss(stampSlider.value);
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                    PlayerBarSliderA {
                        id: stampSlider;
                        anchors.verticalCenter: parent.verticalCenter;
                        onPressedChanged: {
                            if(!pressed) {
                                console.log("音频进度：",value);
                            }
                        }
                    }
                    Text {
                        id: endStamp;
                        text: Assist.int2mmss(stampSlider.maxStamp);
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                }
            }
            Row {
                id: configRow;
                anchors {right:parent.right;}
                anchors.verticalCenter: parent.verticalCenter;
                spacing: 12.5;
                rightPadding: 25;
                PlayerBarButton {
                    id: lyricsCardBtn;
                    icon.source: "qrc:/assets/iconfont/playerbar/lyricsflow.svg";
                }
                PlayerBarButton {
                    id: playingListBtn;
                    icon.source: "qrc:/assets/iconfont/playerbar/playerlist.svg";
                    property bool showed: false;
                    onClicked: {
                        if(showed) {
                            sysButtons.visible=true;
                        } else {
                            sysButtons.visible=false;
                        }
                        showed=!showed;
                    }
                }
            }
        }
        Rectangle {
            id: playingListArea;
            anchors {top:canvas.top; bottom:mainArea.bottom; right: canvas.right;}
            anchors.rightMargin: Define.windowPadding;
            anchors.topMargin: Define.windowPadding;
            topLeftRadius: Define.mainAreaRaduis;
            topRightRadius: Define.mainAreaRaduis;
            bottomLeftRadius: Define.mainAreaRaduis;
            bottomRightRadius: Define.mainAreaRaduis;
            color: Define.mainAreaColor;
            width: 450;
            border.color: Define.subGrey;
            border.width: 1;
            visible: playingListBtn.showed;
        }
    }
    LyricsSubTab {
        id: lyricsSubTab;
        anchors.fill: parent;
        visible: false;
    }
}
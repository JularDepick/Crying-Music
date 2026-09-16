import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Basic
import QtMultimedia
import Qt.labs.platform

import AppHelpers 1.0

import "qml/"

ApplicationWindow {
    id: window;
    width: 1050;
    height: 690;
    minimumWidth: 1050;
    minimumHeight: 690;
    color: Define.nocolor;
    visible: false;
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
            function spread(b=true) {
                if(b===true && !spreaded) {
                    leftSidebar.spreaded=false;
                    leftSidebar.width=leftSidebar.bigWidth;
                    leftSidebar.spreaded=true;
                } else if(b===false && spreaded) {
                    leftSidebar.spreaded=false;
                    leftSidebar.width=leftSidebar.smallWidth;
                    leftSidebar.spreaded=false;
                }
            }
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
                        parent.spread(false);
                    } else if(dragEndX>dragStartX && !parent.spreaded) {
                        parent.spread(true);
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
                Row {
                    anchors {top:parent.top; bottom:parent.bottom;}
                    x: (leftSidebar.spreaded? Define.windowPadding*2:(leftSidebarHeader.width-width)/2);
                    spacing: 10;
                    Button {
                        anchors {top:parent.top; bottom:parent.bottom;}
                        anchors.topMargin: 8;
                        anchors.bottomMargin: 8;
                        width: height;
                        background: Image {
                            anchors.fill: parent;
                            id: userAvatar;
                            source: "qrc:/favicon.jpg";
                            fillMode: Image.PreserveAspectCrop;
                            layer.enabled: true;
                            layer.effect: MultiEffect {
                                maskEnabled: true;
                                maskSource: userAvatarMasker;
                            }
                            Item {
                                id: userAvatarMasker;
                                anchors.fill: parent;
                                visible: false;
                                layer.enabled: true;
                                Rectangle {
                                    anchors.fill: parent;
                                    radius: height/2;
                                    border.color: Define.subGrey;
                                    border.width: 0.5;
                                }
                            }
                        }
                    }
                    Column {
                        anchors {top:parent.top; bottom:parent.bottom;}
                        topPadding: 15;
                        spacing: 5;
                        visible: leftSidebar.spreaded;
                        Row {
                            spacing: 4;
                            Text {
                                id: userName;
                                text: "用户名";
                            }
                            Text {
                                id: userLevel;
                                text: "Lv.100";
                            }
                        }
                        Row {
                            CustomButtonA {
                                id: userVIP;
                                icon.source: "qrc:/assets/iconfont/vip/vip10.svg";
                                icon.color: Define.vipRed;
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: leftSidebarBody;
                anchors {top:leftSidebarHeader.bottom; bottom:leftSidebarFoot.top; left:parent.left; right:parent.right;}
                color: Define.canvasColor;
                property var svg2obj: ({
                    "likedlist": mainArea_LikedPage,
                    "recentlist": mainArea_RecentPage,
                    "locallist": mainArea_LocalPage
                });
                Column {
                    anchors.fill: parent;
                    anchors.topMargin: 10;
                    anchors.rightMargin: Define.windowPadding;
                    spacing: 1;
                    Repeater {
                        model: ListModel {
                            ListElement {svgname:"likedlist"; title:"喜欢"}
                            ListElement {svgname:"recentlist"; title:"最近播放"}
                            ListElement {svgname:"locallist"; title:"本地"}
                        }
                        delegate: Button {
                            height: 50;
                            x: (leftSidebar.spreaded? Define.windowRaduis:(parent.width-width)/2);
                            width: (leftSidebar.spreaded? (parent.width-Define.windowRaduis*2):height);
                            property var obj2: leftSidebarBody.svg2obj[svgname];
                            background: Rectangle {
                                anchors.fill: parent;
                                color: (obj3.visible? (Define.choseDarkColor):(hovered? Define.hoverDarkColor:Define.canvasColor));
                                radius: 10;
                                property var obj3: parent.obj2;
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter;
                                    x: (leftSidebar.spreaded? Define.windowRaduis*2:(parent.width-width)/2);
                                    spacing: 8;
                                    property var obj4: parent.obj3;
                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter;
                                        width: 25;
                                        height: 25;
                                        source: `qrc:/assets/iconfont/leftsidebar/${svgname}`+(parent.obj4.visible? "_ed":"")+".svg";
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter;
                                        text: title;
                                        font.pixelSize: 14;
                                        visible: leftSidebar.spreaded;
                                    }
                                }
                            }
                            onClicked: {
                                mainArea.jump2(obj2);
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: leftSidebarFoot;
                anchors {bottom:parent.bottom; left:parent.left;}
                anchors.bottomMargin: Define.windowPadding;
                width: (parent.width-Define.windowPadding);
                height: 25;
                color: Define.canvasColor;
                Row {
                    anchors.verticalCenter: parent.verticalCenter;
                    anchors.leftMargin: Define.windowPadding;
                    x: (leftSidebar.spreaded? (Define.windowPadding*2):(parent.width-width)/2);
                    spacing: 20;
                    CustomButtonA {
                        icon.source: `qrc:/assets/iconfont/leftsidebar/spread${leftSidebar.spreaded? "ed":""}.svg`;
                        onClicked: {
                            leftSidebar.spread(!leftSidebar.spreaded);
                        }
                    }
                    CustomButtonA {
                        icon.source: "qrc:/assets/iconfont/leftsidebar/settings.svg";
                        visible: leftSidebar.spreaded;
                    }
                    CustomButtonA {
                        icon.source: "qrc:/assets/iconfont/leftsidebar/theme.svg";
                        visible: leftSidebar.spreaded;
                    }
                }
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
                            window.showNormal();
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
                    icon.color: (mainArea.uhis.length<=0? Define.forbdDarkColor:(hovered&&hoverColor? Define.btnHoverColor:Define.btnIconColor));
                    transEnalbed: mainArea.uhis.length>0;
                    onClicked: {
                        mainArea.undo();
                    }
                }
                TopNavBarButton {
                    id: forwardBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/forward.svg";
                    icon.color: (mainArea.rhis.length<=0? Define.forbdDarkColor:(hovered&&hoverColor? Define.btnHoverColor:Define.btnIconColor));
                    transEnalbed: mainArea.rhis.length>0;
                    onClicked: {
                        mainArea.redo();
                    }
                }
                TopNavBarButton {
                    id: refreshBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/refresh.svg";
                    onClicked: {
                        mainArea.refresh();
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
                    transEnalbed: false;
                    background: Rectangle {
                        color: "#d5d5d5";
                        width: 25;
                        height: 30;
                        topRightRadius: 8;
                        bottomRightRadius: 8;
                        anchors.verticalCenter: parent.verticalCenter;
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
                    icon.source: (window.visibility==Window.Maximized? "qrc:/assets/iconfont/topnavbar/normalized.svg":"qrc:/assets/iconfont/topnavbar/maximized.svg");
                    onClicked: {
                        if (window.visibility !== Window.Maximized) {
                            window.showMaximized();
                        } else {
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
            property var uhis: [];
            property var rhis: [];
            property var curr: mainArea_HomePage;
            function _show(which) {
                if(curr===which) {
                    return;
                }
                curr.visible=false;
                curr=which;
                curr.visible=true;
            }
            function undo() {
                if(uhis.length<=0) {
                    return;
                }
                var utop=uhis[uhis.length-1];
                var uarr=uhis.slice();
                uarr.pop();
                uhis=uarr;
                var rarr=rhis.slice();
                rarr.push(curr);
                rhis=rarr;
                _show(utop);
            }
            function redo() {
                if(rhis.length<=0) {
                    return;
                }
                var rtop=rhis[rhis.length-1];
                var rarr=rhis.slice();
                rarr.pop();
                rhis=rarr;
                var uarr=uhis.slice();
                uarr.push(curr);
                uhis=uarr;
                _show(rtop);
            }
            function jump2(which) {
                if(curr===which) {
                    return;
                }
                var uarr=uhis.slice();
                uarr.push(curr);
                uhis=uarr;
                rhis=[];
                _show(which);
            }
            function refresh() {
                if(curr!==undefined && curr.refresh) {
                    curr.refresh();
                }
            }
            MainAreaHomePage {
                id: mainArea_HomePage;
                anchors.fill: parent;
                visible: true;
            }
            MainAreaLikedPage {
                id: mainArea_LikedPage;
                anchors.fill: parent;
            }
            MainAreaRecentPage {
                id: mainArea_RecentPage;
                anchors.fill: parent;
            }
            MainAreaLocalPage {
                id: mainArea_LocalPage;
                anchors.fill: parent;
            }
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
            MediaPlayer {
                id: player;
                audioOutput: AudioOutput {
                    id: audioOutputer;
                    volume: soundCtrl.volume/100;
                }
                source: AppPathHelper.getAbsolutePath("");
                onErrorOccurred: (error, errorString)=>{
                    console.error("音频播放错误:",error,errorString);
                }
                onMediaStatusChanged: {
                    if(mediaStatus===MediaPlayer.EndOfMedia) {
                        console.log("播放结束: ",source);
                    }
                }
                property var id2obj: new Map();
                property var songobjs: [];
                property int playingWhich: 0;
                property var sortlist: [];
                /*{
                    {"songname":"心做し心理作用","singer":"双笙、陈元汐","path":"music/心做し_心理作用_双笙_陈元汐_.mp3","pathtype":"rel"}
                };*/
            }
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
                    spacing: ((leftSidebar.spreaded? 1.5:2)*Define.btnSpacing);
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
                                            color: (hovered? Define.hoverDarkColor:Define.mainAreaColor);
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
                        icon.source: svgBase+(playing? "pause.svg":"play.svg");
                        hoverEnabled: false;
                        property string svgBase: "qrc:/assets/iconfont/playerbar/";
                        property bool playing: player.playing;
                        onClicked: {
                            if(playing) {
                                player.pause();
                            } else {
                                player.play();
                            }
                            stampSlider.value=Math.floor(player.position/1000);
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
                        icon.source: (volume==0? "qrc:/assets/iconfont/playerbar/soundless.svg":"qrc:/assets/iconfont/playerbar/sound.svg");
                        property int volume: soundSlider.value;
                        property bool sliderVisible: false;
                        onClicked: {
                            sliderVisible=!sliderVisible;
                        }
                        Rectangle {
                            id: soundSliderArea;
                            anchors.centerIn: parent;
                            anchors.verticalCenterOffset: -(parent.height/2+height/2+5);
                            visible: soundCtrl.sliderVisible;
                            width: 40;
                            height: 180;
                            color: Define.mainAreaColor;
                            radius: 8;
                            border.color: Define.subGrey;
                            border.width: 1;
                            Column {
                                anchors.fill: parent;
                                anchors.topMargin: 8;
                                spacing: 3;
                                Text {
                                    text: `${soundSlider.value}%`;
                                    anchors.horizontalCenter: parent.horizontalCenter;
                                }
                                PlayerBarSliderB {
                                    id: soundSlider;
                                    anchors.horizontalCenter: parent.horizontalCenter;
                                    height: 120;
                                    value: 100;
                                    onValueChanged: {
                                        soundCtrl.volume=value;
                                        console.log("音量: ",soundCtrl.volume);
                                    }
                                }
                                PlayerBarButton {
                                    id: muteBtn;
                                    anchors.horizontalCenter: parent.horizontalCenter;
                                    icon.source: (soundCtrl.volume==0? "qrc:/assets/iconfont/playerbar/soundless.sub.svg":"qrc:/assets/iconfont/playerbar/sound.sub.svg");
                                    onClicked: {
                                        if(soundCtrl.volume==0) {
                                            soundCtrl.volume=soundSlider.value;
                                        } else {
                                            soundCtrl.volume=0;
                                        }
                                        console.log("音量: ",soundCtrl.volume);
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
                        text: Assist.int2mmss(stampSlider.showedValue);
                        anchors.verticalCenter: parent.verticalCenter;
                    }
                    PlayerBarSliderA {
                        id: stampSlider;
                        width: playerBar.width*0.3;
                        anchors.verticalCenter: parent.verticalCenter;
                        maxStamp: Math.floor(player.duration/1000);
                        property int showedValue: (pressed? value:Math.floor(player.position/1000));
                        onPressedChanged: {
                            if(!pressed) {
                                player.position=value*1000;
                                console.log("音频进度：",value);
                                if(!player.playing) {
                                    player.play();
                                }
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
            MouseArea {
                anchors.fill: parent;
            }
        }
    }
    LyricsSubTab {
        id: lyricsSubTab;
        anchors.fill: parent;
        visible: false;
    }
    Component.onCompleted: {
        console.log("UI加载成功,开始读取程序储存");
        window.visible=true;
    }
}
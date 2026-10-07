import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Basic
import QtQuick.Controls.impl
import QtMultimedia
import Qt.labs.platform

import AppHelper 1.0

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
        width: Define.cornerMouseAreaD;
        height: Define.cornerMouseAreaD;
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
            property var svg2obj: ({
                "profile" : mainArea_ProfilePage,
                "home" : mainArea_HomePage,
                "likedlist" : mainArea_LikedPage,
                "recentlist" : mainArea_RecentPage,
                "locallist" : mainArea_LocalPage,
                "settings" : mainArea_SettingsPage,
                "theme" : mainArea_ThemePage
            });
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
                    topPadding: 10;
                    spacing: 10;
                    CustomButtonA {
                        height: 50;
                        width: height;
                        transEnabled: false;
                        onClicked: {
                            mainArea.jump2(leftSidebar.svg2obj["profile"]);
                        }
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
                        anchors.topMargin: 15;
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
                                transEnabled: false;
                                hoverHandlerEnabled: false;
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: leftSidebarBody;
                anchors {top:leftSidebarHeader.bottom; bottom:leftSidebarFoot.top; left:parent.left; right:parent.right;}
                color: Define.canvasColor;
                property var svg2obj: parent.svg2obj;
                Column {
                    anchors.fill: parent;
                    anchors.topMargin: 10;
                    anchors.rightMargin: Define.windowPadding;
                    spacing: 1;
                    Repeater {
                        model: ListModel {
                            ListElement {svgname:"home"; title:"首页推荐"}
                            ListElement {svgname:"likedlist"; title:"我的喜欢"}
                            ListElement {svgname:"recentlist"; title:"最近播放"}
                            ListElement {svgname:"locallist"; title:"本地和下载"}
                        }
                        delegate: CustomButtonA {
                            height: 50;
                            x: (leftSidebar.spreaded? Define.windowRadius:(parent.width-width)/2);
                            width: (leftSidebar.spreaded? (parent.width-Define.windowRadius*2):height);
                            property var obj2: leftSidebar.svg2obj[svgname];
                            transEnabled: false;
                            background: Rectangle {
                                anchors.fill: parent;
                                color: (obj3.visible? (Define.choseDarkColor):(hovered? Define.hoverDarkColor:Define.canvasColor));
                                radius: 10;
                                property var obj3: parent.obj2;
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter;
                                    x: (leftSidebar.spreaded? Define.windowRadius*2:(parent.width-width)/2);
                                    spacing: 8;
                                    property var obj4: parent.obj3;
                                    ColorImage  {
                                        anchors.verticalCenter: parent.verticalCenter;
                                        width: 25;
                                        height: 25;
                                        source: `qrc:/assets/iconfont/leftsidebar/${svgname}`+(parent.obj4.visible? "_ed":"")+".svg";
                                        color: Define.btnIconColor;
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
                        onClicked: {
                            mainArea.jump2(leftSidebar.svg2obj["settings"]);
                        }
                    }
                    CustomButtonA {
                        icon.source: "qrc:/assets/iconfont/leftsidebar/theme.svg";
                        visible: leftSidebar.spreaded;
                        onClicked: {
                            mainArea.jump2(leftSidebar.svg2obj["theme"]);
                        }
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
                    icon.color: (mainArea.uhis.length<=0? Define.forbdDarkColor:(hovered&&hoverColorEnabled? Define.btnHoverColor:Define.btnIconColor));
                    transEnabled: mainArea.uhis.length>0;
                    hoverHandlerEnabled: transEnabled;
                    onClicked: {
                        mainArea.undo();
                    }
                }
                TopNavBarButton {
                    id: forwardBtn;
                    icon.source: "qrc:/assets/iconfont/topnavbar/forward.svg";
                    icon.color: (mainArea.rhis.length<=0? Define.forbdDarkColor:(hovered&&hoverColorEnabled? Define.btnHoverColor:Define.btnIconColor));
                    transEnabled: mainArea.rhis.length>0;
                    hoverHandlerEnabled: transEnabled;
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
                    transEnabled: false;
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
                    icon.color: (((hovered&&hoverColorEnabled)||showed)? Define.btnHoverColor:Define.btnIconColor);
                    property bool showed: false;
                    onClicked: {
                        /* build flow card */
                        if(!showed) {
                            window.hide();
                        }

                        showed=!showed;
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
            clip: true;
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
            MainAreaProfilePage {
                id: mainArea_ProfilePage;
                anchors.fill: parent;
            }
            MainAreaHomePage {
                id: mainArea_HomePage;
                anchors.fill: parent;
                visible: true;
            }
            MainAreaLikedPage {
                id: mainArea_LikedPage;
                thePlayer: player;
                anchors.fill: parent;
            }
            MainAreaRecentPage {
                id: mainArea_RecentPage;
                thePlayer: player;
                anchors.fill: parent;
            }
            MainAreaLocalPage {
                id: mainArea_LocalPage;
                thePlayer: player;
                theProber: fakePlayer;
                anchors.fill: parent;
            }
            MainAreaSettingsPage {
                id: mainArea_SettingsPage;
                anchors.fill: parent;
            }
            MainAreaThemePage {
                id: mainArea_ThemePage;
                anchors.fill: parent;
            }
        }
        /* 播放栏 */
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
                id: fakePlayer;
                source: "";
            }
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
                        player.playNext(true);
                    }
                }
                property var id2obj: new Map();
                property var songobjs: ([]);
                /* 播放状态: 本模块自己持有, 每次改动后同步到存储枢纽 */
                property string playingWhich: "";
                property int playingIndex: -1;
                property var sortlist: ([]);
                /* 播放顺序: 0 随机播放, 1 顺序播放, 2 单曲循环, 3 列表循环 */
                property int playMode: 1;
                /*[
                    {songname:"心做し 心理作用", singer:"双笙-陈元汐", absfpath:"file:///C:\\Users\\liwenfang\\GitHub\\JularDepick\\Crying-Music\\src\\quick_app\\心做し_心理作用_双笙_陈元汐_.mp3"}
                ];*/
                function jump2play(which) {
                    if(AppFileHelper.existsFile(which.absfpath)===false) {
                        console.error("跳转错误: ",which);
                        return false;
                    }
                    sortlist=insertAfterPlaying(which);
                    playingWhich=which.absfpath;
                    syncPlayingIndex();
                    syncPlayState();
                    source=playingWhich;
                    GlobalFileStorage.addRecent(playingWhich);
                    player.play();
                    console.log("跳转成功: ",which);
                    return true;
                }
                function insertNext(which) {
                    if(which===undefined || which.absfpath===undefined) {
                        console.error("插入错误: ",which);
                        return false;
                    }
                    sortlist=insertAfterPlaying(which);
                    syncPlayingIndex();
                    syncPlayState();
                    console.log("插入下一首: ",which);
                    return true;
                }
                /* 去重后插到当前播放项之后, 当前无播放项时追加到末尾 */
                function insertAfterPlaying(which) {
                    var asl=[];
                    var l=sortlist.length;
                    for(var i=0;i<l;i++) {
                        if(sortlist[i].absfpath!==which.absfpath) {
                            asl.push(sortlist[i]);
                        }
                    }
                    var res=[];
                    var n=asl.length;
                    var done=false;
                    for(var j=0;j<n;j++) {
                        res.push(asl[j]);
                        if(done===false && asl[j].absfpath===playingWhich) {
                            res.push(which);
                            done=true;
                        }
                    }
                    if(done===false) {
                        res.push(which);
                    }
                    return res;
                }
                /* 以整份列表构造播放队列并开始播放 */
                function playAll(list,which) {
                    if(list===undefined || list.length<=0) {
                        console.error("播放失败: 列表为空");
                        return false;
                    }
                    var one=(which===undefined? list[0]:which);
                    if(AppFileHelper.existsFile(one.absfpath)===false) {
                        console.error("播放错误: ",one);
                        return false;
                    }
                    sortlist=list.slice();
                    if(playMode===0) {
                        /* 随机播放: 换列表时同样先打乱 */
                        sortlist=shuffleList(sortlist);
                    }
                    playingWhich=one.absfpath;
                    syncPlayingIndex();
                    syncPlayState();
                    source=playingWhich;
                    GlobalFileStorage.addRecent(playingWhich);
                    player.play();
                    console.log("播放列表: ",sortlist.length);
                    return true;
                }
                /* 直接切到队列中的某一项播放, 不改动队列顺序 */
                function playItem(which) {
                    if(AppFileHelper.existsFile(which.absfpath)===false) {
                        console.error("跳转错误: ",which);
                        return false;
                    }
                    playingWhich=which.absfpath;
                    syncPlayingIndex();
                    syncPlayState();
                    source=playingWhich;
                    GlobalFileStorage.addRecent(playingWhich);
                    player.play();
                    return true;
                }
                /* 播放队列中指定下标的项 */
                function playIndex(idx) {
                    var l=sortlist.length;
                    if(idx<0 || idx>=l) {
                        return false;
                    }
                    playingIndex=idx;
                    playingWhich=sortlist[idx].absfpath;
                    syncPlayState();
                    source=playingWhich;
                    GlobalFileStorage.addRecent(playingWhich);
                    player.play();
                    return true;
                }
                /* 下一曲: auto 为 true 表示播放结束后的自动切换 */
                function playNext(auto) {
                    var l=sortlist.length;
                    if(l<=0) {
                        return false;
                    }
                    if(auto===true && playMode===2) {
                        /* 单曲循环: 重播当前项 */
                        position=0;
                        play();
                        return true;
                    }
                    var next=playingIndex+1;
                    if(next<l) {
                        return playIndex(next);
                    }
                    if(playMode===1) {
                        /* 顺序播放: 自动切换时停止 */
                        if(auto===true) {
                            stop();
                            console.log("顺序播放结束");
                        }
                        return false;
                    }
                    if(playMode===0) {
                        /* 随机播放: 重新打乱后从头播放 */
                        sortlist=shuffleList(sortlist);
                    }
                    return playIndex(0);
                }
                /* 上一曲 */
                function playPrev() {
                    var l=sortlist.length;
                    if(l<=0) {
                        return false;
                    }
                    var prev=playingIndex-1;
                    if(prev<0) {
                        if(playMode===1) {
                            return false;
                        }
                        prev=l-1;
                    }
                    return playIndex(prev);
                }
                /* 切换播放顺序: 切到随机时立即打乱当前队列 */
                function setPlayMode(mode) {
                    playMode=mode;
                    if(mode===0) {
                        sortlist=shuffleList(sortlist);
                        syncPlayingIndex();
                    }
                    syncPlayState();
                    console.log("播放顺序: ",mode);
                }
                /* 打乱列表顺序 */
                function shuffleList(v) {
                    var res=v.slice();
                    for(var i=res.length-1;i>0;i--) {
                        var j=Math.floor(Math.random()*(i+1));
                        var tmp=res[i];
                        res[i]=res[j];
                        res[j]=tmp;
                    }
                    return res;
                }
                /* 当前播放项在队列中的下标, 未找到返回 -1 */
                function indexOfPlaying() {
                    var l=sortlist.length;
                    for(var i=0;i<l;i++) {
                        if(sortlist[i].absfpath===playingWhich) {
                            return i;
                        }
                    }
                    return -1;
                }
                /* 同步当前播放项下标 */
                function syncPlayingIndex() {
                    playingIndex=indexOfPlaying();
                    return playingIndex;
                }
                /* 从播放队列中移除单项 */
                function removeItem(which) {
                    var asl=[];
                    var l=sortlist.length;
                    for(var i=0;i<l;i++) {
                        if(sortlist[i].absfpath!==which.absfpath) {
                            asl.push(sortlist[i]);
                        }
                    }
                    sortlist=asl;
                    syncPlayingIndex();
                    syncPlayState();
                }
                /* 清空播放队列, 保留当前正在播放的项 */
                function clearList() {
                    var keep=[];
                    var l=sortlist.length;
                    for(var i=0;i<l;i++) {
                        if(sortlist[i].absfpath===playingWhich) {
                            keep.push(sortlist[i]);
                        }
                    }
                    sortlist=keep;
                    syncPlayingIndex();
                    syncPlayState();
                }
                /* 把本模块的播放状态推到枢纽, 供其它模块读取 */
                function syncPlayState() {
                    GlobalFileStorage.setPlayState(sortlist,playingWhich,playingIndex,playMode);
                }
                /* 从枢纽取回播放状态: 值不同才覆盖, 避免与推送动作形成回环 */
                function updateFromPlayState() {
                    var st=GlobalFileStorage.playState;
                    if(st.sortlist!==sortlist) {
                        sortlist=st.sortlist;
                    }
                    if(st.playingWhich!==playingWhich) {
                        playingWhich=st.playingWhich;
                    }
                    if(st.playingIndex!==playingIndex) {
                        playingIndex=st.playingIndex;
                    }
                    if(st.playMode!==playMode) {
                        playMode=st.playMode;
                    }
                }
            }
            /* 枢纽上的播放状态被其它模块改写时取回 */
            Connections {
                target: GlobalFileStorage;
                function onPlayStateChanged() {
                    player.updateFromPlayState();
                }
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
                        transEnabled: false;
                        icon.source: (hovered? "qrc:/assets/iconfont/playerbar/lyricsopen.svg":"");
                        icon.color: Define.mainAreaColor;
                        icon.width: parent.width-5;
                        icon.height: parent.width-5;
                        onClicked: {
                            lyricsSubTab.tshow();
                            console.log("clicked lyricsOpenerBtn");
                        }
                        background: Rectangle {
                            id: lyricsOpenerBg;
                            anchors.fill: parent;
                            color: (parent.hovered? Qt.rgba(0,0,0,0.4):Define.nocolor);
                            radius: parent.parent.radius;
                            layer.enabled: true;
                            layer.effect: MultiEffect {
                                maskEnabled: true;
                                maskSource: lyricsOpenerMasker;
                            }
                            Item {
                                id: lyricsOpenerMasker;
                                anchors.fill: parent;
                                visible: false;
                                layer.enabled: true;
                                Rectangle {
                                    anchors.fill: parent;
                                    radius: lyricsOpenerBg.radius;
                                    border.color: Define.subGrey;
                                    border.width: 1;
                                }
                            }
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
                            transEnabled: false;
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
                        property int sortID: player.playMode;
                        /* 0 randomsort
                           1 listsort
                           2 cycleone
                           3 cyclelist
                        */
                        property bool subTabVisible: false;
                        onClicked: {
                            sub_tshow();
                        }
                        function sub_show() {
                            subTabVisible=true;
                        }
                        function sub_hide() {
                            subTabVisible=false;
                        }
                        function sub_tshow() {
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
                                    delegate: CustomButtonA {
                                        anchors.horizontalCenter: parent.horizontalCenter;
                                        width: sortSubTab.width-8;
                                        height: 30;
                                        onClicked: {
                                            playerSort.subTabVisible=false;
                                            player.setPlayMode(num);
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
                            player.playPrev();
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
                        transEnabled: false;
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
                            player.playNext(false);
                        }
                    }
                    PlayerBarButton {
                        id: soundCtrl;
                        icon.source: (volume==0? "qrc:/assets/iconfont/playerbar/soundless.svg":"qrc:/assets/iconfont/playerbar/sound.svg");
                        property int volume: soundSlider.value;
                        property bool sliderVisible: false;
                        onClicked: {
                            sub_tshow();
                        }
                        function sub_show() {
                            sliderVisible=true;
                        }
                        function sub_hide() {
                            sliderVisible=false;
                        }
                        function sub_tshow() {
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
                    property bool showed: false;
                    icon.color: (((hovered&&hoverColorEnabled)||showed)? Define.btnHoverColor:Define.btnIconColor);
                    icon.source: "qrc:/assets/iconfont/playerbar/lyricsflow.svg";
                    onClicked: {
                        showed=!showed;
                    }
                }
                PlayerBarButton {
                    id: playingListBtn;
                    icon.source: "qrc:/assets/iconfont/playerbar/playerlist.svg";
                    property bool subVisible: false;
                    onClicked: {
                        sub_tshow();
                    }
                    function sub_show() {
                        subVisible=true;
                    }
                    function sub_hide() {
                        subVisible=false;
                    }
                    function sub_tshow() {
                        subVisible=!subVisible;
                    }
                }
            }
        }
        /* 播放列表面板: 由播放栏的播放列表按钮呼出 */
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
            visible: playingListBtn.subVisible;
            MouseArea {
                anchors.fill: parent;
            }
            Column {
                id: playingListHead;
                anchors {left:parent.left; right:parent.right; top:parent.top;}
                padding: 20;
                bottomPadding: 10;
                spacing: 10;
                Rectangle {
                    width: parent.width-parent.padding*2;
                    height: 30;
                    color: Define.nocolor;
                    Text {
                        id: playingListTitle;
                        anchors.verticalCenter: parent.verticalCenter;
                        text: "播放列表";
                        font.pixelSize: 18;
                        font.weight: 500;
                    }
                    Text {
                        anchors {verticalCenter:parent.verticalCenter; left:playingListTitle.right; leftMargin:8;}
                        text: `共 ${player.sortlist.length} 首`;
                        font.pixelSize: 13;
                        font.weight: 400;
                        color: Define.btnIconColor;
                    }
                    CustomButtonA {
                        anchors {verticalCenter:parent.verticalCenter; right:parent.right;}
                        transEnabled: false;
                        width: 80;
                        height: 25;
                        background: Rectangle {
                            anchors.fill: parent;
                            radius: 5;
                            color: (parent.hovered? Define.mainAreaColor:"white");
                            border.color: Define.subGrey;
                            border.width: 1;
                            Text {
                                anchors.centerIn: parent;
                                text: "清空列表";
                            }
                        }
                        onClicked: {
                            player.clearList();
                        }
                    }
                }
                Rectangle {
                    width: parent.width-parent.padding*2;
                    height: 2;
                    radius: 1;
                    color: Define.subGrey;
                }
            }
            Rectangle {
                id: playingListViewArea;
                anchors {left:parent.left; right:parent.right; top:playingListHead.bottom; bottom:parent.bottom;}
                color: Define.nocolor;
                ListView {
                    id: playingListView;
                    anchors.fill: parent;
                    anchors.topMargin: 5;
                    spacing: 1;
                    clip: true;
                    DragHandler {
                        acceptedDevices: PointerDevice.Mouse;
                        target: null;
                    }
                    boundsBehavior: Flickable.StopAtBounds;
                    property string selectedWhich: "";
                    model: player.sortlist;
                    delegate: Item {
                        width: ListView.view.width;
                        height: 60;
                        Rectangle {
                            id: playingBox;
                            anchors.fill: parent;
                            anchors.leftMargin: 20;
                            anchors.rightMargin: 20;
                            radius: 10;
                            property bool selectedRow: (playingListView.selectedWhich===modelData["absfpath"]);
                            property bool playingRow: (player.playingWhich===modelData["absfpath"]);
                            property bool hoveredRow: (playingBoxClick.containsMouse||playingAvatarBtn.hovered);
                            color: ((selectedRow||playingRow)? Define.choseDarkColor:(hoveredRow? Define.hoverDarkColor:(index%2===1? Define.canvasColor:Define.mainAreaColor)));
                            MouseArea {
                                id: playingBoxClick;
                                anchors.fill: parent;
                                hoverEnabled: true;
                                onClicked: {
                                    playingListView.selectedWhich=modelData["absfpath"];
                                    console.log("单击: ",playingListView.selectedWhich);
                                }
                                onDoubleClicked: {
                                    console.log("双击: ",modelData["absfpath"]);
                                    if(player.playingWhich===modelData["absfpath"]) {
                                        return;
                                    }
                                    player.playItem(modelData);
                                }
                            }
                            Row {
                                anchors.fill: parent;
                                leftPadding: 10;
                                rightPadding: 10;
                                spacing: 10;
                                CustomButtonA {
                                    id: playingAvatarBtn;
                                    anchors.verticalCenter: parent.verticalCenter;
                                    height: 40;
                                    width: height;
                                    transEnabled: false;
                                    hoverHandlerEnabled: false;
                                    icon.source: (playingBoxClick.containsMouse||hovered? "qrc:/assets/iconfont/playerbar/play.svg":"");
                                    icon.color: (hovered? Define.btnHoverColor:Define.mainAreaColor);
                                    icon.width: 17;
                                    icon.height: 17;
                                    onClicked: {
                                        if(player.playingWhich===modelData["absfpath"]) {
                                            return;
                                        }
                                        player.playItem(modelData);
                                    }
                                    background: Item {
                                        anchors.fill: parent;
                                        Image {
                                            id: playingAvatarImage;
                                            anchors.fill: parent;
                                            source: (modelData["absipath"]&&modelData["absipath"]!==""? modelData["absipath"]:"qrc:/favicon.jpg");
                                            fillMode: Image.PreserveAspectCrop;
                                            layer.enabled: true;
                                            layer.effect: MultiEffect {
                                                maskEnabled: true;
                                                maskSource: playingAvatarMasker;
                                            }
                                            Item {
                                                id: playingAvatarMasker;
                                                anchors.fill: parent;
                                                visible: false;
                                                layer.enabled: true;
                                                Rectangle {
                                                    anchors.fill: parent;
                                                    radius: 10;
                                                    border.color: Define.subGrey;
                                                    border.width: 1;
                                                }
                                            }
                                        }
                                        Rectangle {
                                            anchors.fill: parent;
                                            radius: 10;
                                            color: (playingAvatarBtn.hovered||playingBoxClick.containsMouse? Qt.rgba(0,0,0,0.3):Define.nocolor);
                                        }
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter;
                                    spacing: 5;
                                    width: 280;
                                    Text {
                                        width: parent.width;
                                        text: modelData["songname"];
                                        font.pixelSize: 14;
                                        font.weight: 400;
                                        elide: Text.ElideRight;
                                        wrapMode: Text.NoWrap;
                                        HoverHandler {
                                            id: playingSongnameHh;
                                        }
                                        ToolTip.visible: playingSongnameHh.hovered&&truncated;
                                        ToolTip.text: text;
                                        ToolTip.delay: 500;
                                    }
                                    Text {
                                        width: parent.width;
                                        text: modelData["singer"];
                                        font.pixelSize: 13;
                                        font.weight: 400;
                                        elide: Text.ElideRight;
                                        wrapMode: Text.NoWrap;
                                        HoverHandler {
                                            id: playingSingerHh;
                                        }
                                        ToolTip.visible: playingSingerHh.hovered&&truncated;
                                        ToolTip.text: text;
                                        ToolTip.delay: 500;
                                    }
                                }
                                CustomButtonA {
                                    /* 正在播放的这一项不允许从列表中删除 */
                                    visible: (player.playingWhich!==modelData["absfpath"]);
                                    anchors.verticalCenter: parent.verticalCenter;
                                    width: 12;
                                    height: 12;
                                    icon.source: "qrc:/assets/iconfont/function/close.svg";
                                    icon.color: Define.btnIconColor;
                                    transEnabled: false;
                                    onClicked: {
                                        player.removeItem(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
                CustomSliderC {
                    id: playingListViewScrollBar;
                    anchors {top:parent.top; bottom:parent.bottom; right:parent.right;}
                    visible: (playingListView.contentHeight > playingListView.height);
                    handleRatio: Math.max(0.1,playingListView.height/playingListView.contentHeight);
                    hoverHandlerEnabled: false;
                    value: from*(playingListView.contentY/Math.max(1,playingListView.contentHeight-playingListView.height));
                    onMoved: {
                        playingListView.contentY=(value/from)*Math.max(0,playingListView.contentHeight-playingListView.height);
                        value=Qt.binding(function() {
                            return from*(playingListView.contentY/Math.max(1,playingListView.contentHeight-playingListView.height));
                        });
                    }
                }
            }
        }
    }
    LyricsSubTab {
        id: lyricsSubTab;
        anchors.fill: parent;
        visible: false;
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
    function subsHide(scenePos) {
        if(!Assist.hitItem(playerSort, scenePos) && !Assist.hitItem(sortSubTab, scenePos)) {
            playerSort.sub_hide();
        }
        if(!Assist.hitItem(soundCtrl, scenePos) && !Assist.hitItem(soundSliderArea, scenePos)) {
            soundCtrl.sub_hide();
        }
        if(!Assist.hitItem(playingListBtn, scenePos) && !Assist.hitItem(playingListArea, scenePos)) {
            playingListBtn.sub_hide();
        }
        if(!Assist.hitItem(moreFunBtn, scenePos) && !Assist.hitItem(moreFunSubTab, scenePos)) {
            moreFunBtn.subTabVisible=false;
        }
        mainArea.curr.subsHide(scenePos);
    }
    Connections {
        target: AppClickHelper;
        function onMousePressed(scenePos) {
            window.subsHide(scenePos);
        }
    }
    Component.onCompleted: {
        console.log("UI加载成功,开始读取程序储存");
        GlobalFileStorage.load();
        window.visible=true;
    }
}
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

    /* 内存枢纽: 只存内存的临时状态, 不落盘; 由主界面持有并注入给各页。
     * 声明在页面之前, 保证页面构建时它已存在 */
    QtObject {
        id: memStorage;
        /* 音频元数据缓存: 标准化路径 -> {duration:秒, title:曲名, artist:歌手} */
        property var metaCache: ({});
        /* 加载进度: 供各模块共用的加载反馈, 同一时刻只服务一个使用者 */
        property var loadingState:
        ({
            using: false,
            value: 0,
            finishedTip: "",
            usedByWho: ""
        });
        /* 写入音频元数据 */
        function setMeta(absfpath,meta) {
            metaCache[absfpath]=meta;
        }
        /* 读取音频元数据: 未探测返回 null */
        function metaOf(absfpath) {
            var m=metaCache[absfpath];
            return (m===undefined? null:m);
        }
        /* 判断路径是否已探测过元数据 */
        function hasMeta(absfpath) {
            return (metaCache[absfpath]!==undefined);
        }
        /* 开始加载: 已在加载中时不打断当前使用者, 返回是否成功占用 */
        function startLoading(finishedTip,usedByWho) {
            if(loadingState.using) {
                return false;
            }
            loadingState=({"using":true,"value":0,"finishedTip":finishedTip,"usedByWho":usedByWho});
            return true;
        }
        /* 更新加载进度: 只接受当前使用者的更新, 返回是否被采纳 */
        function updateLoading(value,usedByWho) {
            if(loadingState.using===false || loadingState.usedByWho!==usedByWho) {
                return false;
            }
            loadingState=({"using":true,
                           "value":value,
                           "finishedTip":loadingState.finishedTip,
                           "usedByWho":usedByWho});
            return true;
        }
        /* 结束加载: 传使用者标识时只有匹配才结束 */
        function stopLoading(usedByWho) {
            if(loadingState.using===false) {
                return false;
            }
            if(usedByWho!==undefined && usedByWho!==loadingState.usedByWho) {
                return false;
            }
            loadingState=({"using":false,"value":0,"finishedTip":"","usedByWho":""});
            return true;
        }
    }

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
            property int bigWidth: 220;
            property int smallWidth: 75;
            /* 展开状态取自存储单例的界面状态, 改动只经存储接口写回, 因此重启后保持上次的状态 */
            property bool spreaded: GlobalFileStorage.uiState.leftSidebarSpreaded;
            width: (spreaded? bigWidth: smallWidth);
            color: Define.leftSidebarColor;
            function spread(b=true) {
                if(b===spreaded) {
                    return;
                }
                GlobalFileStorage.setLeftSidebarSpreaded(b);
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
            /* 按当前页反查路由键: 路由表由左侧栏持有, 这里只做反查, 用于把导航位置落盘 */
            function routeKeyOf(which) {
                var t=leftSidebar.svg2obj;
                for(var k in t) {
                    if(t[k]===which) {
                        return k;
                    }
                }
                return "";
            }
            function _show(which) {
                if(curr===which) {
                    return;
                }
                curr.visible=false;
                curr=which;
                curr.visible=true;
                /* 每次真正换页都把当前页写进界面状态, 供下次启动停在同一页 */
                GlobalFileStorage.setMainAreaPage(routeKeyOf(which));
            }
            /* 按存储里的界面状态恢复上次停留的页面: 只换页, 不进历史栈 */
            function applyStoredPage() {
                var obj=leftSidebar.svg2obj[GlobalFileStorage.uiState.mainAreaPage];
                if(obj===undefined || obj===null) {
                    return false;
                }
                _show(obj);
                return true;
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
                theMemStorage: memStorage;
                anchors.fill: parent;
            }
            MainAreaRecentPage {
                id: mainArea_RecentPage;
                thePlayer: player;
                theMemStorage: memStorage;
                anchors.fill: parent;
            }
            MainAreaLocalPage {
                id: mainArea_LocalPage;
                thePlayer: player;
                theProber: fakePlayer;
                theMemStorage: memStorage;
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
            /* 把进度条手柄与已播放填充同步到当前播放位置; 按住拖动时不打断用户 */
            function syncStampDisplay() {
                if(stampSlider.pressed===false) {
                    stampSlider.value=Math.floor(player.position/1000);
                }
            }
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
                source: "";
                onErrorOccurred: (error, errorString)=>{
                    console.error("音频播放错误:",error,errorString);
                }
                onMediaStatusChanged: {
                    if(mediaStatus===MediaPlayer.LoadedMedia && pendingRestore===true) {
                        /* 断点恢复: 音频加载完成后回到上次的播放进度, 但不自动播放 */
                        pendingRestore=false;
                        position=(GlobalFileStorage.playState.playingPosition===undefined? 0:GlobalFileStorage.playState.playingPosition);
                        console.log("断点恢复: ",source," 进度 ",position);
                    }
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
                /* 断点恢复中: 待音频加载完成后把播放进度恢复到上次的位置 */
                property bool pendingRestore: false;
                /* 播放栏显示的曲名与歌手: 由 syncPlayingInfo 从当前播放项刷新, 空字符串表示未在播放 */
                property string playingTitle: "";
                property string playingSinger: "";
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
                    /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
                    GlobalFileStorage.setPlayPosition(0);
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
                    /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
                    GlobalFileStorage.setPlayPosition(0);
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
                    /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
                    GlobalFileStorage.setPlayPosition(0);
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
                    /* 换歌即把播放进度归零, 避免断点恢复落到上一首的位置 */
                    GlobalFileStorage.setPlayPosition(0);
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
                    syncPlayingInfo();
                }
                /* 刷新播放栏显示的曲名与歌手: 取当前播放项, 找不到时清空 */
                function syncPlayingInfo() {
                    var idx=indexOfPlaying();
                    if(idx<0) {
                        playingTitle="";
                        playingSinger="";
                        return false;
                    }
                    var one=sortlist[idx];
                    playingTitle=(one["songname"]===undefined? "":one["songname"]);
                    playingSinger=(one["singer"]===undefined? "":one["singer"]);
                    return true;
                }
                /* 把播放进度推到枢纽: 落盘与断点恢复都从枢纽取 */
                function syncPlayPosition(ms) {
                    GlobalFileStorage.setPlayPosition(ms);
                }
                /* 断点恢复: 校验队列与当前播放项后加载音频, 不自动播放 */
                function restoreFromState() {
                    var st=GlobalFileStorage.playState;
                    sortlist=st.sortlist;
                    playingWhich=st.playingWhich;
                    playingIndex=st.playingIndex;
                    playMode=st.playMode;
                    if(playingWhich==="" || AppFileHelper.existsFile(playingWhich)===false) {
                        /* 上次的音频已不存在: 清掉当前播放项, 队列保留 */
                        playingWhich="";
                        playingIndex=-1;
                        syncPlayState();
                        return false;
                    }
                    pendingRestore=true;
                    syncPlayingInfo();
                    source=playingWhich;
                    return true;
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
                    syncPlayingInfo();
                }
            }
            /* 播放进度节流上报: 播放中每 5 秒把当前位置写入枢纽, 供落盘与断点恢复 */
            Timer {
                id: positionReport;
                interval: 5000;
                repeat: true;
                running: player.playing;
                onTriggered: {
                    player.syncPlayPosition(Math.floor(player.position));
                }
            }
            /* 枢纽上的播放状态被其它模块改写时取回 */
            Connections {
                target: GlobalFileStorage;
                function onPlayStateChanged() {
                    player.updateFromPlayState();
                }
            }
            /* 播放位置与时长变化时同步进度条: 手柄与已播放填充都读滑块的值 */
            Connections {
                target: player;
                function onPositionChanged() {
                    playerBar.syncStampDisplay();
                }
                function onDurationChanged() {
                    playerBar.syncStampDisplay();
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
                        /* 曲名与歌手: 宽度上限由设计常量给出, 未超出时宽度贴合文本(因此右侧的 VIP 标识紧邻文字),
                         * 超出上限时宽度固定为上限并循环滚动轮播 */
                        Item {
                            id: playingTitleViewport;
                            anchors.verticalCenter: parent.verticalCenter;
                            width: Math.min(playingTitleText.implicitWidth,Define.playerTitleMaxWidth);
                            height: playingTitleText.height;
                            clip: true;
                            Text {
                                id: playingTitleText;
                                text: `${song} - ${singer}`;
                                font.pixelSize: 14;
                                wrapMode: Text.NoWrap;
                                /* 曲名与歌手取自播放模块, 未在播放时用占位文本 */
                                property string song: (player.playingTitle===""? "曲名":player.playingTitle);
                                property string singer: (player.playingTitle===""? "歌手":player.playingSinger);
                                /* 换歌或换文本时回到开头, 避免停在上一次的滚动位置 */
                                onTextChanged: {
                                    x=0;
                                }
                                /* 轮播: 先停一下, 再滚到文本末尾, 再停一下, 然后回到开头重新开始 */
                                SequentialAnimation {
                                    running: (playingTitleText.implicitWidth>Define.playerTitleMaxWidth);
                                    loops: Animation.Infinite;
                                    PauseAnimation {
                                        duration: 1200;
                                    }
                                    NumberAnimation {
                                        target: playingTitleText;
                                        property: "x";
                                        from: 0;
                                        to: (Define.playerTitleMaxWidth-playingTitleText.implicitWidth);
                                        duration: Math.max(1200,(playingTitleText.implicitWidth-Define.playerTitleMaxWidth)*30);
                                    }
                                    PauseAnimation {
                                        duration: 800;
                                    }
                                }
                            }
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
                            /* 喜欢状态取自存储里当前播放项的记录, 未在播放时按钮不可用 */
                            enabled: (player.playingWhich!=="");
                            property bool liked: (enabled && GlobalFileStorage.isLiked(player.playingWhich));
                            icon.source: (liked? "qrc:/assets/iconfont/function/liked.svg":"qrc:/assets/iconfont/function/like.svg");
                            icon.color: (enabled===false? Define.forbdDarkColor:(liked? (hovered? Define.btnHoverRed:Define.btnIconRed):(hovered? Define.btnIconRed:Define.btnIconColor)));
                            onClicked: {
                                GlobalFileStorage.setLiked(player.playingWhich,!liked);
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
                        /* 播放顺序: 0 随机, 1 顺序, 2 单曲, 3 列表; 图标随播放模块的当前模式变化 */
                        property int sortID: player.playMode;
                        function modeSvgName(mode) {
                            var names=["randomsort","listsort","cycleone","cyclelist"];
                            return (mode>=0 && mode<names.length? names[mode]:"listsort");
                        }
                        icon.source: `qrc:/assets/iconfont/playerbar/${modeSvgName(player.playMode)}.svg`;
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
                        /* 静音前的音量, 供取消静音时恢复 */
                        property int lastVolume: 100;
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
                                    /* 初值取自存储枢纽里的音量, 拖动结束后写回存储 */
                                    value: GlobalFileStorage.playState.volume;
                                    onPressedChanged: {
                                        if(!pressed) {
                                            GlobalFileStorage.setVolume(value);
                                            console.log("音量: ",value);
                                        }
                                    }
                                }
                                PlayerBarButton {
                                    id: muteBtn;
                                    anchors.horizontalCenter: parent.horizontalCenter;
                                    icon.source: (soundCtrl.volume==0? "qrc:/assets/iconfont/playerbar/soundless.sub.svg":"qrc:/assets/iconfont/playerbar/sound.sub.svg");
                                    onClicked: {
                                        if(soundCtrl.volume==0) {
                                            soundSlider.value=soundCtrl.lastVolume;
                                        } else {
                                            soundCtrl.lastVolume=soundCtrl.volume;
                                            soundSlider.value=0;
                                        }
                                        GlobalFileStorage.setVolume(soundSlider.value);
                                        console.log("音量: ",soundSlider.value);
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
                        maxStamp: Math.max(0,Math.floor(player.duration/1000));
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
            /* 这一层既挡住面板下方主内容区的点击, 也吃掉列表没有消费的滚轮事件,
             * 避免列表滚到边界后继续滚动主内容区的列表 */
            MouseArea {
                anchors.fill: parent;
                onWheel: (wheel)=> {
                    wheel.accepted=true;
                }
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
                    /* 单行高度, 与委托保持一致 */
                    property int rowHeight: 60;
                    model: player.sortlist;
                    delegate: Item {
                        width: ListView.view.width;
                        height: playingListView.rowHeight;
                        Rectangle {
                            id: playingBox;
                            anchors.fill: parent;
                            anchors.leftMargin: 20;
                            anchors.rightMargin: 20;
                            radius: 10;
                            property bool selectedRow: (playingListView.selectedWhich===modelData["absfpath"]);
                            property bool playingRow: (player.playingWhich===modelData["absfpath"]);
                            /* 悬停高亮: 除整行区域外还要或上内部各组件自己的悬停态,
                             * 因为子组件会接收悬停事件, 此时整行区域的 containsMouse 会变成 false */
                            property bool hoveredRow: (playingBoxClick.containsMouse||playingAvatarBtn.hovered||playingRemoveBtn.hovered||playingSongnameHh.hovered||playingSingerHh.hovered);
                            /* 选中的行用深灰背景; 正在播放的行不用背景色区分, 只用下面那行青色文字标识, 两者可以同时成立 */
                            color: (selectedRow? Define.choseDarkColor:(hoveredRow? Define.hoverDarkColor:(index%2===1? Define.canvasColor:Define.mainAreaColor)));
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
                                        color: (playingBox.playingRow? Define.choseCyanColor:"black");
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
                                        color: (playingBox.playingRow? Define.choseCyanColor:"black");
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
                                    id: playingRemoveBtn;
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
                    /* 悬浮按钮: 两个按钮用同一列自下而上排列, 只有一个可见时也落在右下角同一位置 */
                    Column {
                        id: playingJumpBtnColumn;
                        anchors {bottom:parent.bottom; right:parent.right; bottomMargin:15; rightMargin:15;}
                        spacing: 10;
                        CustomButtonA {
                            id: playingJump2PlayingBtn;
                            width: 30;
                            height: 30;
                            icon.source: "qrc:/assets/iconfont/function/jump2playing.svg";
                            icon.color: (hovered? Define.btnHoverColor:Define.subGrey);
                            icon.width: 20;
                            icon.height: 20;
                            transEnabled: false;
                            visible: playingListView.playingOutOfView();
                            background: Rectangle {
                                anchors.fill: parent;
                                color: Qt.rgba(246,246,246,0.8);
                                border.width: 1.25;
                                border.color: (playingJump2PlayingBtn.hovered? Define.btnHoverColor:Define.subGrey);
                            }
                            onClicked: {
                                playingListView.selectedWhich=player.playingWhich;
                                playingListView.positionViewAtIndex(player.playingIndex,ListView.Beginning);
                            }
                        }
                        CustomButtonA {
                            id: playingJump2TopBtn;
                            width: 30;
                            height: 30;
                            icon.source: "qrc:/assets/iconfont/function/jump2top.svg";
                            icon.color: (hovered? Define.btnHoverColor:Define.subGrey);
                            icon.width: 20;
                            icon.height: 20;
                            transEnabled: false;
                            visible: (playingListView.contentY>0);
                            background: Rectangle {
                                anchors.fill: parent;
                                color: Qt.rgba(246,246,246,0.8);
                                border.width: 1.25;
                                border.color: (playingJump2TopBtn.hovered? Define.btnHoverColor:Define.subGrey);
                            }
                            onClicked: {
                                playingListView.contentY=0;
                            }
                        }
                    }
                    /* 当前播放行是否落在视域之外 */
                    function playingOutOfView() {
                        var idx=player.playingIndex;
                        if(idx<0) {
                            return false;
                        }
                        var top=idx*(rowHeight+spacing);
                        var bottom=top+rowHeight;
                        return (bottom<=contentY || top>=contentY+height);
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
    /* 加载进度条: 状态由内存枢纽的加载状态驱动 */
    Rectangle {
        id: loadingRate;
        anchors {bottom:parent.bottom; left:parent.left; right:parent.right;}
        height: 5;
        color: Define.subGrey;
        bottomLeftRadius: Define.windowRadius;
        bottomRightRadius: Define.windowRadius;
        visible: memStorage.loadingState.using;
        /* 本次加载是否已提示过完成, 避免重复弹出 */
        property bool tipShown: false;
        /* 进度填充: 宽度按枢纽里的百分比换算 */
        Rectangle {
            anchors {left:parent.left; top:parent.top; bottom:parent.bottom;}
            width: parent.width*memStorage.loadingState.value/100;
            color: Define.choseCyanColor;
            bottomLeftRadius: parent.bottomLeftRadius;
            bottomRightRadius: parent.bottomRightRadius;
        }
        /* 进度满时弹一次完成提示, 并让枢纽结束本次加载 */
        Connections {
            target: memStorage;
            function onLoadingStateChanged() {
                var st=memStorage.loadingState;
                if(st.using===false) {
                    loadingRate.tipShown=false;
                    return;
                }
                if(st.value>=100 && loadingRate.tipShown===false) {
                    loadingRate.tipShown=true;
                    loadingTip.showTip(st.finishedTip);
                    memStorage.stopLoading(st.usedByWho);
                }
            }
        }
    }
    /* 完成提示浮层: 独立于进度条, 因此进度条收起后仍短暂可见 */
    Rectangle {
        id: loadingTip;
        anchors {bottom:loadingRate.top; bottomMargin:10; horizontalCenter:parent.horizontalCenter;}
        width: loadingTipText.width+24;
        height: 26;
        radius: 5;
        color: Define.mainAreaColor;
        border.color: Define.subGrey;
        border.width: 1;
        visible: false;
        property string tipText: "";
        function showTip(t) {
            tipText=t;
            visible=true;
            loadingTipTimer.restart();
        }
        Text {
            id: loadingTipText;
            anchors.centerIn: parent;
            text: loadingTip.tipText;
            font.pixelSize: 13;
            font.weight: 400;
        }
        Timer {
            id: loadingTipTimer;
            interval: 2000;
            onTriggered: {
                loadingTip.visible=false;
                loadingTip.tipText="";
            }
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
        /* 先确定存储目录, 再读取落盘数据; 子项先于本处理器完成构建, 因此列表需在读盘后重建一次 */
        GlobalFileStorage.verifyStorageDir();
        GlobalFileStorage.load();
        mainArea.applyStoredPage();
        mainArea_LocalPage.refresh();
        player.restoreFromState();
        window.visible=true;
    }
    Component.onDestruction: {
        /* 退出前把当前播放进度与全部数据落盘 */
        player.syncPlayPosition(Math.floor(player.position));
        GlobalFileStorage.save();
    }
}
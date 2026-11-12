import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia

import AppHelper 1.0

import "./"

/* 播放栏: 主界面与歌词页共用同一份实现, 由 cardStyle 区分卡片式与透明浮条.
 * 播放器与内存在主界面, 这里只做呈现与命令转发; 队列与播放状态的权威始终是注入的播放器对象 */
Rectangle {
    id: root;
    /* 注入: 播放器, 探测用播放器与内存枢纽(内存枢纽用于边播边下的策略钩子) */
    property var thePlayer: null;
    property var theProber: null;
    property var theMemStorage: null;
    /* 实例开关: 卡片式(底色与圆角)还是透明浮条; 歌词页那份取 false */
    property bool cardStyle: true;
    /* 注入: 侧栏展开状态, 决定中部按钮的间距 */
    property bool sidebarSpreaded: true;
    /* 实例开关: 是否由本实例承担播放器级的副作用(进度节拍上报, 枢纽回灌, 清单校正);
     * 主界面那份取 true, 歌词页那份取 false, 避免同一件事被做两遍 */
    property bool ownsPlayerSideEffects: false;
    /* 实例开关: 封面上的悬停图标用关闭歌词页的图形(歌词页实例)还是打开歌词页的图形(主界面实例) */
    property bool lyricsCloseIcon: false;
    /* 桌面悬浮歌词当前是否开启: 由宿主注入, 让右侧的歌词卡片按钮保持点亮 */
    property bool lyricsOpened: false;
    /* 左侧封面被点击: 主界面用来进入歌词页, 歌词页用来退出 */
    signal lyricsOpenerClicked();
    /* 右侧歌词卡片被点击: 开关桌面悬浮歌词, 与歌词页是两件事 */
    signal desktopLyricsRequested();
    /* 音量被拖动: 宿主据此更新音频输出, 避免两侧各存一份音量 */
    signal volumeMoved(int value);
    /* 供宿主绑定的播放列表面板开关状态 */
    readonly property bool listVisible: playingListBtn.subVisible;
    /* 本组件内部的三个弹层是否展开: 播放顺序, 更多, 音量; 加上播放列表面板共四处 */
    readonly property bool subPanelsOpen: (playerSort.subTabVisible || moreFunBtn.subTabVisible
                                           || soundCtrl.sliderVisible);
    /* 交互锁: 四处弹层任一处展开, 或进度与音量滑块正在被按住时成立;
     * 宿主据此让整条播放条保持常显, 不进入隐藏计时 */
    readonly property bool interactionLocked: (subPanelsOpen || playingListBtn.subVisible
                                               || stampSlider.pressed || soundSlider.pressed);
    /* 队列策略钩子: 转交给主界面的内存枢纽 */
    function followPlayStrategy(one) {
        if(theMemStorage!==null) {
            theMemStorage.followPlayStrategy(one);
        }
    }
    /* 收起本组件内的子面板 */
    function subsHide(scenePos) {
        if(!Assist.hitItem(playerSort, scenePos) && !Assist.hitItem(sortSubTab, scenePos)) {
            playerSort.sub_hide();
        }
        if(!Assist.hitItem(soundCtrl, scenePos) && !Assist.hitItem(soundSliderArea, scenePos)) {
            soundCtrl.sub_hide();
        }
        if(!Assist.hitItem(moreFunBtn, scenePos) && !Assist.hitItem(moreFunSubTab, scenePos)) {
            moreFunBtn.subTabVisible=false;
        }
    }
    /* 单独收起播放列表面板: 面板由宿主持有, 落点判断留给宿主 */
    function sub_hideList() {
        playingListBtn.sub_hide();
    }
    /* 收起本组件内部的三个弹层: 隐藏整条播放条前调用, 避免隐藏后弹层状态残留,
     * 再次显示时弹层自己冒出来 */
    function sub_hideAll() {
        playerSort.subTabVisible=false;
        moreFunBtn.subTabVisible=false;
        soundCtrl.sliderVisible=false;
    }
    /* 隐藏前的统一收拾: 三个内部弹层与播放列表面板一起收起 */
    function prepareHide() {
        sub_hideAll();
        sub_hideList();
    }
    /* 热区判定: 入参为本组件坐标系下的点, 覆盖播放条自身与它展开的任一弹层,
     * 弹层都挂在播放条上方, 因此必须按实际几何取范围, 不能只看播放条矩形 */
    function hotAreaContains(lx,ly,pad) {
        var p=Number(pad);
        if(isNaN(p)) {
            p=0;
        }
        var x=Number(lx);
        var y=Number(ly);
        if(x>=-p && x<=(width+p) && y>=-p && y<=(height+p)) {
            return true;
        }
        var subs=[sortSubTab,moreFunSubTab,soundSliderArea];
        for(var i=0;i<subs.length;i++) {
            var it=subs[i];
            if(it===null || it===undefined || it.visible!==true) {
                continue;
            }
            var tl=it.mapToItem(root,0,0);
            if(x>=(tl.x-p) && x<=(tl.x+it.width+p) && y>=(tl.y-p) && y<=(tl.y+it.height+p)) {
                return true;
            }
        }
        return false;
    }
    /* 点击是否落在播放列表按钮上: 落在开启按钮时由按钮自己切换,
     * 宿主的区域外点击收起要让位, 否则按下先收起, 抬手又切换回打开 */
    function hitsListOpener(scenePos) {
        return Assist.hitItem(playingListBtn, scenePos);
    }
    height: 80;
    topLeftRadius: Define.mainAreaRaduis;
    topRightRadius: Define.mainAreaRaduis;
    bottomLeftRadius: Define.mainAreaRaduis;
    bottomRightRadius: Define.mainAreaRaduis;
    color: (cardStyle? Define.mainAreaColor:Define.nocolor);
    /* 供宿主读取的播放位置(秒, 保留小数): 歌词页据此定位当前行与当前词, 逐字进度需要秒级以下的精度;
     * 其余播放命令两处都直接走注入的播放器 */
    readonly property real positionSec: (root.thePlayer===null? 0:root.thePlayer.position/1000);
    /* 把进度条手柄与已播放填充同步到当前播放位置; 按住拖动时不打断用户 */
    function syncStampDisplay() {
        if(stampSlider.pressed===false) {
            stampSlider.value=Math.floor(root.thePlayer.position/1000);
        }
    }
    /* 播放进度节流上报: 播放中每 5 秒把当前位置写入枢纽, 供落盘与断点恢复 */
    Timer {
        id: positionReport;
        interval: 5000;
        repeat: true;
        running: (root.ownsPlayerSideEffects===true && root.thePlayer!==null && root.thePlayer.playing);
        onTriggered: {
            root.thePlayer.syncPlayPosition(Math.floor(root.thePlayer.position));
        }
    }
    /* 枢纽上的播放状态被其它模块改写时取回 */
    Connections {
        target: GlobalFileStorage;
        function onPlayStateChanged() {
            if(root.ownsPlayerSideEffects===true && root.thePlayer!==null) {
                root.thePlayer.updateFromPlayState();
            }
        }
    }
    /* 在线清单就绪时校正队列里的在线条目, 使播放栏与面板显示清单值 */
    Connections {
        target: Server;
        function onLoadStateChanged() {
            if(root.ownsPlayerSideEffects===true && root.thePlayer!==null && Server.loadState===2) {
                root.thePlayer.refreshOnlineTitles();
            }
        }
    }
    /* 播放位置与时长变化时同步进度条: 手柄与已播放填充都读滑块的值 */
    Connections {
        target: root.thePlayer;
        function onPositionChanged() {
            root.syncStampDisplay();
        }
        function onDurationChanged() {
            root.syncStampDisplay();
            root.thePlayer.rememberOnlineDuration();
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
            CoverImage {
                id: lyricsOpenerImage;
                cornerRadius: 5;
                outlineWidth: 0;
                anchors.fill: parent;
                /* 封面跟随当前播放项: 优先条目自带的封面路径, 其次按封面名取在线封面缓存,
                 * 都没有时回退应用图标; 本地条目与未播放时都走回退 */
                property var playingEntry: root.thePlayer.playingEntry();
                property string coverName: (playingEntry===null? "":(playingEntry["cover"]===undefined? "":String(playingEntry["cover"])));
                property string coverSource: ((playingEntry!==null && playingEntry["absipath"]
                                              ? String(playingEntry["absipath"])
                                              :(coverName!=="" && Server.coverCache[coverName]!==undefined
                                                ? String(Server.coverCache[coverName]):"qrc:/favicon.jpg")));
                /* 换歌时按需请求封面: 已缓存或本进程已失败时 requestCover 直接返回 */
                onCoverNameChanged: {
                    if(coverName!=="") {
                        Server.requestCover(coverName);
                    }
                }
                source: coverSource;
            }
            CustomButtonA {
                id: lyricsOpenerBtn;
                anchors.fill: parent;
                transEnabled: false;
                icon.source: (hovered? (root.lyricsCloseIcon
                                        ? "qrc:/assets/iconfont/playerbar/lyricsclose.svg"
                                        : "qrc:/assets/iconfont/playerbar/lyricsopen.svg"):"");
                icon.color: Define.mainAreaColor;
                icon.width: parent.width/2;
                icon.height: parent.width/2;
                onClicked: {
                    root.lyricsOpenerClicked();
                    Assist.dlog("播放","clicked lyricsOpenerBtn");
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
                    /* 超出上限时确实看不到全文, 悬停浮出完整文本 */
                    HoverHandler {
                        id: playingTitleHh;
                    }
                    ToolTip.visible: playingTitleHh.hovered&&(playingTitleText.implicitWidth>Define.playerTitleMaxWidth);
                    ToolTip.text: playingTitleText.text;
                    ToolTip.delay: 500;
                    Text {
                        color: Define.textColor;
                        id: playingTitleText;
                        text: `${song} - ${singer}`;
                        font.pixelSize: 14;
                        wrapMode: Text.NoWrap;
                        /* 曲名与歌手取自播放模块, 未在播放时用占位文本 */
                        property string song: (root.thePlayer.playingTitle===""? "曲名":root.thePlayer.playingTitle);
                        property string singer: (root.thePlayer.playingTitle===""? "歌手":root.thePlayer.playingSinger);
                        /* 换歌或换文本时回到开头, 避免停在上一次的滚动位置 */
                        onTextChanged: {
                            x=0;
                        }
                        /* 轮播: 开头停 1s, 滚到文本末尾, 末尾停 1s, 再滚回开头, 如此往复 */
                        SequentialAnimation {
                            running: (playingTitleText.implicitWidth>Define.playerTitleMaxWidth);
                            loops: Animation.Infinite;
                            PauseAnimation {
                                duration: 1000;
                            }
                            NumberAnimation {
                                target: playingTitleText;
                                property: "x";
                                from: 0;
                                to: (Define.playerTitleMaxWidth-playingTitleText.implicitWidth);
                                duration: Math.max(1200,(playingTitleText.implicitWidth-Define.playerTitleMaxWidth)*30);
                            }
                            PauseAnimation {
                                duration: 1000;
                            }
                            NumberAnimation {
                                target: playingTitleText;
                                property: "x";
                                from: (Define.playerTitleMaxWidth-playingTitleText.implicitWidth);
                                to: 0;
                                duration: Math.max(1200,(playingTitleText.implicitWidth-Define.playerTitleMaxWidth)*30);
                            }
                            PauseAnimation {
                                duration: 1000;
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
                    enabled: (root.thePlayer.playingWhich!=="");
                    property bool liked: (enabled && GlobalFileStorage.isLiked(root.thePlayer.playingWhich));
                    icon.source: (liked? "qrc:/assets/iconfont/function/liked.svg":"qrc:/assets/iconfont/function/like.svg");
                    icon.color: (enabled===false? Define.forbdDarkColor:(liked? (hovered? Define.btnHoverRed:Define.btnIconRed):(hovered? Define.btnIconRed:Define.btnIconColor)));
                    onClicked: {
                        GlobalFileStorage.setLiked(root.thePlayer.playingWhich,!liked);
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
    /* 上下两条独立锚定的行为什么不用 Row/Column 承载: Row 无法容纳带锚定的子项,
     * Column 会把两条行按顺序堆叠, 与顶部 20 底部 10 的独立锚定不符, 因此用普通承载层 */
    Item {
        id: controlRows;
        anchors {top:parent.top; bottom:parent.bottom}
        anchors.horizontalCenter: parent.horizontalCenter;
        Row {
            id: controlRowA;
            anchors {top:parent.top;}
            anchors.topMargin: 20;
            anchors.horizontalCenter: parent.horizontalCenter;
            height: 30;
            spacing: ((root.sidebarSpreaded? 1.5:2)*Define.btnSpacing);
            PlayerBarButton {
                id: playerSort;
                /* 播放顺序: 0 随机, 1 顺序, 2 单曲, 3 列表; 图标随播放模块的当前模式变化 */
                property int sortID: root.thePlayer.playMode;
                function modeSvgName(mode) {
                    var names=["randomsort","listsort","cycleone","cyclelist"];
                    return (mode>=0 && mode<names.length? names[mode]:"listsort");
                }
                icon.source: `qrc:/assets/iconfont/playerbar/${modeSvgName(root.thePlayer.playMode)}.svg`;
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
                                    root.thePlayer.setPlayMode(num);
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
                                            color: Define.textColor;
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
                    root.thePlayer.playPrev();
                }
            }
            PlayerBarButton {
                id: play_pause;
                icon.source: svgBase+(playing? "pause.svg":"play.svg");
                hoverEnabled: false;
                property string svgBase: "qrc:/assets/iconfont/playerbar/";
                property bool playing: root.thePlayer.playing;
                onClicked: {
                    if(playing) {
                        root.thePlayer.pause();
                    } else {
                        root.thePlayer.play();
                    }
                    stampSlider.value=Math.floor(root.thePlayer.position/1000);
                    Assist.dlog("播放","click play_pause, playing=",playing);
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
                    root.thePlayer.playNext(false);
                }
            }

            PlayerBarButton {
                id: soundCtrl;
                icon.source: (volume==0? "qrc:/assets/iconfont/playerbar/soundless.svg":"qrc:/assets/iconfont/playerbar/sound.svg");
                property int volume: soundSlider.value;
                /* 静音前的音量, 供取消静音时恢复: 读的是存储里的同一份, 主界面与歌词页
                 * 两份实例因此共用同一个恢复值; 存储接口缺失或字段未落盘时回退 100, 不报错 */
                function storedLastVolume() {
                    var v=undefined;
                    if(typeof GlobalFileStorage.lastVolume==="function") {
                        v=GlobalFileStorage.lastVolume();
                    } else if(GlobalFileStorage.playState!==undefined
                              && GlobalFileStorage.playState!==null) {
                        v=GlobalFileStorage.playState.lastVolume;
                    }
                    if(v===undefined || v===null || isNaN(Number(v))) {
                        return 100;
                    }
                    return Math.round(Number(v));
                }
                /* 记下静音前的音量: 只经存储接口写, 由它负责夹取与落盘;
                 * setter 尚不可用时静默跳过, 不打断静音流程 */
                function rememberVolume(v) {
                    var n=Math.round(Number(v));
                    if(isNaN(n) || n<0) {
                        n=0;
                    }
                    if(n>100) {
                        n=100;
                    }
                    if(typeof GlobalFileStorage.setLastVolume==="function") {
                        GlobalFileStorage.setLastVolume(n);
                    }
                }
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
                            color: Define.textColor;
                            text: `${soundSlider.value}%`;
                            anchors.horizontalCenter: parent.horizontalCenter;
                        }
                        PlayerBarSliderB {
                            id: soundSlider;
                            anchors.horizontalCenter: parent.horizontalCenter;
                            height: 120;
                            /* 初值取自存储枢纽里的音量, 拖动结束后写回存储 */
                            value: GlobalFileStorage.playState.volume;
                            /* 音量一变就交给宿主更新音频输出, 覆盖拖动与存储同步两种来源;
                             * 松手时写回存储, 静音按钮同样直接写存储 */
                            onValueChanged: {
                                root.volumeMoved(Math.round(value));
                            }
                            onPressedChanged: {
                                if(!pressed) {
                                    GlobalFileStorage.setVolume(value);
                                    Assist.dlog("播放","音量: ",value);
                                }
                            }
                            /* 拖动会覆盖 value 而打断上面的绑定, 这里在存储音量变化时补写一次,
                             * 使拖动或静音之后滑块显示仍与存储音量一致, 两份实例都生效;
                             * 按住拖动时滑块归用户, 播放中每 5 秒的进度落盘会整体替换播放状态,
                             * 补写必须让位, 否则正在拖的滑块被写回旧值 */
                            Connections {
                                target: GlobalFileStorage;
                                function onPlayStateChanged() {
                                    if(soundSlider.pressed===true) {
                                        return;
                                    }
                                    var v=GlobalFileStorage.playState.volume;
                                    if(v===undefined || v===null) {
                                        return;
                                    }
                                    if(Math.round(soundSlider.value)!==Math.round(v)) {
                                        soundSlider.value=v;
                                    }
                                }
                            }
                        }
                        PlayerBarButton {
                            id: muteBtn;
                            anchors.horizontalCenter: parent.horizontalCenter;
                            icon.source: (soundCtrl.volume==0? "qrc:/assets/iconfont/playerbar/soundless.sub.svg":"qrc:/assets/iconfont/playerbar/sound.sub.svg");
                            onClicked: {
                                /* 只经存储单例改音量, 不给滑块直接赋值, 避免打断它的 value 绑定;
                                 * 滑块随存储变化, 两份实例因此始终与存储音量一致 */
                                var target=0;
                                if(soundCtrl.volume==0) {
                                    target=soundCtrl.storedLastVolume();
                                } else {
                                    soundCtrl.rememberVolume(soundCtrl.volume);
                                }
                                GlobalFileStorage.setVolume(target);
                                Assist.dlog("播放","音量: ",target);
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
                color: Define.textColor;
                id: nowStamp;
                text: Assist.int2mmss(stampSlider.showedValue);
                anchors.verticalCenter: parent.verticalCenter;
            }
            PlayerBarSliderA {
                id: stampSlider;
                width: root.width*0.3;
                anchors.verticalCenter: parent.verticalCenter;
                maxStamp: Math.max(0,Math.floor(root.thePlayer.duration/1000));
                property int showedValue: (pressed? value:Math.floor(root.thePlayer.position/1000));
                onPressedChanged: {
                    if(!pressed) {
                        root.thePlayer.position=value*1000;
                        Assist.dlog("播放","音频进度：",value);
                        if(!root.thePlayer.playing) {
                            root.thePlayer.play();
                        }
                    }
                }
            }
            Text {
                color: Define.textColor;
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
            /* 桌面悬浮歌词的开关: 点亮状态跟随悬浮窗的真实可见性 */
            icon.color: (((hovered&&hoverColorEnabled)||root.lyricsOpened)? Define.btnHoverColor:Define.btnIconColor);
            icon.source: "qrc:/assets/iconfont/playerbar/lyricsflow.svg";
            onClicked: {
                root.desktopLyricsRequested();
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
                Assist.dlog("面板","显示播放列表面板");
            }
            function sub_hide() {
                if(subVisible===true) {
                    Assist.dlog("面板","收起播放列表面板");
                }
                subVisible=false;
            }
            function sub_tshow() {
                subVisible=!subVisible;
                Assist.dlog("面板","播放列表面板可见: ",subVisible);
            }
        }
    }
}

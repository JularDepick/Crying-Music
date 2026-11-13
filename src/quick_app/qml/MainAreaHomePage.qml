import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Effects

import "./"

/* 首页推荐: 在线曲库的封面网格, 卡片可直接流式播放, 也可就地下载;
 * 下载队列由主界面的内存枢纽持有, 因此本页与本地和下载页看到的是同一份队列 */
MainAreaFatherPage {
    id: mainArea_HomePage;
    visible: false;
    /* 推荐列表: 由在线曲库清单构造, 只由重建函数整体替换 */
    property var recommendModel: ([]);
    /* 默认排序档: 歌名升序; 排序只有四档, 1 歌名升, 2 歌名降, 3 歌手升, 4 歌手降 */
    readonly property int sortStepDefault: 1;
    property int sortStep: sortStepDefault;
    /* 网格每行放几张卡片: 与 GridView 的分列口径一致(内容宽度除以单元格宽度向下取整),
     * 定位按钮按它把卡片下标换算成行列位置 */
    readonly property int gridColumns: Math.max(1,Math.floor((recommendView.width
                                                             -recommendView.leftMargin
                                                             -recommendView.rightMargin)
                                                            /recommendView.cellWidth));
    /* 标题与功能行 */
    Column {
        id: headColum;
        anchors {left:parent.left; right:parent.right;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        Text {
            color: Define.textColor;
            id: titleText;
            text: "首页推荐";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Row {
            id: functionBox;
            anchors {left:parent.left; right:parent.right;}
            anchors.leftMargin: 40;
            anchors.rightMargin: 40;
            topPadding: 20;
            spacing: 20;
            CustomButtonA {
                id: playAllBtn;
                width: 100;
                height: 30;
                visible: (mainArea_HomePage.recommendModel.length>0);
                onClicked: {
                    mainArea_HomePage.playAllSongs();
                }
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: `qrc:/assets/iconfont/playerbar/play.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            color: Define.textColor;
                            text: "播放全部";
                        }
                    }
                }
            }
            CustomButtonA {
                id: sortBtn;
                width: 80;
                height: 30;
                onClicked: {
                    mainArea_HomePage.cycleSort();
                }
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    /* 默认档不点亮, 换成别的档位才点亮 */
                    color: ((mainArea_HomePage.sortStep!==mainArea_HomePage.sortStepDefault||parent.hovered)? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        Text {
                            color: Define.textColor;
                            text: mainArea_HomePage.sortLabel();
                        }
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 10;
                            height: 10;
                            source: mainArea_HomePage.sortIcon();
                            color: Define.btnIconColor;
                        }
                    }
                }
            }
            CustomButtonA {
                id: refreshBtn;
                width: 80;
                height: 30;
                /* 已有拉取在途时禁用: 避免连点触发并行的拉取 */
                enabled: (Server.fetching!==true);
                opacity: (enabled? 1:0.5);
                onClicked: {
                    mainArea_HomePage.refreshCatalog();
                }
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: `qrc:/assets/iconfont/topnavbar/refresh.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            color: Define.textColor;
                            text: "刷新";
                        }
                    }
                }
            }
        }
    }
    /* 推荐网格: 卡片为封面加曲名歌手, 封面悬停时浮出播放按钮, 右下角为下载按钮 */
    Rectangle {
        id: recommendArea;
        anchors {left:parent.left; right:parent.right; top:headColum.bottom; bottom:parent.bottom;}
        color: Define.nocolor;
        GridView {
            id: recommendView;
            anchors.fill: parent;
            anchors.topMargin: 5;
            clip: true;
            boundsBehavior: Flickable.StopAtBounds;
            cellWidth: (Define.homeCardWidth+Define.homeCardSpacing);
            cellHeight: (Define.homeCardWidth+54);
            leftMargin: 40;
            rightMargin: 40;
            model: mainArea_HomePage.recommendModel;
            delegate: Item {
                width: Define.homeCardWidth;
                height: recommendView.cellHeight;
                Rectangle {
                    id: cardBox;
                    anchors.fill: parent;
                    color: Define.nocolor;
                    /* 已下载与下载中都从枢纽实时取, 因此下载完成后本卡片自动换态 */
                    property var task: (theMemStorage===undefined || theMemStorage===null
                                        ? null:theMemStorage.downloadTaskOf(modelData["onlineId"]));
                    property bool downloaded: GlobalFileStorage.isDownloaded(modelData["onlineId"]);
                    property bool downloading: (task!==null);
                    property bool playingRow: (GlobalFileStorage.playState.playingWhich===modelData["absfpath"]);
                    property bool hoveredCard: (coverClick.containsMouse||coverPlayBtn.hovered||cardDownloadBtn.hovered);
                    Rectangle {
                        id: coverBox;
                        width: Define.homeCardWidth;
                        height: width;
                        radius: 10;
                        clip: true;
                        color: Define.hoverDarkColor;
                        CoverImage {
                            id: coverImage;
                            cornerRadius: 10;
                            outlineWidth: 0;
                            anchors.fill: parent;
                            /* 封面取在线封面缓存, 未命中或拉取失败时回退应用图标;
                             * 封面在卡片可见时按需请求, 避免整页一次性发起下载 */
                            property string coverKey: (modelData["cover"]===undefined? "":modelData["cover"]);
                            onCoverKeyChanged: {
                                Server.requestCover(coverKey);
                            }
                            source: mainArea_HomePage.coverPathOf(modelData);
                        }
                        /* 悬停与正在播放的暗层: 让浮出的播放按钮与跳动的柱子在任意封面上都清晰 */
                        Rectangle {
                            anchors.fill: parent;
                            radius: 10;
                            color: ((cardBox.playingRow||cardBox.hoveredCard)? Qt.rgba(0,0,0,0.28):Define.nocolor);
                        }
                        MouseArea {
                            id: coverClick;
                            anchors.fill: parent;
                            hoverEnabled: true;
                            acceptedButtons: Qt.LeftButton;
                            onClicked: {
                                mainArea_HomePage.playRow(modelData);
                            }
                        }
                        CustomButtonA {
                            id: coverPlayBtn;
                            anchors.centerIn: parent;
                            /* 图标按原尺寸的三倍放大, 按钮同步放大以容下图标 */
                            width: 54;
                            height: 54;
                            /* 正在播放的卡片常显这个按钮, 其余卡片仍然只在悬停时浮出 */
                            visible: (cardBox.hoveredCard===true || cardBox.playingRow===true);
                            /* 正在播放且不悬停时把图标位置让给跳动的柱子, 悬停时仍是播放图标 */
                            icon.source: ((cardBox.playingRow===true && cardBox.hoveredCard!==true)
                                          ? "":"qrc:/assets/iconfont/playerbar/play.svg");
                            icon.color: "white";
                            icon.width: 54;
                            icon.height: 54;
                            hoverColorEnabled: false;
                            transEnabled: false;
                            /* 播放中的状态图标: 与歌曲列表行用的是同一份组件, 播放中才推进 */
                            PlayingBars {
                                anchors.centerIn: parent;
                                width: 54;
                                height: 54;
                                barColor: Define.mainAreaColor;
                                active: (thePlayer!==null && thePlayer.playing===true);
                                visible: (cardBox.playingRow===true && cardBox.hoveredCard!==true);
                            }
                            onClicked: {
                                mainArea_HomePage.playRow(modelData);
                            }
                        }
                        /* 下载中: 封面底部一条细进度条 */
                        Rectangle {
                            visible: cardBox.downloading;
                            anchors {left:parent.left; bottom:parent.bottom;}
                            height: 2;
                            radius: 1;
                            width: (coverBox.width*Math.min(100,Math.max(0,cardBox.task===null? 0:cardBox.task["progress"]))/100);
                            color: Define.choseCyanColor;
                        }
                        /* 下载按钮: 未下载为白底描边, 下载中禁用, 已下载为青色圆角底加白色图标 */
                        CustomButtonA {
                            id: cardDownloadBtn;
                            anchors {right:parent.right; bottom:parent.bottom;}
                            anchors.margins: 8;
                            width: 26;
                            height: 26;
                            enabled: (!cardBox.downloaded && !cardBox.downloading);
                            hoverColorEnabled: false;
                            transEnabled: false;
                            icon.source: "qrc:/assets/iconfont/function/download.svg";
                            icon.width: 14;
                            icon.height: 14;
                            icon.color: (cardBox.downloaded? "white"
                                         :(cardBox.downloading? Define.forbdDarkColor
                                           :(hovered? Define.btnHoverColor:Define.btnIconColor)));
                            onClicked: {
                                mainArea_HomePage.startDownload(modelData);
                            }
                            background: Rectangle {
                                anchors.fill: parent;
                                radius: width/2;
                                color: (cardBox.downloaded? Define.choseCyanColor
                                        :(cardBox.downloading? Define.hoverDarkColor
                                          :(cardDownloadBtn.hovered? Define.mainAreaColor:Qt.rgba(255,255,255,0.9))));
                                border.width: (cardBox.downloaded? 0:1);
                                border.color: Define.subGrey;
                            }
                        }
                    }
                    Text {
                        anchors {left:parent.left; right:parent.right; top:parent.top;}
                        anchors.topMargin: (Define.homeCardWidth+6);
                        text: modelData["songname"];
                        font.pixelSize: 14;
                        font.weight: 400;
                        color: (cardBox.playingRow? Define.choseCyanColor:Define.textColor);
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                    Text {
                        anchors {left:parent.left; right:parent.right; top:parent.top;}
                        anchors.topMargin: (Define.homeCardWidth+26);
                        text: modelData["singer"];
                        font.pixelSize: 12;
                        font.weight: 400;
                        color: (cardBox.playingRow? Define.choseCyanColor:Define.btnIconColor);
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                }
            }
        }
        /* 曲库为空时的提示: 按加载状态分加载中, 失败与空库三种文案;
         * 失败态点一下即手动重拉, 后台仍按退避节拍自动重试 */
        Rectangle {
            id: onlineTipArea;
            anchors.centerIn: parent;
            width: Math.max(onlineTipText.width+40, 200);
            height: 40;
            radius: 8;
            color: Define.mainAreaColor;
            border.color: Define.subGrey;
            border.width: 1;
            visible: (mainArea_HomePage.recommendModel.length<=0);
            MouseArea {
                anchors.fill: parent;
                enabled: (Server.loadState===3);
                onClicked: {
                    mainArea_HomePage.refreshCatalog();
                }
            }
            Text {
                id: onlineTipText;
                anchors.centerIn: parent;
                font.pixelSize: 14;
                color: Define.btnIconColor;
                text: {
                    if(Server.loadState===3) {
                        return "在线曲库加载失败, 点击重试";
                    }
                    if(Server.loadState===2) {
                        return "在线曲库暂无曲目";
                    }
                    return "正在加载在线曲库...";
                }
            }
        }
        /* 两个悬浮按钮用同一列自下而上排列: 只有一个可见时也落在右下角同一位置;
         * 与歌曲列表页同款, 只是这里的视域是网格, 行位置按每行卡片数换算 */
        Column {
            id: jumpBtnColumn;
            anchors {bottom:parent.bottom; right:parent.right; bottomMargin:15; rightMargin:15;}
            spacing: 10;
            CustomButtonA {
                id: jump2PlayingBtn;
                width: 30;
                height: 30;
                icon.source: "qrc:/assets/iconfont/function/jump2playing.svg";
                icon.color: (hovered? Define.btnHoverColor:Define.subGrey);
                icon.width: 20;
                icon.height: 20;
                transEnabled: false;
                visible: mainArea_HomePage.playingOutOfView();
                background: Rectangle {
                    anchors.fill: parent;
                    color: Qt.rgba(246,246,246,0.8);
                    border.width: 1.25;
                    border.color: (jump2PlayingBtn.hovered? Define.btnHoverColor:Define.subGrey);
                }
                onClicked: {
                    mainArea_HomePage.jump2playing();
                }
            }
            CustomButtonA {
                id: jump2TopBtn;
                width: 30;
                height: 30;
                icon.source: "qrc:/assets/iconfont/function/jump2top.svg";
                icon.color: (hovered? Define.btnHoverColor:Define.subGrey);
                icon.width: 20;
                icon.height: 20;
                transEnabled: false;
                visible: (recommendView.contentY>0);
                background: Rectangle {
                    anchors.fill: parent;
                    color: Qt.rgba(246,246,246,0.8);
                    border.width: 1.25;
                    border.color: (jump2TopBtn.hovered? Define.btnHoverColor:Define.subGrey);
                }
                onClicked: {
                    recommendView.contentY=0;
                }
            }
        }
    }
    /* 网格滚动条: 与其它列表共用同一个组件, 轨道与网格视口等高以保证滑块比例正确 */
    CustomSliderC {
        id: recommendScrollBar;
        anchors {top:recommendView.top; bottom:recommendView.bottom; right:parent.right;}
        width: 4;
        visible: (recommendView.contentHeight > recommendView.height);
        handleRatio: Math.max(0.1,recommendView.height/Math.max(1,recommendView.contentHeight));
        hoverHandlerEnabled: false;
        value: from*(recommendView.contentY/Math.max(1,recommendView.contentHeight-recommendView.height));
        onMoved: {
            recommendView.contentY=(value/from)*Math.max(0,recommendView.contentHeight-recommendView.height);
            value=Qt.binding(function() {
                return from*(recommendView.contentY/Math.max(1,recommendView.contentHeight-recommendView.height));
            });
        }
    }
    /* 由在线清单构造推荐条目: 已下载与下载中的状态由卡片实时读取, 条目只带清单字段 */
    function collectOnlineSongs() {
        var v=[];
        if(Server.loadState!==2) {
            return v;
        }
        var rows=Server.manifestRows();
        var l=rows.length;
        for(var i=0;i<l;i++) {
            var e=Server.onlineEntryOfRow(rows[i]);
            if(e!==null) {
                v.push(e);
            }
        }
        return v;
    }
    /* 当前播放项在推荐列表里的下标: 不在列表里时为 -1 */
    function playingRowIndex() {
        var which=GlobalFileStorage.playState.playingWhich;
        if(which===undefined || which===null || which==="") {
            return -1;
        }
        var v=mainArea_HomePage.recommendModel;
        for(var i=0;i<v.length;i++) {
            if(v[i]["absfpath"]===which) {
                return i;
            }
        }
        return -1;
    }
    /* 当前播放项是否落在网格视域之外: 按每行卡片数把下标换算成整行的高度 */
    function playingOutOfView() {
        var idx=mainArea_HomePage.playingRowIndex();
        if(idx<0) {
            return false;
        }
        var top=Math.floor(idx/mainArea_HomePage.gridColumns)*recommendView.cellHeight;
        var bottom=top+recommendView.cellHeight;
        return (bottom<=recommendView.contentY || top>=recommendView.contentY+recommendView.height);
    }
    /* 定位到当前播放的卡片 */
    function jump2playing() {
        var idx=mainArea_HomePage.playingRowIndex();
        if(idx<0) {
            Assist.dlog("在线","定位失败: 当前播放的歌曲不在首页推荐里");
            return false;
        }
        recommendView.positionViewAtIndex(idx,GridView.Beginning);
        Assist.dlog("在线","定位到当前播放的卡片: 下标 ",idx);
        return true;
    }
    /* 重建推荐列表: 按当前排序态重排 */
    function rebuild() {
        var v=sortEntries(collectOnlineSongs());
        mainArea_HomePage.recommendModel=v;
        Assist.dlog("在线","首页推荐重建: 共 ",v.length," 首");
        return true;
    }
    /* 数据有变化才重建: 后台静默刷新时尽量不打扰用户, 重建时保留滚动位置;
     * force 为真时无视内容比对强制重建(封面缓存被清空后需要重建一次让封面按需重取) */
    function rebuildIfChanged(force) {
        var v=sortEntries(collectOnlineSongs());
        if(force!==true && JSON.stringify(v)===JSON.stringify(mainArea_HomePage.recommendModel)) {
            return false;
        }
        var keptY=recommendView.contentY;
        mainArea_HomePage.recommendModel=v;
        recommendView.contentY=keptY;
        Assist.dlog("在线","首页推荐已更新: 共 ",v.length," 首");
        return true;
    }
    /* 按排序态重排副本: 1/2 按歌名升降, 3/4 按歌手升降 */
    function sortEntries(v) {
        var step=mainArea_HomePage.sortStep;
        var key=((step===1 || step===2)? "songname":"singer");
        var asc=(step===1 || step===3);
        var res=v.slice();
        res.sort(function(a,b) {
            if(a[key]===b[key]) {
                return 0;
            }
            return ((a[key]>b[key]? 1:-1)*(asc? 1:-1));
        });
        return res;
    }
    /* 排序按钮的文案: 歌名两档显示 歌名, 歌手两档显示 歌手 */
    function sortLabel() {
        var step=mainArea_HomePage.sortStep;
        if(step===1 || step===2) {
            return "歌名";
        }
        return "歌手";
    }
    /* 排序按钮的指示图标: 升序向上, 降序向下 */
    function sortIcon() {
        var step=mainArea_HomePage.sortStep;
        if(step===1 || step===3) {
            return "qrc:/assets/iconfont/listview/upsort.svg";
        }
        return "qrc:/assets/iconfont/listview/downsort.svg";
    }
    /* 排序切换: 歌名升 -> 歌名降 -> 歌手升 -> 歌手降 -> 歌名升 */
    function cycleSort() {
        mainArea_HomePage.sortStep=(mainArea_HomePage.sortStep%4)+1;
        Assist.dlog("在线","首页推荐排序: ",mainArea_HomePage.sortStep,", ",sortLabel());
        return rebuild();
    }
    /* 手动刷新在线曲库: 已有拉取在途时不再发起, 保证同一时刻只有一个拉取;
     * 拉取在后台进行, 失败不做视觉反馈, 由拉取层按退避节拍自动重试 */
    function refreshCatalog() {
        if(Server.fetching===true) {
            Assist.dlog("在线","手动刷新被忽略: 已有拉取在途");
            return false;
        }
        var ok=Server.refreshNow();
        Assist.dlog("在线","手动刷新在线曲库: ",ok);
        return ok;
    }
    /* 下载某一首: 队列由内存枢纽持有, 完成记录与提示也由它统一处理 */
    function startDownload(one) {
        if(theMemStorage===undefined || theMemStorage===null) {
            Assist.derror("下载","内存枢纽不可用, 无法下载");
            return false;
        }
        return theMemStorage.startDownload(one);
    }
    /* 播放某一行: 播放队列为空时以整个推荐列表构造队列, 否则插到当前播放项之后 */
    function playRow(one) {
        Assist.dlog("在线","播放推荐: ",one["absfpath"]);
        if(GlobalFileStorage.playState.sortlist.length<=0) {
            return thePlayer.playAll(mainArea_HomePage.recommendModel,one);
        }
        return thePlayer.jump2play(one);
    }
    /* 播放全部推荐: 从头开始 */
    function playAllSongs() {
        var v=mainArea_HomePage.recommendModel;
        if(v.length<=0) {
            Assist.dlog("在线","播放失败: 推荐列表为空");
            return false;
        }
        return thePlayer.playAll(v,v[0]);
    }
    /* 关键字搜索: 走统一的搜索匹配算法过滤推荐列表 */
    function search(keyword) {
        return Assist.searchList(keyword,mainArea_HomePage.recommendModel);
    }
    function refresh() {
        if(Server.loadState!==2) {
            Server.refreshNow();
        }
        return rebuild();
    }
    /* 曲库就绪或数据变化: 数据变了才重建, 让后台刷新对用户无感 */
    Connections {
        target: Server;
        function onLoadStateChanged() {
            mainArea_HomePage.rebuildIfChanged();
        }
        function onManifestUpdated() {
            mainArea_HomePage.rebuildIfChanged();
        }
        function onCoverCacheCleared() {
            mainArea_HomePage.rebuildIfChanged(true);
        }
    }
    /* 封面来源: 优先取在线封面缓存, 未命中或尚未缓存时回退应用图标 */
    function coverPathOf(one) {
        var key=(one===undefined || one===null? "":one["cover"]);
        if(typeof key!=="string" || key==="") {
            return "qrc:/favicon.jpg";
        }
        var p=Server.coverCache[key];
        return (typeof p==="string" && p!==""? p:"qrc:/favicon.jpg");
    }
}

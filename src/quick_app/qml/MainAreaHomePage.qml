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
    /* 排序状态: 0 默认顺序, 1 歌名升, 2 歌名降, 3 歌手升, 4 歌手降 */
    property int sortStep: 0;
    /* 标题与功能行 */
    Column {
        id: headColum;
        anchors {left:parent.left; right:parent.right;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        Text {
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
                    color: ((mainArea_HomePage.sortStep!==0||parent.hovered)? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        Text {
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
            DragHandler {
                acceptedDevices: PointerDevice.Mouse;
                target: null;
            }
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
                        Image {
                            id: coverImage;
                            anchors.fill: parent;
                            /* 封面取在线图标缓存, 未命中或拉取失败时回退应用图标;
                             * 图标在卡片可见时按需请求, 避免整页一次性发起下载 */
                            property string iconKey: (modelData["icon"]===undefined? "":modelData["icon"]);
                            onIconKeyChanged: {
                                Server.requestIcon(iconKey);
                            }
                            source: mainArea_HomePage.iconPathOf(modelData);
                            fillMode: Image.PreserveAspectCrop;
                        }
                        /* 悬停暗层: 让浮出的播放按钮在任何封面上都清晰 */
                        Rectangle {
                            anchors.fill: parent;
                            radius: 10;
                            color: (cardBox.hoveredCard? Qt.rgba(0,0,0,0.28):Define.nocolor);
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
                            width: 34;
                            height: 34;
                            visible: cardBox.hoveredCard;
                            icon.source: "qrc:/assets/iconfont/playerbar/play.svg";
                            icon.color: "white";
                            icon.width: 18;
                            icon.height: 18;
                            hoverColorEnabled: false;
                            transEnabled: false;
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
                        color: (cardBox.playingRow? Define.choseCyanColor:"black");
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
        /* 曲库为空时的提示: 拉取失败不做视觉反馈, 由拉取层每分钟自动重试 */
        Rectangle {
            id: onlineTipArea;
            anchors.centerIn: parent;
            width: onlineTipText.width+40;
            height: 40;
            radius: 8;
            color: Define.mainAreaColor;
            border.color: Define.subGrey;
            border.width: 1;
            visible: (mainArea_HomePage.recommendModel.length<=0);
            Text {
                id: onlineTipText;
                anchors.centerIn: parent;
                font.pixelSize: 14;
                color: Define.btnIconColor;
                text: "正在加载在线曲库...";
            }
        }
    }
    /* 网格滚动条: 与其它列表共用同一个组件, 轨道与网格视口等高以保证滑块比例正确 */
    CustomSliderC {
        id: recommendScrollBar;
        anchors {top:recommendView.top; bottom:recommendView.bottom; right:parent.right;}
        width: 4;
        visible: (recommendView.contentHeight > recommendView.height);
        handleRatio: Math.max(0.1,recommendView.height/recommendView.contentHeight);
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
    /* 按排序态重排副本: 0 保持清单顺序, 1/2 按歌名升降, 3/4 按歌手升降 */
    function sortEntries(v) {
        var step=mainArea_HomePage.sortStep;
        if(step===0) {
            return v;
        }
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
    /* 排序按钮的文案 */
    function sortLabel() {
        var step=mainArea_HomePage.sortStep;
        if(step===1 || step===2) {
            return "歌名";
        }
        if(step===3 || step===4) {
            return "歌手";
        }
        return "排序";
    }
    /* 排序按钮的指示图标 */
    function sortIcon() {
        var step=mainArea_HomePage.sortStep;
        if(step===1 || step===3) {
            return "qrc:/assets/iconfont/listview/upsort.svg";
        }
        if(step===2 || step===4) {
            return "qrc:/assets/iconfont/listview/downsort.svg";
        }
        return "qrc:/assets/iconfont/listview/justsort.svg";
    }
    /* 排序切换: 默认 -> 歌名升 -> 歌名降 -> 歌手升 -> 歌手降 -> 默认 */
    function cycleSort() {
        mainArea_HomePage.sortStep=(mainArea_HomePage.sortStep+1)%5;
        Assist.dlog("在线","首页推荐排序: ",mainArea_HomePage.sortStep,", ",sortLabel());
        return rebuild();
    }
    /* 手动刷新在线曲库: 已有拉取在途时不再发起, 保证同一时刻只有一个拉取;
     * 拉取在后台进行, 失败不做视觉反馈, 由拉取层每分钟自动重试 */
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
    /* 关键字搜索: 只过滤推荐列表的曲名与歌手 */
    function search(keyword) {
        var v=mainArea_HomePage.recommendModel;
        var l=v.length;
        var res=[];
        for(var i=0;i<l;i++) {
            if(Assist.keywordMatch(v[i]["songname"],v[i]["singer"],keyword)) {
                res.push(v[i]);
            }
        }
        return res;
    }
    function subsHide(scenePos) {
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
        function onIconCacheCleared() {
            mainArea_HomePage.rebuildIfChanged(true);
        }
    }
    /* 封面来源: 优先取在线图标缓存, 未命中或尚未缓存时回退应用图标 */
    function iconPathOf(one) {
        var key=(one===undefined || one===null? "":one["icon"]);
        if(typeof key!=="string" || key==="") {
            return "qrc:/favicon.jpg";
        }
        var p=Server.iconCache[key];
        return (typeof p==="string" && p!==""? p:"qrc:/favicon.jpg");
    }
}

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
    /* 在线曲库请求在底部加载进度条上的使用者标识 */
    property string onlineLoadingId: "onlineManifest";
    /* 推荐列表: 由在线曲库清单构造, 只由重建函数整体替换 */
    property var recommendModel: ([]);
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
                id: retryBtn;
                width: 80;
                height: 30;
                visible: (Server.loadState===3);
                onClicked: {
                    mainArea_HomePage.retryOnline();
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
                            text: "重新加载";
                        }
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter;
                text: (Server.loadState===2? "在线曲库共 "+mainArea_HomePage.recommendModel.length+" 首"
                       :(Server.loadState===3? "在线曲库加载失败":"正在加载在线曲库"));
                font.pixelSize: 13;
                color: (Server.loadState===3? Define.btnIconRed:Define.btnIconColor);
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
        /* 在线曲库的加载态与失败重试: 只在推荐列表为空时出现 */
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
                color: (Server.loadState===3? Define.btnIconRed:Define.btnIconColor);
                text: (Server.loadState===2? "在线曲库为空"
                       :(Server.loadState===3? "在线曲库加载失败, 点击重试":"正在加载在线曲库..."));
            }
            MouseArea {
                anchors.fill: parent;
                enabled: (Server.loadState===3);
                onClicked: {
                    mainArea_HomePage.retryOnline();
                }
            }
        }
    }
    /* 网格滚动条: 与其它列表共用同一个组件 */
    CustomSliderC {
        id: recommendScrollBar;
        anchors {top:recommendArea.top; bottom:recommendArea.bottom; right:parent.right;}
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
    /* 重建推荐列表 */
    function rebuild() {
        var v=collectOnlineSongs();
        mainArea_HomePage.recommendModel=v;
        Assist.dlog("在线","首页推荐重建: 共 ",v.length," 首");
        return true;
    }
    /* 数据有变化才重建: 后台静默刷新时尽量不打扰用户, 重建时保留滚动位置 */
    function rebuildIfChanged() {
        var v=collectOnlineSongs();
        if(JSON.stringify(v)===JSON.stringify(mainArea_HomePage.recommendModel)) {
            return false;
        }
        var keptY=recommendView.contentY;
        mainArea_HomePage.recommendModel=v;
        recommendView.contentY=keptY;
        Assist.dlog("在线","首页推荐已更新: 共 ",v.length," 首");
        return true;
    }
    /* 请求在线曲库: 未就绪时拉取一次, 进度走底部加载进度条 */
    function requestOnline() {
        if(Server.loadState===1) {
            return false;
        }
        if(Server.loadState===2) {
            return rebuild();
        }
        if(theMemStorage!==undefined && theMemStorage!==null) {
            theMemStorage.startLoading("在线曲库已更新",mainArea_HomePage.onlineLoadingId);
        }
        return Server.ensureLoaded();
    }
    /* 在线曲库加载失败后的重试 */
    function retryOnline() {
        if(Server.loadState===1) {
            return false;
        }
        Assist.dlog("在线","首页重试加载在线曲库");
        Server.retry();
        if(theMemStorage!==undefined && theMemStorage!==null) {
            theMemStorage.startLoading("在线曲库已更新",mainArea_HomePage.onlineLoadingId);
        }
        return true;
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
            requestOnline();
        }
        return rebuild();
    }
    /* 在线清单就绪或失败: 收尾加载进度条并重建推荐列表 */
    Connections {
        target: Server;
        function onLoadStateChanged() {
            if(Server.loadState===2) {
                if(mainArea_HomePage.theMemStorage!==undefined && mainArea_HomePage.theMemStorage!==null) {
                    mainArea_HomePage.theMemStorage.updateLoading(100,mainArea_HomePage.onlineLoadingId);
                }
                mainArea_HomePage.rebuildIfChanged();
            } else if(Server.loadState===3) {
                if(mainArea_HomePage.theMemStorage!==undefined && mainArea_HomePage.theMemStorage!==null) {
                    mainArea_HomePage.theMemStorage.stopLoading(mainArea_HomePage.onlineLoadingId);
                }
                mainArea_HomePage.rebuildIfChanged();
            }
        }
        /* 后台静默刷新成功: 数据变了才重建, 让刷新对用户无感 */
        function onManifestUpdated() {
            mainArea_HomePage.rebuildIfChanged();
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

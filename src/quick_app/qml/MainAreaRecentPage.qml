import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Effects

import AppHelper 1.0

import "./"

MainAreaFatherPage {
    id: mainArea_RecentPage;
    visible: false;
    /* 标题与功能行: 列表滚动时标题吸顶 */
    Column {
        id: headColum;
        z: mainViewArea.z+1;
        y: Math.min(0,mainListView.contentY>=titleText.height? (-titleText.height):(-mainListView.contentY));
        anchors {left:parent.left; right:parent.right;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        Text {
            color: Define.textColor;
            id: titleText;
            text: "最近播放";
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
                id: playList;
                width: 80;
                height: 30;
                onClicked: {
                    mainArea_RecentPage.playAllSongs();
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
                            text: "播放";
                        }
                    }
                }
            }
            CustomButtonA {
                id: batchOp;
                width: 80;
                height: 30;
                onClicked: {
                    mainListView.setBatchMode(!mainListView.batchMode);
                }
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: ((mainListView.batchMode||parent.hovered)? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: Define.batchIconSize;
                            height: Define.batchIconSize;
                            source: `qrc:/assets/iconfont/function/batch.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            color: Define.textColor;
                            text: (mainListView.batchMode? "取消":"批量");
                        }
                    }
                }
            }
            Row {
                id: batchBox;
                visible: mainListView.batchMode;
                spacing: 20;
                CustomButtonA {
                    id: selectAllBtn;
                    width: 80;
                    height: 30;
                    onClicked: {
                        mainListView.toggleAllChecked();
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
                                width: Define.batchIconSize;
                                height: Define.batchIconSize;
                                /* 批量按钮呼起的全选入口用对勾图标; checked_stark 只用于行首复选框 */
                                source: "qrc:/assets/iconfont/function/check_mark.svg";
                                color: Define.btnIconColor;
                            }
                            Text {
                                color: Define.textColor;
                                text: (mainListView.allChecked? "取消全选":"全选");
                            }
                        }
                    }
                }
                /* 移除记录是破坏性操作: 第一次点击只进入确认态, 确认态内再次点击才真正移除 */
                ConfirmButton {
                    id: batchRemoveBtn;
                    width: 100;
                    height: 30;
                    transEnabled: false;
                    label: "移除记录";
                    confirmLabel: "确认移除";
                    icon.source: "qrc:/assets/iconfont/function/delete.svg";
                    onConfirmed: {
                        mainListView.batchRemove();
                    }
                }
            }
        }
    }
    /* 排序表头: 曲名与歌手为四态循环按钮, 大小与时长各自 toggle */
    Row {
        id: sortHead;
        anchors {left:parent.left; right:parent.right; top:headColum.bottom;}
        anchors.leftMargin: 40;
        anchors.rightMargin: 40;
        height: 20;
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*Define.listColumnRatios[0];
            color: Define.nocolor;
            /* 表头文字左对齐: 文字自列左边缘起排, 排序指示图标紧跟其后 */
            Button {
                anchors.fill: parent;
                onClicked: {
                    mainListView.sortByName();
                }
                background: Item {
                    Text {
                        id: nameSortText;
                        anchors {left:parent.left; verticalCenter:parent.verticalCenter; leftMargin:Define.listHeaderPad;}
                        color: Define.textColor;
                        text: mainListView.nameSortLabel();
                    }
                    ColorImage {
                        anchors {verticalCenter:parent.verticalCenter; left:nameSortText.right; leftMargin:2;}
                        width: 10;
                        height: 10;
                        source: mainListView.nameSortIcon();
                        color: Define.btnIconColor;
                    }
                }
            }
        }
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*Define.listColumnRatios[1];
            color: Define.nocolor;
            /* 表头文字左对齐: 文字自列左边缘起排, 排序指示图标紧跟其后 */
            Button {
                anchors.fill: parent;
                onClicked: {
                    mainListView.sortBy("size");
                }
                background: Item {
                    Text {
                        id: sizeSortText;
                        anchors {left:parent.left; verticalCenter:parent.verticalCenter;}
                        color: Define.textColor;
                        text: "大小";
                    }
                    ColorImage {
                        anchors {verticalCenter:parent.verticalCenter; left:sizeSortText.right; leftMargin:2;}
                        width: 10;
                        height: 10;
                        source: mainListView.sortIconOf("size");
                        color: Define.btnIconColor;
                    }
                }
            }
        }
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*Define.listColumnRatios[2];
            color: Define.nocolor;
            /* 表头文字左对齐: 文字自列左边缘起排, 排序指示图标紧跟其后 */
            Button {
                anchors.fill: parent;
                onClicked: {
                    mainListView.sortBy("duration");
                }
                background: Item {
                    Text {
                        id: durationSortText;
                        anchors {left:parent.left; verticalCenter:parent.verticalCenter;}
                        color: Define.textColor;
                        text: "时长";
                    }
                    ColorImage {
                        anchors {verticalCenter:parent.verticalCenter; left:durationSortText.right; leftMargin:2;}
                        width: 10;
                        height: 10;
                        source: mainListView.sortIconOf("duration");
                        color: Define.btnIconColor;
                    }
                }
            }
        }
    }
    /* 列表条目数组: 只由构建函数与排序函数整体替换 */
    property var mainListViewModel: ([]);
    /* 列表区: 委托行, 回到顶部与定位当前播放两个悬浮按钮 */
    Rectangle {
        id: mainViewArea;
        anchors {left:parent.left; right:parent.right; top:sortHead.bottom; bottom:parent.bottom}
        color: Define.nocolor;
        ListView {
            id: mainListView;
            anchors.fill: parent;
            anchors.topMargin: 5;
            spacing: 0;
            clip: true;
            boundsBehavior: Flickable.StopAtBounds;
            property string selectedWhich: "";
            property bool batchMode: false;
            /* 列表是否已全部勾选: 供全选按钮在"全选"与"取消全选"之间自动切换 */
            property bool allChecked: (mainArea_RecentPage.mainListViewModel.length>0
                                       && mainArea_RecentPage.mainListViewModel.every(function(one) { return one["checked"]===true; }));
            property string sortKey: "";
            property bool sortAsc: true;
            /* 曲名与歌手合并按钮的四态下标, -1 表示尚未点过该按钮 */
            property int nameSortStep: -1;
            /* 单行高度, 与委托保持一致 */
            property int rowHeight: 60;
            model: mainArea_RecentPage.mainListViewModel;
            delegate: Item {
                width: ListView.view.width;
                height: mainListView.rowHeight;
                Rectangle {
                    id: box;
                    anchors.fill: parent;
                    anchors.leftMargin: 40;
                    anchors.rightMargin: 40;
                    radius: 10;
                    property bool checkedRow: (modelData["checked"]===true);
                    property bool selectedRow: (mainListView.selectedWhich===modelData["absfpath"]);
                    property bool playingRow: (GlobalFileStorage.playState.playingWhich===modelData["absfpath"]);
                    /* 行内可用内容宽度: 与排序表头的左右边距一致, 三列列宽由它乘列宽比例算出,
                     * 因此左侧栏收起或展开时表头与行内列同步重算 */
                    property real rowContentW: (mainListView.width-anchors.leftMargin-anchors.rightMargin);
                    /* 悬停高亮: 由挂在行容器上的 HoverHandler 判定, 它覆盖整行,
                     * 子组件接收悬停时同样算在行内 */
                    property bool hoveredRow: rowHover.hovered;
                    HoverHandler {
                        id: rowHover;
                    }
                    color: ((checkedRow||selectedRow)? Define.choseDarkColor:(hoveredRow? Define.hoverDarkColor:(index%2===1? Define.canvasColor:Define.mainAreaColor)));
                    MouseArea {
                        id: boxClick;
                        anchors.fill: parent;
                        hoverEnabled: true;
                        onClicked: {
                            if(mainListView.batchMode) {
                                mainListView.toggleChecked(index);
                                return;
                            }
                            mainListView.selectedWhich=modelData["absfpath"];
                            Assist.dlog("列表","单击: ",mainListView.selectedWhich);
                        }
                        onDoubleClicked: {
                            if(mainListView.batchMode) {
                                return;
                            }
                            Assist.dlog("列表","双击: ",modelData["absfpath"]);
                            if(GlobalFileStorage.playState.playingWhich===modelData["absfpath"]) {
                                return;
                            }
                            mainArea_RecentPage.playRow(modelData);
                        }
                    }
                    Row {
                        anchors.fill: parent;
                        topPadding: 8;
                        leftPadding: 10;
                        rightPadding: 10;
                        spacing: 10;
                        CustomButtonA {
                            id: songCheckBtn;
                            visible: mainListView.batchMode;
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 16;
                            height: 16;
                            transEnabled: false;
                            hoverHandlerEnabled: false;
                            icon.source: "qrc:/assets/iconfont/function/checked_stark.svg";
                            icon.width: 8;
                            icon.height: 8;
                            icon.color: Define.mainAreaColor;
                            property bool selected: (modelData["checked"]===true);
                            onClicked: {
                                mainListView.toggleChecked(index);
                            }
                            background: Rectangle {
                                anchors.fill: parent;
                                radius: parent.width/2;
                                border.width: 1.5;
                                border.color: (parent.selected? Define.choseCyanColor:Define.btnIconColor);
                                color: (parent.selected? Define.choseCyanColor:Define.nocolor);
                            }
                        }
                        CustomButtonA {
                            id: songAvatarBtn;
                            anchors.verticalCenter: parent.verticalCenter;
                            height: 40;
                            width: height;
                            transEnabled: false;
                            hoverHandlerEnabled: false;
                            /* 图标: 正在播放的行不悬停时由 PlayingBars 显示跳动的柱子, 悬停时按播放状态
                             * 显示暂停或播放; 其它行只在悬停时显示播放图标 */
                            icon.source: {
                                if(mainListView.batchMode) {
                                    return "";
                                }
                                if(box.hoveredRow!==true) {
                                    return "";
                                }
                                if(box.playingRow===true) {
                                    return ((thePlayer!==null && thePlayer.playing===true)
                                            ? "qrc:/assets/iconfont/playerbar/pause.svg"
                                            : "qrc:/assets/iconfont/playerbar/play.svg");
                                }
                                return "qrc:/assets/iconfont/playerbar/play.svg";
                            }
                            icon.color: (hovered? Define.btnHoverColor:Define.mainAreaColor);
                            icon.width: 17;
                            icon.height: 17;
                            /* 正在播放的行不悬停时, 图标位置换成一圈自己跳动的柱子:
                             * 原来那枚 svg 是 SMIL 动画, QML 只把它光栅化成一张静态图 */
                            PlayingBars {
                                anchors.centerIn: parent;
                                width: 17;
                                height: 17;
                                barColor: Define.mainAreaColor;
                                active: (thePlayer!==null && thePlayer.playing===true);
                                visible: (mainListView.batchMode!==true && box.hoveredRow!==true
                                          && box.playingRow===true);
                            }
                            onClicked: {
                                if(mainListView.batchMode) {
                                    mainListView.toggleChecked(index);
                                    return;
                                }
                                if(box.playingRow===true) {
                                    if(thePlayer!==null && thePlayer.playing===true) {
                                        thePlayer.pause();
                                    } else if(thePlayer!==null) {
                                        thePlayer.play();
                                    }
                                    return;
                                }
                                mainArea_RecentPage.playRow(modelData);
                            }
                            background: Item {
                                anchors.fill: parent;
                                CoverImage {
                                    id: songAvatarImage;
                                    cornerRadius: 10;
                                    anchors.fill: parent;
                                    /* 封面: 本地路径优先, 在线条目取 Server 里的封面缓存, 都没有时回退应用图标;
                                     * 在线封面在行可见时按需请求, 避免整表一次性发起下载 */
                                    property string coverKey: (modelData["cover"]===undefined? "":modelData["cover"]);
                                    onCoverKeyChanged: {
                                        Server.requestCover(coverKey);
                                    }
                                    source: (modelData["absipath"]&&modelData["absipath"]!==""? modelData["absipath"]
                                             :(modelData["cover"]&&modelData["cover"]!==""&&Server.coverCache[modelData["cover"]]!==undefined
                                               ? Server.coverCache[modelData["cover"]]:"qrc:/favicon.jpg"));
                                }
                                Rectangle {
                                    anchors.fill: parent;
                                    radius: 10;
                                    /* 批量操作时临时禁用暗色遮罩, 避免勾选时封面变暗 */
                                    color: ((!mainListView.batchMode&&(box.playingRow||box.hoveredRow))? Qt.rgba(0,0,0,0.3):Define.nocolor);
                                }
                            }
                        }
                        /* 歌名与歌手列: 起点由行内左内边距与封面决定(批量多选态还要算上勾选框);
                         * 宽度固定, 超出时省略号截断, 点赞与加入播放列表紧随其后 */
                        Column {
                            anchors.verticalCenter: parent.verticalCenter;
                            spacing: 5;
                            width: Define.songColWidth;
                            /* 正在播放的行把曲名与歌手改成选中青, 与选中背景并存 */
                            Text {
                                width: parent.width;
                                text: modelData["songname"];
                                font.pixelSize: 14;
                                font.weight: 400;
                                color: (box.playingRow? Define.choseCyanColor:Define.textColor);
                                elide: Text.ElideRight;
                                wrapMode: Text.NoWrap;
                                HoverHandler {
                                    id: songnameHh;
                                }
                                ToolTip.visible: songnameHh.hovered&&truncated;
                                ToolTip.text: text;
                                ToolTip.delay: 500;
                            }
                            Text {
                                width: parent.width;
                                text: modelData["singer"];
                                font.pixelSize: 13;
                                font.weight: 400;
                                color: (box.playingRow? Define.choseCyanColor:Define.textColor);
                                elide: Text.ElideRight;
                                wrapMode: Text.NoWrap;
                                HoverHandler {
                                    id: singerHh;
                                }
                                ToolTip.visible: singerHh.hovered&&truncated;
                                ToolTip.text: text;
                                ToolTip.delay: 500;
                            }
                        }
                        /* 点赞与下一首播放: 单独用一层容器内嵌 Row, 便于给这两个按钮设置独立的间距 */
                        Rectangle {
                            id: songActionBox;
                            anchors.verticalCenter: parent.verticalCenter;
                            color: Define.nocolor;
                            width: songActionRow.width;
                            height: songActionRow.height;
                            Row {
                                id: songActionRow;
                                spacing: 25;
                                CustomButtonA {
                                    id: songLikeBtn;
                                    visible: !mainListView.batchMode;
                                    height: 20;
                                    width: 20;
                                    icon.source: (liked? "qrc:/assets/iconfont/function/liked.svg":"qrc:/assets/iconfont/function/like.svg");
                                    icon.color: ((liked||hovered)? Define.btnIconRed:Define.btnIconColor);
                                    transEnabled: false;
                                    property bool liked: (modelData["liked"]===true);
                                    onClicked: {
                                        var next=!liked;
                                        GlobalFileStorage.setLiked(modelData["absfpath"],next);
                                        var v=mainArea_RecentPage.mainListViewModel.slice();
                                        v[index]["liked"]=next;
                                        mainArea_RecentPage.replaceModelKeepScroll(v);
                                    }
                                }
                                CustomButtonA {
                                    id: songAddIntoBtn;
                                    /* 加入播放列表与下载按钮跟着行悬停出现, 点赞按钮常驻 */
                                    visible: (!mainListView.batchMode && box.hoveredRow);
                                    height: 20;
                                    width: 20;
                                    icon.source: "qrc:/assets/iconfont/function/addinto.svg";
                                    transEnabled: false;
                                    onClicked: {
                                        thePlayer.insertNext(modelData);
                                    }
                                }
                                /* 下载按钮: 只对在线条目出现; 未下载显示下载图标并可点,
                                 * 已在下载队列里则禁用(状态由内存枢纽统一给出),
                                 * 已下载显示对勾状态图标; 本地音乐没有这一项 */
                                CustomButtonA {
                                    id: songDownloadBtn;
                                    property string onlineId: (modelData["onlineId"]===undefined? "":String(modelData["onlineId"]));
                                    property var task: ((onlineId==="" || theMemStorage===undefined || theMemStorage===null)
                                                        ? null:theMemStorage.downloadTaskOf(onlineId));
                                    property bool downloaded: (onlineId!=="" && GlobalFileStorage.isDownloaded(onlineId));
                                    property bool downloading: (task!==null);
                                    /* 已下载的条目常驻显示对勾, 未下载的仍随行悬停出现 */
                                    visible: ((modelData["online"]===true && mainListView.batchMode!==true)
                                              && (box.hoveredRow===true || downloaded===true));
                                    height: 20;
                                    width: 20;
                                    enabled: (!downloaded && !downloading);
                                    transEnabled: false;
                                    icon.source: (downloaded? "qrc:/assets/iconfont/listview/checked_status.svg"
                                                             :"qrc:/assets/iconfont/function/download.svg");
                                    icon.color: (downloaded? Define.choseCyanColor
                                                            :(downloading? Define.forbdDarkColor
                                                              :(hovered? Define.btnHoverColor:Define.btnIconColor)));
                                    onClicked: {
                                        if(downloaded===true || downloading===true) {
                                            return;
                                        }
                                        Assist.dlog("下载","列表内开始下载: ",modelData["songname"]);
                                        theMemStorage.startDownload(modelData);
                                    }
                                }
                            }
                        }
                    }
                    /* 大小与时长两列: 脱离 Row, 直接按列宽比例算出左侧与宽度,
                     * 使 Text 左侧分别对齐排序表头的大小与时长文字左侧 */
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        x: (box.rowContentW*Define.listColumnRatios[0]);
                        width: (box.rowContentW*Define.listColumnRatios[1]);
                        text: Assist.fileSize2text(modelData["size"]);
                        font.pixelSize: 13;
                        font.weight: 400;
                        color: (box.playingRow? Define.choseCyanColor:Define.textColor);
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        x: (box.rowContentW*(Define.listColumnRatios[0]+Define.listColumnRatios[1]));
                        width: (box.rowContentW*Define.listColumnRatios[2]);
                        text: Assist.int2mmss(modelData["duration"]);
                        font.pixelSize: 13;
                        font.weight: 400;
                        color: (box.playingRow? Define.choseCyanColor:Define.textColor);
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                }
            }
            /* 两个悬浮按钮用同一列自下而上排列: 只有一个可见时也落在右下角同一位置 */
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
                    visible: mainArea_RecentPage.playingOutOfView();
                    background: Rectangle {
                        anchors.fill: parent;
                        color: Qt.rgba(246,246,246,0.8);
                        border.width: 1.25;
                        border.color: (jump2PlayingBtn.hovered? Define.btnHoverColor:Define.subGrey);
                    }
                    onClicked: {
                        mainArea_RecentPage.jump2playing();
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
                    visible: (mainListView.contentY>=titleText.height);
                    background: Rectangle {
                        anchors.fill: parent;
                        color: Qt.rgba(246,246,246,0.8);
                        border.width: 1.25;
                        border.color: (jump2TopBtn.hovered? Define.btnHoverColor:Define.subGrey);
                    }
                    onClicked: {
                        mainListView.contentY=0;
                    }
                }
            }
            /* 从 GlobalFileStorage 加载最近播放列表 */
            function rebuild() {
                mainArea_RecentPage.mainListViewModel=sortList(mainArea_RecentPage.collectRecentSongs());
                selectedWhich="";
                contentY=0;
                Assist.dlog("列表","重建列表(最近播放): 共 ",mainArea_RecentPage.mainListViewModel.length," 项");
            }
            /* 同步元数据缓存, 并按当前排序键返回重排副本 */
            function sortList(v) {
                var l=v.length;
                for(var i=0;i<l;i++) {
                    /* 在线条目没有本地元数据, 曲名与歌手直接取清单值 */
                    if(v[i]["online"]===true) {
                        continue;
                    }
                    var m=theMemStorage.metaOf(v[i]["absfpath"]);
                    if(m) {
                        if(m.title!=="") {
                            v[i]["songname"]=m.title;
                        }
                        if(m.artist!=="") {
                            v[i]["singer"]=m.artist;
                        }
                        v[i]["duration"]=(m.duration>0? m.duration:0);
                    }
                }
                if(sortKey==="") {
                    return v;
                }
                var asc=sortAsc;
                var key=sortKey;
                var res=v.slice();
                res.sort(function(a,b) {
                    if(a[key]===b[key]) {
                        return 0;
                    }
                    return ((a[key]>b[key]? 1:-1)*(asc? 1:-1));
                });
                return res;
            }
            /* 排序表头: 同键切换升降序, 异键重置为升序 */
            function sortBy(key) {
                if(sortKey===key) {
                    sortAsc=!sortAsc;
                } else {
                    sortKey=key;
                    sortAsc=true;
                }
                mainArea_RecentPage.mainListViewModel=sortList(mainArea_RecentPage.mainListViewModel);
                Assist.dlog("列表","排序: 键 ",sortKey,", 升序 ",sortAsc);
            }
            /* 曲名与歌手合并按钮: 0 歌名升, 1 歌名降, 2 歌手升, 3 歌手降, 每次点击进入下一态 */
            function sortByName() {
                nameSortStep=(nameSortStep+1)%4;
                sortKey=(nameSortStep<2? "songname":"singer");
                sortAsc=(nameSortStep===0 || nameSortStep===2);
                mainArea_RecentPage.mainListViewModel=sortList(mainArea_RecentPage.mainListViewModel);
                Assist.dlog("列表","排序(合并按钮): 键 ",sortKey,", 升序 ",sortAsc,", 四态下标 ",nameSortStep);
            }
            /* 合并按钮当前态对应的键名 */
            function nameSortLabel() {
                return (nameSortStep<2? "歌名":"歌手");
            }
            /* 合并按钮的排序指示图标: 键与方向都正是当前排序时才显示方向 */
            function nameSortIcon() {
                var key=(nameSortStep<2? "songname":"singer");
                var asc=(nameSortStep===0 || nameSortStep===2);
                if(sortKey===key && sortAsc===asc) {
                    return (asc? "qrc:/assets/iconfont/listview/upsort.svg":"qrc:/assets/iconfont/listview/downsort.svg");
                }
                return "qrc:/assets/iconfont/listview/justsort.svg";
            }
            /* 排序指示图标 */
            function sortIconOf(key) {
                if(sortKey!==key) {
                    return "qrc:/assets/iconfont/listview/justsort.svg";
                }
                return (sortAsc? "qrc:/assets/iconfont/listview/upsort.svg":"qrc:/assets/iconfont/listview/downsort.svg");
            }
            /* 进入或退出批量多选 */
            function setBatchMode(on) {
                /* 切换批量态时复位确认按钮, 避免确认态残留到新状态 */
                batchRemoveBtn.confirming=false;
                /* 离开本页时退出批量态: 批量按钮回到"批量", 勾选与确认态一并复位; 页内标签选中状态不变 */
                if(mainListView.batchMode===true) {
                    mainListView.setBatchMode(false);
                }
                if(batchMode===on) {
                    return;
                }
                batchMode=on;
                selectedWhich="";
                Assist.dlog("列表","批量多选态: ",on);
                if(!batchMode) {
                    setAllChecked(false);
                }
            }
            /* 切换单行勾选 */
            function toggleChecked(idx) {
                var v=mainArea_RecentPage.mainListViewModel.slice();
                v[idx]["checked"]=(v[idx]["checked"]!==true);
                mainArea_RecentPage.mainListViewModel=v;
            }
            /* 全选或取消全选 */
            function setAllChecked(what) {
                Assist.dlog("列表","全选状态改为: ",what,", 共 ",mainArea_RecentPage.mainListViewModel.length," 项");
                var v=mainArea_RecentPage.mainListViewModel;
                var l=v.length;
                for(var i=0;i<l;i++) {
                    v[i]["checked"]=what;
                }
                mainArea_RecentPage.mainListViewModel=v.slice();
            }
            /* 全选按钮: 已全部勾选时改为取消全选 */
            function toggleAllChecked() {
                setAllChecked(!allChecked);
            }
            /* 已勾选的条目 */
            function checkedItems() {
                var v=mainArea_RecentPage.mainListViewModel;
                var l=v.length;
                var res=[];
                for(var i=0;i<l;i++) {
                    if(v[i]["checked"]===true) {
                        res.push(v[i]);
                    }
                }
                return res;
            }
            /* 批量移除记录: 交由 GlobalFileStorage 处理, 外部不直接改写其数据 */
            function batchRemove() {
                var items=checkedItems();
                var l=items.length;
                if(l<=0) {
                    Assist.dlog("列表","批量移除失败: 未勾选任何歌曲");
                    return false;
                }
                var paths=[];
                for(var i=0;i<l;i++) {
                    paths.push(items[i]["absfpath"]);
                }
                GlobalFileStorage.removeRecent(paths);
                Assist.dlog("列表","批量移除记录: ",l);
                rebuild();
                return true;
            }
        }
    }
    /* 整体替换最近播放列表模型时保住滚动位置: 只改条目内容也会重建列表, 不处理就会跳回顶部 */
    function replaceModelKeepScroll(v) {
        var keepY=mainListView.contentY;
        mainArea_RecentPage.mainListViewModel=v;
        mainListView.contentY=keepY;
        return true;
    }
    /* 列表滚动条: 与其它列表共用同一个组件 */
    CustomSliderC {
        id: mainListViewScrollBar;
        anchors {top:parent.top; bottom:parent.bottom; right:parent.right;}
        width: 4;
        visible: (mainListView.contentHeight > mainListView.height);
        handleRatio: Math.max(0.1,mainListView.height/Math.max(1,mainListView.contentHeight));
        hoverHandlerEnabled: false;
        value: from*(mainListView.contentY/Math.max(1,mainListView.contentHeight-mainListView.height));
        onMoved: {
            mainListView.contentY=(value/from)*Math.max(0,mainListView.contentHeight-mainListView.height);
            value=Qt.binding(function() {
                return from*(mainListView.contentY/Math.max(1,mainListView.contentHeight-mainListView.height));
            });
        }
    }
    /* 由最近播放的路径列表生成条目, 最新播放的在前 */
    function collectRecentSongs() {
        var vf=GlobalFileStorage.recentFiles;
        var l=vf.length;
        var v=[];
        for(var i=0;i<l;i++) {
            pushSong(v,vf[i]);
        }
        return v;
    }
    /* 追加单条歌曲: 跳过空路径与重复项 */
    function pushSong(v,absfpath) {
        if(absfpath===undefined || absfpath==="") {
            return;
        }
        var l=v.length;
        for(var i=0;i<l;i++) {
            if(v[i]["absfpath"]===absfpath) {
                return;
            }
        }
        /* 在线歌曲的标识是它的播放地址: 由在线清单还原曲名, 歌手与封面 */
        if(Server.isOnlineKey(absfpath)===true) {
            var online=Server.onlineEntryOfKey(absfpath);
            if(online!==null) {
                v.push(online);
                Server.ensureLoaded();
            }
            return;
        }
        var m=theMemStorage.metaOf(absfpath);
        var sz=AppFileHelper.fileSize(absfpath);
        v.push({
            "songname": (m && m.title!==""? m.title:nameOfFile(absfpath)),
            "singer": (m && m.artist!==""? m.artist:"未知歌手"),
            "absfpath": absfpath,
            "absipath": "",
            "size": (sz>0? sz:0),
            "duration": (m && m.duration>0? m.duration:0),
            "liked": GlobalFileStorage.isLiked(absfpath),
            "checked": false
        });
    }
    /* 由标准化路径取歌曲名 */
    function nameOfFile(absfpath) {
        var p=AppFileHelper.clearPath(absfpath);
        var i=p.lastIndexOf("/");
        if(i>=0) {
            p=p.substring(i+1);
        }
        var d=p.lastIndexOf(".");
        if(d>0) {
            p=p.substring(0,d);
        }
        return p;
    }
    /* 播放: 以整个列表构造播放队列, 优先从选中项开始 */
    function playAllSongs() {
        var v=mainArea_RecentPage.mainListViewModel;
        var l=v.length;
        if(l<=0) {
            Assist.dlog("列表","播放失败: 列表为空");
            return false;
        }
        var which=mainListView.selectedWhich;
        var one=v[0];
        for(var i=0;i<l;i++) {
            if(v[i]["absfpath"]===which) {
                one=v[i];
                break;
            }
        }
        Assist.dlog("列表","播放整个列表(最近播放): ",l," 项, 起点 ",one["absfpath"]);
        return thePlayer.playAll(v,one);
    }
    /* 播放某一行: 播放队列为空时以整个列表构造队列, 否则插到当前播放项之后 */
    function playRow(one) {
        Assist.dlog("列表","播放某一行: ",one["absfpath"]);
        if(GlobalFileStorage.playState.sortlist.length<=0) {
            return thePlayer.playAll(mainArea_RecentPage.mainListViewModel,one);
        }
        return thePlayer.jump2play(one);
    }
    /* 当前播放项在列表中的下标, 不在列表中返回 -1 */
    function playingRowIndex() {
        if(thePlayer===undefined || thePlayer===null) {
            return -1;
        }
        var which=GlobalFileStorage.playState.playingWhich;
        if(which===undefined || which==="") {
            return -1;
        }
        var v=mainArea_RecentPage.mainListViewModel;
        var l=v.length;
        for(var i=0;i<l;i++) {
            if(v[i]["absfpath"]===which) {
                return i;
            }
        }
        return -1;
    }
    /* 当前播放项是否落在列表视域之外 */
    function playingOutOfView() {
        var idx=mainArea_RecentPage.playingRowIndex();
        if(idx<0) {
            return false;
        }
        var top=idx*(mainListView.rowHeight+mainListView.spacing);
        var bottom=top+mainListView.rowHeight;
        return (bottom<=mainListView.contentY || top>=mainListView.contentY+mainListView.height);
    }
    /* 定位到当前播放的歌曲 */
    function jump2playing() {
        var idx=mainArea_RecentPage.playingRowIndex();
        if(idx<0) {
            Assist.dlog("列表","定位失败: 当前播放的歌曲不在列表中");
            return false;
        }
        mainListView.selectedWhich=GlobalFileStorage.playState.playingWhich;
        mainListView.positionViewAtIndex(idx,ListView.Beginning);
        Assist.dlog("列表","定位到当前播放行: 下标 ",idx);
        return true;
    }
    function refresh() {
        mainListView.rebuild();
    }
    /* 钩子: 在列表里定位到指定条目并滚动过去高亮它, 供搜索结果页回跳时调用 */
    function locateSong(one) {
        if(one===undefined || one===null) {
            return false;
        }
        var key=String(one["absfpath"]);
        var v=mainArea_RecentPage.mainListViewModel;
        for(var i=0;i<v.length;i++) {
            if(String(v[i]["absfpath"])===key) {
                mainListView.selectedWhich=key;
                mainListView.positionViewAtIndex(i,ListView.Center);
                Assist.dlog("列表","搜索结果定位: 下标 ",i);
                return true;
            }
        }
        return false;
    }
    /* 关键字搜索: 走统一的搜索匹配算法过滤最近播放列表 */
    function search(keyword) {
        return Assist.searchList(keyword,mainArea_RecentPage.mainListViewModel);
    }
    /* 在线清单就绪后重建一次, 让在线条目取回真实曲名与歌手 */
    Connections {
        target: Server;
        function onLoadStateChanged() {
            if(Server.loadState===2 && mainArea_RecentPage.visible) {
                mainListView.rebuild();
            }
        }
    }
    /* 最近播放由播放动作写入, 显示时重新加载; 页面切走时复位确认按钮 */
    onVisibleChanged: {
        if(visible) {
            refresh();
        } else {
            batchRemoveBtn.confirming=false;
        }
    }
    Component.onCompleted: {
        refresh();
    }
}
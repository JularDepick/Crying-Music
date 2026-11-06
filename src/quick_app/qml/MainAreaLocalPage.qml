import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Effects
import QtQuick.Dialogs
import QtMultimedia

import AppHelper 1.0

import "./"

MainAreaFatherPage {
    id: mainArea_LocalPage;
    visible: false;
    /* 探测元数据用的播放器, 由 Main.qml 注入 */
    property var theProber;
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
            text: "本地和下载";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Row {
            id: headRow;
            topPadding: 5;
            spacing: 0;
            property string curr: "localSongs";
            function jump2(which) {
                Assist.dlog("列表","切换标签: ",curr," -> ",which);
                if(which!==curr) {
                    curr=which;
                    mainListView.setBatchMode(false);
                    mainListView.rebuild();
                }
            }
            Repeater {
                model: ListModel {
                    ListElement {tabname:"本地歌曲"; btnID:"localSongs";}
                    ListElement {tabname:"下载歌曲"; btnID:"downloadedSongs";}
                    ListElement {tabname:"正在下载"; btnID:"downloadingSongs";}
                }
                delegate: CustomButtonA {
                    height: 24;
                    width: 96;
                    transEnabled: false;
                    property bool selected: (headRow.curr===btnID);
                    onClicked: {
                        headRow.jump2(btnID);
                    }
                    background: Rectangle {
                        anchors.fill: parent;
                        color: Define.nocolor;
                        property bool selected: parent.selected;
                        Text {
                            anchors.centerIn: parent;
                            text: tabname;
                            font.pixelSize: 14;
                            color: (parent.selected||parent.parent.hovered? Define.choseCyanColor:"black");
                            transform: Translate {
                                x: (parent.pressed? 2:0);
                                y: (parent.pressed? 2:0);
                            }
                        }
                    }
                    Rectangle {
                        anchors.top: parent.bottom;
                        anchors.topMargin: 5;
                        anchors.horizontalCenter: parent.horizontalCenter;
                        height: 2;
                        width: 25;
                        radius: 1;
                        color: (parent.selected? Define.choseCyanColor:Define.nocolor);
                    }
                }
            }
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
                /* 正在下载的条目还不可播放, 因此该标签下收起播放按钮 */
                visible: (headRow.curr!=="downloadingSongs");
                onClicked: {
                    mainArea_LocalPage.playAllSongs();
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
                id: addSong;
                width: 80;
                height: 30;
                /* 手动添加与自动扫描只作用于本地歌曲 */
                visible: (headRow.curr==="localSongs");
                onClicked: {
                    addSongSubTab.updateP();
                    addSongSubTab.tshow();
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
                            source: `qrc:/assets/iconfont/function/addbtn.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            color: Define.textColor;
                            text: "添加";
                        }
                    }
                }
            }
            CustomButtonA {
                id: batchOp;
                width: 80;
                height: 30;
                /* 批量动作只服务本地歌曲: 在线的移除语义不同, 不在此处提供 */
                visible: (headRow.curr==="localSongs");
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
                CustomButtonA {
                    id: batchAddBtn;
                    width: 110;
                    height: 30;
                    onClicked: {
                        mainListView.batchInsertNext();
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
                                source: `qrc:/assets/iconfont/function/addinto.svg`;
                                color: Define.btnIconColor;
                            }
                            Text {
                                color: Define.textColor;
                                text: "加入播放列表";
                            }
                        }
                    }
                }
                CustomButtonA {
                    id: batchRemoveBtn;
                    width: 80;
                    height: 30;
                    onClicked: {
                        mainListView.batchRemove();
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
                                source: `qrc:/assets/iconfont/function/delete.svg`;
                                color: Define.btnIconColor;
                            }
                            Text {
                                color: Define.textColor;
                                text: "移除选中";
                            }
                        }
                    }
                }
            }
        }
    }
    /* 添加按钮弹出的子菜单: 手动添加歌曲与自动扫描歌曲 */
    Rectangle {
        id: addSongSubTab;
        z: mainViewArea.z+2;
        radius: 8;
        width: 120;
        height: 65;
        color: Define.mainAreaColor;
        visible: false;
        border.color: Define.subGrey;
        border.width: 0.5;
        function updateP() {
            var p=addSong.mapToItem(mainArea_LocalPage,0,0);
            x=p.x+(addSong.width-width)/2;
            y=p.y+addSong.height+5;
        }
        function show() {
            visible=true;
        }
        function hide() {
            visible=false;
        }
        function tshow() {
            visible=!visible;
        }
        Column {
            anchors {fill:parent;}
            padding: 2;
            spacing: 2;
            CustomButtonA {
                width: parent.width-4;
                height: 30;
                transEnabled: false;
                hoverColorEnabled: false;
                onClicked: {
                    songFileDialog.open();
                    addSongSubTab.hide();
                }
                background: Rectangle {
                    anchors.fill: parent;
                    color: (parent.hovered? Define.hoverDarkColor:Define.mainAreaColor);
                    radius: 5;
                    Row {
                        anchors.verticalCenter: parent.verticalCenter;
                        spacing: 5;
                        leftPadding: 10;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: "qrc:/assets/iconfont/function/addfiles.svg";
                            color: Define.btnIconColor;
                        }
                        Text {
                            color: Define.textColor;
                            text: "手动添加歌曲";
                        }
                    }
                }
                FileDialog {
                    id: songFileDialog;
                    title: "请选择需要导入的音频文件(可多选)";
                    acceptLabel: "导入";
                    fileMode: FileDialog.OpenFiles;
                    /* 过滤器由设计常量拼出, 与扫描的格式预选项共用同一份清单 */
                    nameFilters: [
                        "音频文件 ("+Define.audioFormats.map(function(f) { return "*"+f; }).join(" ")+")"
                    ];
                    currentFolder: AppFileHelper.getAppPath();
                    onAccepted: {
                        var vs=selectedFiles;
                        var ls=vs.length;
                        var nv=[];
                        for(var i=0;i<ls;i++) {
                            var p=AppFileHelper.formatPath(vs[i]);
                            if(p!=="") {
                                nv.push(p);
                            }
                        }
                        GlobalFileStorage.addSingleFiles(nv);
                        mainArea_LocalPage.refresh();
                        Assist.dlog("列表",nv);
                    }
                }
            }
            CustomButtonA {
                width: parent.width-4;
                height: 30;
                transEnabled: false;
                hoverColorEnabled: false;
                onClicked: {
                    addSongDirSubTab.open();
                    addSongSubTab.hide();
                }
                background: Rectangle {
                    anchors.fill: parent;
                    color: (parent.hovered? Define.hoverDarkColor:Define.mainAreaColor);
                    radius: 5;
                    Row {
                        anchors.verticalCenter: parent.verticalCenter;
                        spacing: 5;
                        leftPadding: 10;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: "qrc:/assets/iconfont/function/add4dir.svg";
                            color: Define.btnIconColor;
                        }
                        Text {
                            color: Define.textColor;
                            text: "自动扫描歌曲";
                        }
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
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortByName();
                }
                background: Row {
                    Text {
                        color: Define.textColor;
                        text: mainListView.nameSortLabel();
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
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
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortBy("size");
                }
                background: Row {
                    Text {
                        color: Define.textColor;
                        text: "大小";
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
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
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortBy("duration");
                }
                background: Row {
                    Text {
                        color: Define.textColor;
                        text: "时长";
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
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
            DragHandler {
                acceptedDevices: PointerDevice.Mouse;
                target: null;
            }
            boundsBehavior: Flickable.StopAtBounds;
            property string selectedWhich: "";
            property bool batchMode: false;
            /* 列表是否已全部勾选: 供全选按钮在"全选"与"取消全选"之间自动切换 */
            property bool allChecked: (mainArea_LocalPage.mainListViewModel.length>0
                                       && mainArea_LocalPage.mainListViewModel.every(function(one) { return one["checked"]===true; }));
            property string sortKey: "";
            property bool sortAsc: true;
            /* 曲名与歌手合并按钮的四态下标, -1 表示尚未点过该按钮 */
            property int nameSortStep: -1;
            /* 单行高度, 与委托保持一致 */
            property int rowHeight: 60;
            model: mainArea_LocalPage.mainListViewModel;
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
                            if(headRow.curr==="downloadingSongs") {
                                return;
                            }
                            if(mainListView.batchMode) {
                                mainListView.toggleChecked(index);
                                return;
                            }
                            mainListView.selectedWhich=modelData["absfpath"];
                            Assist.dlog("列表","单击: ",mainListView.selectedWhich);
                        }
                        onDoubleClicked: {
                            if(mainListView.batchMode || headRow.curr==="downloadingSongs") {
                                return;
                            }
                            Assist.dlog("列表","双击: ",modelData["absfpath"]);
                            if(GlobalFileStorage.playState.playingWhich===modelData["absfpath"]) {
                                return;
                            }
                            mainArea_LocalPage.playRow(modelData);
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
                                mainArea_LocalPage.playRow(modelData);
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
                                color: (box.playingRow? Define.choseCyanColor:"black");
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
                                color: (box.playingRow? Define.choseCyanColor:"black");
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
                                    /* 正在下载的行还没有可收藏的对象, 该标签下收起收藏与加入按钮 */
                                    visible: (!mainListView.batchMode && headRow.curr!=="downloadingSongs");
                                    height: 20;
                                    width: 20;
                                    icon.source: (liked? "qrc:/assets/iconfont/function/liked.svg":"qrc:/assets/iconfont/function/like.svg");
                                    icon.color: ((liked||hovered)? Define.btnIconRed:Define.btnIconColor);
                                    transEnabled: false;
                                    property bool liked: (modelData["liked"]===true);
                                    onClicked: {
                                        var next=!liked;
                                        GlobalFileStorage.setLiked(modelData["absfpath"],next);
                                        var v=mainArea_LocalPage.mainListViewModel.slice();
                                        v[index]["liked"]=next;
                                        mainArea_LocalPage.replaceModelKeepScroll(v);
                                    }
                                }
                                CustomButtonA {
                                    id: songAddIntoBtn;
                                    /* 加入播放列表与下载按钮跟着行悬停出现, 点赞按钮常驻 */
                                    visible: (!mainListView.batchMode && headRow.curr!=="downloadingSongs"
                                              && box.hoveredRow);
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
                                    visible: (modelData["online"]===true && box.hoveredRow===true && mainListView.batchMode!==true && headRow.curr!=="downloadingSongs");
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
                                /* 取消按钮: 只在正在下载标签出现 */
                                CustomButtonA {
                                    id: songCancelBtn;
                                    visible: (headRow.curr==="downloadingSongs");
                                    height: 20;
                                    width: 20;
                                    icon.source: "qrc:/assets/iconfont/function/close.svg";
                                    icon.color: (hovered? Define.btnIconRed:Define.btnIconColor);
                                    transEnabled: false;
                                    onClicked: {
                                        theMemStorage.cancelDownload(modelData["taskKey"]);
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
                        /* 下载中的行用大小列显示百分比, 其余行显示文件大小 */
                        text: (modelData["progress"]!==undefined
                               ? Math.min(100,Math.max(0,modelData["progress"]))+"%"
                               : Assist.fileSize2text(modelData["size"]));
                        font.pixelSize: 13;
                        font.weight: 400;
                        color: (box.playingRow? Define.choseCyanColor:"black");
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        x: (box.rowContentW*(Define.listColumnRatios[0]+Define.listColumnRatios[1]));
                        width: (box.rowContentW*Define.listColumnRatios[2]);
                        /* 下载中的行用时长列显示已下载与总大小, 其余行显示音频时长 */
                        text: (modelData["progress"]!==undefined
                               ? Assist.fileSize2text(modelData["received"])+"/"+Assist.fileSize2text(modelData["total"])
                               : Assist.int2mmss(modelData["duration"]));
                        font.pixelSize: 13;
                        font.weight: 400;
                        color: (box.playingRow? Define.choseCyanColor:"black");
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                    /* 下载中的行: 行底一条细进度条, 宽度按百分比换算 */
                    Rectangle {
                        visible: (modelData["progress"]!==undefined);
                        anchors {left:parent.left; bottom:parent.bottom;}
                        height: 2;
                        radius: 1;
                        width: (box.rowContentW*Math.min(100,Math.max(0,modelData["progress"]===undefined? 0:modelData["progress"]))/100);
                        color: Define.choseCyanColor;
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
                    visible: mainArea_LocalPage.playingOutOfView();
                    background: Rectangle {
                        anchors.fill: parent;
                        color: Qt.rgba(246,246,246,0.8);
                        border.width: 1.25;
                        border.color: (jump2PlayingBtn.hovered? Define.btnHoverColor:Define.subGrey);
                    }
                    onClicked: {
                        mainArea_LocalPage.jump2playing();
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
            /* 按当前标签重建列表: 本地歌曲取扫描与手动添加项, 下载歌曲取在线清单, 正在下载取下载队列 */
            function rebuild() {
                var v=[];
                if(headRow.curr==="localSongs") {
                    v=mainArea_LocalPage.collectLocalSongs();
                } else if(headRow.curr==="downloadedSongs") {
                    v=mainArea_LocalPage.collectDownloadedSongs();
                } else {
                    v=mainArea_LocalPage.collectDownloadingSongs();
                }
                mainArea_LocalPage.mainListViewModel=sortList(v);
                selectedWhich="";
                contentY=0;
                Assist.dlog("列表","重建列表: 标签 ",headRow.curr,", 共 ",v.length," 项");
            }
            /* 按当前排序键返回重排副本 */
            function sortList(v) {
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
                mainArea_LocalPage.mainListViewModel=sortList(mainArea_LocalPage.mainListViewModel);
                Assist.dlog("列表","排序: 键 ",sortKey,", 升序 ",sortAsc);
            }
            /* 曲名与歌手合并按钮: 0 歌名升, 1 歌名降, 2 歌手升, 3 歌手降, 每次点击进入下一态 */
            function sortByName() {
                nameSortStep=(nameSortStep+1)%4;
                sortKey=(nameSortStep<2? "songname":"singer");
                sortAsc=(nameSortStep===0 || nameSortStep===2);
                mainArea_LocalPage.mainListViewModel=sortList(mainArea_LocalPage.mainListViewModel);
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
            /* 元数据回填: 探测队列排空后统一更新一次列表, 不在每项探测完成时更新 */
            function applyMetaAll() {
                var v=mainArea_LocalPage.mainListViewModel;
                var l=v.length;
                var nv=[];
                for(var i=0;i<l;i++) {
                    /* 在线条目的曲名与歌手一律以清单为准, 元数据回填不覆盖 */
                    if(v[i]["online"]===true) {
                        nv.push(v[i]);
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
                    /* 内嵌封面与内嵌歌词可能晚于条目构造到位, 回填时一并补上;
                     * 空值不覆盖已有值, 没有内嵌封面与歌词的条目保持原样 */
                    var cp=mainArea_LocalPage.coverPathOf(v[i]["absfpath"]);
                    if(cp!=="") {
                        v[i]["absipath"]=cp;
                    }
                    var ln=mainArea_LocalPage.lyricNameOf(v[i]["absfpath"]);
                    if(ln!=="") {
                        v[i]["lyrics"]=ln;
                    }
                    if(v[i]["source"]==="scan" && m && m.duration>=0
                       && m.duration<GlobalFileStorage.localScan.scanRadio) {
                        /* 扫描项时长不满足扫描规则, 不进入列表 */
                        continue;
                    }
                    nv.push(v[i]);
                }
                mainArea_LocalPage.mainListViewModel=sortList(nv);
                Assist.dlog("元数据","回填列表: 应用 ",nv.length," 项");
                /* 本地内嵌歌词已按缓存格式落盘: 刷新一次歌词缓存索引,
                 * 歌词页按歌词名直接取到文件, 不会再为这些名字发起在线拉取 */
                if(mainArea_LocalPage.lyricsCacheDirty===true) {
                    mainArea_LocalPage.lyricsCacheDirty=false;
                    Server.loadLyricsCache();
                }
                /* 队列与列表共享条目对象, 回填后通知播放模块刷新播放栏显示的曲名与歌手 */
                if(thePlayer!==undefined && thePlayer!==null) {
                    thePlayer.syncPlayingInfo();
                }
            }
            /* 喜欢状态轻量同步: 只刷新红心, 不重建列表, 因此滚动位置不跳 */
            function syncLiked() {
                var v=mainArea_LocalPage.mainListViewModel;
                var l=v.length;
                for(var i=0;i<l;i++) {
                    v[i]["liked"]=GlobalFileStorage.isLiked(v[i]["absfpath"]);
                }
                mainArea_LocalPage.mainListViewModel=v.slice();
            }
            /* 进入或退出批量多选 */
            function setBatchMode(on) {
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
                var v=mainArea_LocalPage.mainListViewModel.slice();
                v[idx]["checked"]=(v[idx]["checked"]!==true);
                mainArea_LocalPage.mainListViewModel=v;
            }
            /* 全选或取消全选 */
            function setAllChecked(what) {
                Assist.dlog("列表","全选状态改为: ",what,", 共 ",mainArea_LocalPage.mainListViewModel.length," 项");
                var v=mainArea_LocalPage.mainListViewModel;
                var l=v.length;
                for(var i=0;i<l;i++) {
                    v[i]["checked"]=what;
                }
                mainArea_LocalPage.mainListViewModel=v.slice();
            }
            /* 全选按钮: 已全部勾选时改为取消全选 */
            function toggleAllChecked() {
                setAllChecked(!allChecked);
            }
            /* 已勾选的条目 */
            function checkedItems() {
                var v=mainArea_LocalPage.mainListViewModel;
                var l=v.length;
                var res=[];
                for(var i=0;i<l;i++) {
                    if(v[i]["checked"]===true) {
                        res.push(v[i]);
                    }
                }
                return res;
            }
            /* 批量加入播放列表: 逐项插到当前播放项之后 */
            function batchInsertNext() {
                var items=checkedItems();
                var l=items.length;
                if(l<=0) {
                    Assist.dlog("列表","批量加入失败: 未勾选任何歌曲");
                    return false;
                }
                for(var i=0;i<l;i++) {
                    thePlayer.insertNext(items[i]);
                }
                setAllChecked(false);
                Assist.dlog("列表","批量加入播放列表: ",l);
                return true;
            }
            /* 批量移除: 交由 GlobalFileStorage 处理, 外部不直接改写其数据 */
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
                GlobalFileStorage.removeSongs(paths);
                Assist.dlog("列表","批量移除: ",l);
                rebuild();
                return true;
            }
        }
    }
    /* 整体替换本地列表模型时保住滚动位置: 只改条目内容也会重建列表, 不处理就会跳回顶部 */
    function replaceModelKeepScroll(v) {
        var keepY=mainListView.contentY;
        mainArea_LocalPage.mainListViewModel=v;
        mainListView.contentY=keepY;
        return true;
    }
    /* 列表滚动条: 与其它列表共用同一个组件 */
    CustomSliderC {
        id: mainListViewScrollBar;
        anchors {top:parent.top; bottom:parent.bottom; right:parent.right;}
        width: 4;
        visible: (mainListView.contentHeight > mainListView.height);
        handleRatio: Math.max(0.1,mainListView.height/mainListView.contentHeight);
        hoverHandlerEnabled: false;
        value: from*(mainListView.contentY/Math.max(1,mainListView.contentHeight-mainListView.height));
        onMoved: {
            mainListView.contentY=(value/from)*Math.max(0,mainListView.contentHeight-mainListView.height);
            value=Qt.binding(function() {
                return from*(mainListView.contentY/Math.max(1,mainListView.contentHeight-mainListView.height));
            });
        }
    }
    property var addSongDirViewModel: ([]);
    property var addSongDirFmts: formatCheckRoot1.fmts;
    property var addSongDirRadioMin: (durationGroup1.checkedButton? durationGroup1.checkedButton.radioMin:0);
    /* 自动扫描歌曲弹窗: 文件夹清单与扫描规则 */
    Popup {
        id: addSongDirSubTab;
        parent: Overlay.overlay;
        modal: true;
        dim: false;
        focus: true;
        closePolicy: Popup.CloseOnEscape;
        width: parent.width;
        height: parent.height;
        padding: 0;
        background: Rectangle {
            color: Define.nocolor;
        }
        onOpened: {
            addSongDirSubTabArea.applyScanRules();
            addSongDirSubTabArea.x=(width-addSongDirSubTabArea.width)/2;
            addSongDirSubTabArea.y=(height-addSongDirSubTabArea.height)/2;
        }
        function confirm() {
            /* 保存到 GlobalFileStorage */
            GlobalFileStorage.setMALocalP(mainArea_LocalPage.addSongDirViewModel,
                                          mainArea_LocalPage.addSongDirFmts,
                                          mainArea_LocalPage.addSongDirRadioMin);
            mainArea_LocalPage.refresh();
        }
        Rectangle {
            id: addSongDirSubTabArea;
            width: 640;
            height: 480;
            radius: Define.windowRadius;
            color: "white";
            border.color: Define.subGrey;
            border.width: 1;
            MouseArea {
                anchors.fill: parent;
                acceptedButtons: Qt.LeftButton;
                drag.target: addSongDirSubTabArea;
                drag.axis: Drag.XAndYAxis;
                drag.minimumX: Define.windowPadding;
                drag.maximumX: addSongDirSubTab.width-addSongDirSubTabArea.width-Define.windowPadding;
                drag.minimumY: Define.windowPadding;
                drag.maximumY: addSongDirSubTab.height-addSongDirSubTabArea.height-Define.windowPadding;
            }
            CustomButtonA {
                anchors {top:parent.top; right:parent.right; topMargin:10; rightMargin:10;}
                width: 30;
                height: 30;
                icon.source: "qrc:/assets/iconfont/function/close.svg";
                icon.color: (hovered? Define.mainAreaColor:Define.btnIconColor);
                icon.width: 15;
                icon.height: 15;
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    color: (parent.hovered? Define.warnRed:Define.nocolor);
                }
                onClicked: {
                    addSongDirSubTab.confirm();
                    addSongDirSubTab.close();
                }
            }
            Column {
                anchors.fill: parent;
                padding: 20;
                spacing: 10;
                Text {
                    color: Define.textColor;
                    text: "自动扫描歌曲";
                    font.pixelSize: 18;
                    font.weight: 500;
                }
                Rectangle {
                    anchors {left:parent.left; right:parent.right;}
                    height: 2;
                    radius: 1;
                    color: Define.subGrey;
                }
                Rectangle {
                    width: parent.width-parent.padding*2;
                    height: 30;
                    color: Define.nocolor;
                    Text {
                        color: Define.textColor;
                        anchors.verticalCenter: parent.verticalCenter;
                        text: "勾选自动扫描的文件夹(文件增删实时同步)";
                        font.pixelSize: 15;
                        font.weight: 400;
                    }
                    CustomButtonA {
                        anchors.right: parent.right;
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
                                color: Define.textColor;
                                anchors.centerIn: parent;
                                text: "添加文件夹";
                            }
                        }
                        onClicked: {
                            songDirDialog.open();
                        }
                    }
                }
                Rectangle {
                    id: addSongDirListArea;
                    width: parent.width-parent.padding*2;
                    height: parent.height*0.4;
                    color: Define.mainAreaColor;
                    property var dirListViewModel: mainArea_LocalPage.addSongDirViewModel;
                    ListView {
                        id: addSongDirListView;
                        anchors.fill: parent;
                        spacing: 0;
                        clip: true;
                        boundsBehavior: Flickable.StopAtBounds;
                        model: addSongDirListArea.dirListViewModel;
                        DragHandler {
                            acceptedDevices: PointerDevice.Mouse;
                            target: null;
                        }
                        delegate: Item {
                            width: ListView.view.width;
                            height: 40;
                            Rectangle {
                                anchors.fill: parent;
                                color: Define.nocolor;
                                Row {
                                    anchors.fill: parent;
                                    spacing: 10;
                                    leftPadding: 20;
                                    CustomButtonA {
                                        anchors.verticalCenter: parent.verticalCenter;
                                        transEnabled: false;
                                        hoverHandlerEnabled: false;
                                        width: 16;
                                        height: 16;
                                        icon.source: "qrc:/assets/iconfont/function/checked_stark.svg";
                                        icon.width: 8;
                                        icon.height: 8;
                                        icon.color: Define.mainAreaColor;
                                        property bool selected: modelData["included"];
                                        onClicked: {
                                            selected=!selected;
                                            var v=mainArea_LocalPage.addSongDirViewModel.slice();
                                            v[index]["included"]=selected;
                                            mainArea_LocalPage.addSongDirViewModel=v;
                                        }
                                        background: Rectangle {
                                            anchors.fill: parent;
                                            radius: parent.width/2;
                                            border.width: 1.5;
                                            border.color: (parent.selected? Define.choseCyanColor:Define.btnIconColor);
                                            color: (parent.selected? Define.choseCyanColor:Define.nocolor);
                                        }
                                    }
                                    Text {
                                        color: Define.textColor;
                                        anchors.verticalCenter: parent.verticalCenter;
                                        width: parent.width*0.85;
                                        elide: Text.ElideRight;
                                        wrapMode: Text.NoWrap;
                                        font.pixelSize: 14;
                                        font.weight: 400;
                                        text: AppFileHelper.clearPath(modelData["absdpath"]);
                                        HoverHandler {
                                            id: texthh1;
                                        }
                                        ToolTip.visible: texthh1.hovered&&truncated;
                                        ToolTip.text: text;
                                        ToolTip.delay: 500;
                                    }
                                }
                                CustomButtonA {
                                    anchors.verticalCenter: parent.verticalCenter;
                                    anchors.right: parent.right;
                                    anchors.rightMargin: 20;
                                    width: 12;
                                    height: 12;
                                    icon.source: "qrc:/assets/iconfont/function/close.svg";
                                    icon.color: Define.btnIconColor;
                                    transEnabled: false;
                                    onClicked: {
                                        var mlvm=mainArea_LocalPage.addSongDirViewModel;
                                        var l=mlvm.length;
                                        var v=[];
                                        for(var i=0;i<l;i++) {
                                            if(mlvm[i]["absdpath"]===modelData["absdpath"]) {
                                                continue;
                                            }
                                            v.push(mlvm[i]);
                                        }
                                        mainArea_LocalPage.addSongDirViewModel=v;
                                    }
                                }
                                Rectangle {
                                    anchors {bottom:parent.bottom; left:parent.left; right:parent.right;}
                                    anchors.leftMargin: 15;
                                    anchors.rightMargin: 15;
                                    height: 1;
                                    color: Define.subGrey;
                                }
                            }
                        }
                    }
                    CustomSliderC {
                        id: addSongDirListViewScrollBar;
                        anchors {top:parent.top; bottom:parent.bottom; right:parent.right;}
                        visible: (addSongDirListView.contentHeight > addSongDirListView.height);
                        handleRatio: Math.max(0.1,addSongDirListView.height/addSongDirListView.contentHeight);
                        hoverHandlerEnabled: false;
                        value: from*(addSongDirListView.contentY/Math.max(1,addSongDirListView.contentHeight-addSongDirListView.height));
                        onMoved: {
                            addSongDirListView.contentY=(value/from)*Math.max(0,addSongDirListView.contentHeight-addSongDirListView.height);
                            value=Qt.binding(function() {
                                return from*(addSongDirListView.contentY/Math.max(1,addSongDirListView.contentHeight-addSongDirListView.height));
                            });
                        }
                    }
                }
                Text {
                    color: Define.textColor;
                    text: "扫描规则";
                    font.pixelSize: 15;
                    font.weight: 400;
                }
                Row {
                    spacing: 10;
                    Text {
                        color: Define.textColor;
                        anchors.verticalCenter: parent.verticalCenter;
                        text: "文件时长";
                        font.pixelSize: 14;
                        font.weight: 400;
                    }
                    ButtonGroup {
                        id: durationGroup1;
                    }
                    Repeater {
                        id: durationRepeater1;
                        model: ListModel {
                            ListElement { radioText:"1分钟及以上"; radioMin:60; isChecked:true; }
                            ListElement { radioText:"30秒及以上"; radioMin:30; isChecked:false; }
                            ListElement { radioText:"全部时长"; radioMin:0; isChecked:false; }
                        }
                        delegate: RadioButton {
                            id: durationRadio1;
                            text: radioText;
                            checked: isChecked;
                            spacing: 6;
                            font.pixelSize: 14;
                            font.weight: 400;
                            ButtonGroup.group: durationGroup1;
                            property int minSecond: radioMin;
                            indicator: Rectangle {
                                implicitWidth: 16;
                                implicitHeight: 16;
                                x: durationRadio1.leftPadding;
                                y: durationRadio1.height/2-height/2;
                                radius: width/2;
                                border.width: 1.2;
                                border.color: (durationRadio1.checked? Define.choseCyanColor:Define.subGrey);
                                color: Define.nocolor;
                                Rectangle {
                                    anchors.centerIn: parent;
                                    width: parent.width*0.5;
                                    height: parent.height*0.5;
                                    radius: width/2;
                                    color: Define.choseCyanColor;
                                    visible: durationRadio1.checked;
                                }
                            }
                            contentItem: Text {
                                text: durationRadio1.text;
                                font: durationRadio1.font;
                                color: Define.textColor;
                                verticalAlignment: Text.AlignVCenter;
                                leftPadding: durationRadio1.indicator.width+durationRadio1.spacing;
                            }
                        }
                    }
                }
                Row {
                    spacing: 10;
                    Text {
                        color: Define.textColor;
                        anchors.verticalCenter: parent.verticalCenter;
                        text: "文件格式";
                        font.pixelSize: 14;
                        font.weight: 400;
                    }
                    Item {
                        id: formatCheckRoot1;
                        property var fmts: ([]);
                    }
                    Repeater {
                        id: formatCheckRepeater1;
                        /* 预选项取自设计常量, 界面默认全选 */
                        model: Define.audioFormats;
                        delegate: CheckBox {
                            id: formatCheck;
                            text: modelData;
                            checked: true;
                            spacing: 6;
                            font.pixelSize: 14;
                            font.weight: 400;
                            onCheckedChanged: {
                                if(checked) {
                                    var had=false;
                                    var la=formatCheckRoot1.fmts.length;
                                    var va=formatCheckRoot1.fmts.slice();
                                    for(var ia=0;ia<la;ia++) {
                                        if(va[ia]===modelData) {
                                            had=true;
                                            break;
                                        }
                                    }
                                    if(!had) {
                                        va.push(modelData);
                                        formatCheckRoot1.fmts=va;
                                    }
                                } else {
                                    var lb=formatCheckRoot1.fmts.length;
                                    var vb=[];
                                    for(var ib=0;ib<lb;ib++) {
                                        var one=formatCheckRoot1.fmts[ib];
                                        if(one!==modelData) {
                                            vb.push(one);
                                        }
                                    }
                                    formatCheckRoot1.fmts=vb;
                                }
                            }
                            indicator: Rectangle {
                                implicitWidth: 16;
                                implicitHeight: 16;
                                x: formatCheck.leftPadding;
                                y: formatCheck.height/2-height/2;
                                radius: 2;
                                border.width: 1.2;
                                border.color: (formatCheck.checked? Define.choseCyanColor:Define.subGrey);
                                color: Define.nocolor;
                                Rectangle {
                                    anchors.centerIn: parent;
                                    width: parent.width*0.5;
                                    height: parent.height*0.5;
                                    radius: parent.radius*0.6;
                                    color: Define.choseCyanColor;
                                    visible: formatCheck.checked;
                                }
                            }
                            contentItem: Text {
                                text: formatCheck.text;
                                font: formatCheck.font;
                                color: Define.textColor;
                                verticalAlignment: Text.AlignVCenter;
                                leftPadding: formatCheck.indicator.width+formatCheck.spacing;
                            }
                        }
                    }
                }
            }
            CustomButtonA {
                anchors {bottom:parent.bottom; right:parent.right; bottomMargin:20; rightMargin:20;}
                transEnabled: false;
                width: 80;
                height: 30;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 5;
                    color: (parent.hovered? Define.choseCyanColor:Define.btnHoverColor);
                    border.color: Define.subGrey;
                    border.width: 1;
                    Text {
                        anchors.centerIn: parent;
                        text: "确认";
                        color: "white";
                        font.pixelSize: 14;
                        font.weight: 500;
                    }
                }
                onClicked: {
                    addSongDirSubTab.confirm();
                    addSongDirSubTab.close();
                }
            }
            function toggleDuration2(which) {
                var l=durationRepeater1.count;
                for(var i=0;i<l;i++) {
                    var it=durationRepeater1.itemAt(i);
                    if(it && it.minSecond===which) {
                        it.checked=true;
                        return true;
                    }
                }
                return false;
            }
            function toggleFormat(which,what) {
                if(what!==true && what!==false) {
                    return false;
                }
                var l=formatCheckRepeater1.count;
                for(var i=0;i<l;i++) {
                    var it=formatCheckRepeater1.itemAt(i);
                    if(it && it.text===which) {
                        it.checked=what;
                        return true;
                    }
                }
                return false;
            }
            /* 打开时用存储中的扫描规则回填界面 */
            function applyScanRules() {
                var scan=GlobalFileStorage.localScan;
                var vd=scan.scanDirs;
                var ld=vd.length;
                var v=[];
                for(var i=0;i<ld;i++) {
                    v.push({"absdpath":vd[i]["absdpath"],"included":(vd[i]["included"]===true)});
                }
                mainArea_LocalPage.addSongDirViewModel=v;
                toggleDuration2(scan.scanRadio);
                /* 先清空再回填, 避免初始化时漏掉的勾选变化 */
                var lf=formatCheckRepeater1.count;
                for(var j=0;j<lf;j++) {
                    var it=formatCheckRepeater1.itemAt(j);
                    if(it) {
                        it.checked=false;
                    }
                }
                formatCheckRoot1.fmts=[];
                var ls=scan.scanFmts.length;
                if(ls<=0) {
                    /* 未保存过扫描规则时默认勾选全部格式 */
                    for(var k=0;k<lf;k++) {
                        var d=formatCheckRepeater1.itemAt(k);
                        if(d) {
                            toggleFormat(d.text,true);
                        }
                    }
                } else {
                    for(var m=0;m<ls;m++) {
                        toggleFormat(scan.scanFmts[m],true);
                    }
                }
            }
        }
        FolderDialog {
            id: songDirDialog;
            title: "请选择需要添加的文件夹(仅单选)";
            acceptLabel: "添加";
            currentFolder: AppFileHelper.getAppPath();
            options: FolderDialog.ReadOnly;
            onAccepted: {
                Assist.dlog("列表",selectedFolder);
                var mlvm=mainArea_LocalPage.addSongDirViewModel;
                var l=mlvm.length;
                for(var i=0;i<l;i++) {
                    if(mlvm[i]["absdpath"]===selectedFolder) {
                        Assist.dlog("列表","repeat dir: ",selectedFolder);
                        return;
                    }
                }
                var v=mlvm.slice();
                v.push({"absdpath":selectedFolder,"included":true});
                mainArea_LocalPage.addSongDirViewModel=v;
            }
        }
    }
    /* 由下载记录构造条目: 下载歌曲标签只展示已经下载到本地且文件仍在的歌曲 */
    function collectDownloadedSongs() {
        var v=[];
        var src=GlobalFileStorage.downloads;
        var l=src.length;
        for(var i=0;i<l;i++) {
            var one=src[i];
            var p=(one["absfpath"]===undefined? "":one["absfpath"]);
            if(typeof p!=="string" || p==="") {
                continue;
            }
            /* 记录还在但文件被外部删除时不列出 */
            if(AppFileHelper.existsFile(p)===false) {
                continue;
            }
            var name=(typeof one["songname"]==="string" && one["songname"]!==""
                      ? one["songname"]:mainArea_LocalPage.nameOfFile(p));
            var singer=(typeof one["singer"]==="string" && one["singer"]!==""? one["singer"]:"未知歌手");
            /* 记录只是下载当时的快照: 时长与大小缺失时先看已播放缓存, 时长再缺就按在线标识查清单 */
            var pm=Server.playedMetaOf(one["onlineId"]);
            var dur=(one["duration"]>0? one["duration"]:(pm===null? 0:pm["duration"]));
            if(!(dur>0)) {
                var ent=Server.onlineEntryOfId(one["onlineId"]);
                dur=(ent===null? 0:ent["duration"]);
            }
            var sz=(one["size"]>0? one["size"]
                    :(pm!==null && pm["size"]>0? pm["size"]:AppFileHelper.fileSize(p)));
            v.push({"songname": name,
                    "singer": singer,
                    "absfpath": p,
                    "absipath": "",
                    "size": (sz>0? sz:0),
                    "duration": (dur>0? dur:0),
                    "source": "downloaded",
                    "online": true,
                    "onlineId": one["onlineId"],
                    "cover": (one["cover"]===undefined? "":one["cover"]),
                    "liked": GlobalFileStorage.isLiked(p),
                    "checked": false});
        }
        return v;
    }
    /* 由下载队列构造条目: 供正在下载标签显示进度, 队列由主界面的内存枢纽持有 */
    function collectDownloadingSongs() {
        var v=[];
        var src=(theMemStorage===undefined || theMemStorage===null? []:theMemStorage.downloadTasks);
        var l=src.length;
        for(var i=0;i<l;i++) {
            var t=src[i];
            v.push({"songname":t["songname"],
                    "singer":t["singer"],
                    "absfpath":t["url"],
                    "absipath":"",
                    "size":0,
                    "duration":0,
                    "source":"downloading",
                    "online":true,
                    "onlineId":t["onlineId"],
                    "cover":t["cover"],
                    "liked":false,
                    "checked":false,
                    "progress":t["progress"],
                    "received":t["received"],
                    "total":t["total"],
                    "taskKey":t["onlineId"]});
        }
        return v;
    }
    /* 正在下载标签的就地刷新: 只换模型, 不重置滚动位置 */
    function refreshDownloadingModel() {
        mainArea_LocalPage.mainListViewModel=mainListView.sortList(mainArea_LocalPage.collectDownloadingSongs());
    }
    /* 元数据探测: 先由 FakePlayer 探测, 超时转 AppFileHelper 兜底 */
    property var probeQueue: ([]);
    property string probingPath: "";
    property bool cppProbing: false;
    /* 本批探测已完成项数, 用于向加载条反馈进度 */
    property int probeDone: 0;
    /* 探测进度在加载条上的使用者标识 */
    property string loadingId: "probeMeta";
    /* 内嵌封面: 本地路径 -> 封面文件标准化路径, 探测到之后才有键;
     * 列表条目构造与元数据回填都从这里取, 没有内嵌封面时保持空串并回退应用图标 */
    property var coverPathCache: ({});
    /* 内嵌歌词: 本地路径 -> 歌词缓存主名(不含扩展名), 空串表示该文件没有内嵌歌词;
     * 歌词页按这个主名取歌词, 本地曲目与在线曲目因此走同一套歌词显示 */
    property var lyricNameCache: ({});
    /* 本批是否写出了新的本地歌词: 探测队列排空后据此统一刷新一次歌词缓存索引 */
    property bool lyricsCacheDirty: false;
    Timer {
        id: probeTimeout;
        interval: Define.probeTimeoutMs;
        onTriggered: {
            mainArea_LocalPage.fallbackProbe();
        }
    }
    Timer {
        id: fallbackTimeout;
        interval: Define.probeFallbackMs;
        onTriggered: {
            mainArea_LocalPage.finishProbe({"duration":-1,"title":"","artist":""});
        }
    }
    /* 封面陆续回传: 合并成一次列表刷新, 避免每回来一首就换一次模型 */
    Timer {
        id: coverApplyTimer;
        interval: 500;
        repeat: false;
        onTriggered: {
            mainArea_LocalPage.applyCoverPaths();
        }
    }
    /* theProber 由 Main.qml 注入, 注入后继续排队中的探测 */
    onTheProberChanged: {
        startProbe();
    }
    Connections {
        target: mainArea_LocalPage.theProber;
        function onMediaStatusChanged() {
            mainArea_LocalPage.onProbeStatus();
        }
    }
    Connections {
        target: AppFileHelper;
        function onAudioMetaReady(absfpath,duration,title,artist) {
            mainArea_LocalPage.onFallbackMeta(absfpath,duration,title,artist);
        }
        function onAudioCoverReady(absfpath,coverPath) {
            mainArea_LocalPage.onCoverReady(absfpath,coverPath);
        }
    }
    /* 下载进度变化: 正在下载标签就地换模型 */
    Connections {
        target: mainArea_LocalPage.theMemStorage;
        function onDownloadTasksChanged() {
            if(headRow.curr==="downloadingSongs") {
                mainArea_LocalPage.refreshDownloadingModel();
            }
        }
    }
    /* 下载记录变化: 下载歌曲标签重建一次 */
    Connections {
        target: GlobalFileStorage;
        function onDownloadsChanged() {
            if(headRow.curr==="downloadedSongs") {
                mainListView.rebuild();
            }
        }
    }
    /* 汇总本地歌曲: 手动添加项在前, 扫描文件夹项在后 */
    function collectLocalSongs() {
        var scan=GlobalFileStorage.localScan;
        var v=[];
        var vg=scan.singleFiles;
        var lg=vg.length;
        for(var i=0;i<lg;i++) {
            pushSong(v,vg[i],"manual");
        }
        var vd=scan.scanDirs;
        var ld=vd.length;
        for(var d=0;d<ld;d++) {
            if(vd[d]["included"]!==true || AppFileHelper.existsDir(vd[d]["absdpath"])===false) {
                continue;
            }
            var vf=AppFileHelper.listFiles(vd[d]["absdpath"],1,scan.scanFmts);
            var lf=vf.length;
            for(var f=0;f<lf;f++) {
                pushSong(v,vf[f],"scan");
            }
        }
        return v;
    }
    /* 追加单条歌曲: 跳过已移除项与重复项, 同时入队探测元数据 */
    function pushSong(v,absfpath,source) {
        if(absfpath===undefined || absfpath==="") {
            return;
        }
        if(GlobalFileStorage.isExcluded(absfpath)) {
            return;
        }
        var l=v.length;
        for(var i=0;i<l;i++) {
            if(v[i]["absfpath"]===absfpath) {
                return;
            }
        }
        var m=theMemStorage.metaOf(absfpath);
        var dur=(m? m.duration:-1);
        if(dur>=0 && source==="scan" && dur<GlobalFileStorage.localScan.scanRadio) {
            /* 扫描项时长不满足扫描规则 */
            return;
        }
        var sz=AppFileHelper.fileSize(absfpath);
        /* 封面: 本次已探到或上次运行已缓存时直接带上, 都没有时保持空串, 等探测回填 */
        var cover=coverPathOf(absfpath);
        if(cover==="") {
            cover=AppFileHelper.cachedCoverPath(absfpath);
        }
        v.push({
            "songname": (m && m.title!==""? m.title:nameOfFile(absfpath)),
            "singer": (m && m.artist!==""? m.artist:"未知歌手"),
            "absfpath": absfpath,
            "absipath": cover,
            "lyrics": lyricNameOf(absfpath),
            "size": (sz>0? sz:0),
            "duration": (dur>0? dur:0),
            "source": source,
            "liked": GlobalFileStorage.isLiked(absfpath),
            "checked": false
        });
        if(theMemStorage.hasMeta(absfpath)===false) {
            probeMeta(absfpath);
        }
    }
    /* 取某路径已探到的内嵌封面路径: 还没探测或该文件没有内嵌封面时返回空字符串 */
    function coverPathOf(absfpath) {
        var p=coverPathCache[absfpath];
        return (p===undefined? "":String(p));
    }
    /* 取某路径的内嵌歌词主名: 还没探测或该文件没有内嵌歌词时返回空字符串 */
    function lyricNameOf(absfpath) {
        var p=lyricNameCache[absfpath];
        return (p===undefined? "":String(p));
    }
    /* 记一条内嵌歌词结果: 空串表示该文件没有内嵌歌词, 有键即视为已处理过 */
    function setLyricName(absfpath,name) {
        var m=({});
        for(var k in lyricNameCache) {
            m[k]=lyricNameCache[k];
        }
        m[absfpath]=(name===undefined? "":String(name));
        lyricNameCache=m;
    }
    /* 内嵌封面就绪: 记进缓存并合并成一次列表刷新 */
    function onCoverReady(absfpath,coverPath) {
        if(absfpath===undefined || absfpath==="") {
            return;
        }
        var m=({});
        for(var k in coverPathCache) {
            m[k]=coverPathCache[k];
        }
        m[absfpath]=(coverPath===undefined? "":String(coverPath));
        coverPathCache=m;
        coverApplyTimer.restart();
    }
    /* 把封面路径写回列表条目: 只换条目内容并整体替换模型, 滚动位置保持不变 */
    function applyCoverPaths() {
        var v=mainArea_LocalPage.mainListViewModel;
        var l=v.length;
        var changed=false;
        for(var i=0;i<l;i++) {
            if(v[i]["online"]===true) {
                continue;
            }
            var p=coverPathOf(v[i]["absfpath"]);
            if(p!=="" && v[i]["absipath"]!==p) {
                v[i]["absipath"]=p;
                changed=true;
            }
        }
        if(changed) {
            replaceModelKeepScroll(v.slice());
        }
    }
    /* 内嵌封面与内嵌歌词: 每首本地曲目在元数据探测结束后处理一次;
     * 歌词只按帧长跳跃读标签头, 封面交给 AppFileHelper 自己的读取队列, 都不占用探测超时 */
    function cacheEmbeddedOf(absfpath,durationSec) {
        if(absfpath===undefined || absfpath==="") {
            return;
        }
        var cover=AppFileHelper.cachedCoverPath(absfpath);
        if(cover!=="") {
            onCoverReady(absfpath,cover);
        } else {
            AppFileHelper.readAudioCover(absfpath);
        }
        if(lyricNameCache[absfpath]!==undefined) {
            return;
        }
        var dir=GlobalFileStorage.lyricsCacheDir();
        if(dir==="") {
            setLyricName(absfpath,"");
            return;
        }
        /* 歌词主名沿用缓存命名习惯: local 前缀加路径摘要, 与在线歌词的文件名不会撞车 */
        var mainName="local_"+AppFileHelper.sha256Hex(absfpath).substring(0,16);
        /* 歌词页按歌词增强开关取不同的扩展名, 两档文件名各写一份, 切换档位时同样有歌词;
         * 清单还没就绪时档位名不带扩展名, 这个兜底名也一并写上 */
        var tierName=Server.lyricsVariantName(mainName);
        var names=[tierName,mainName+".lrc"];
        var ready=true;
        for(var i=0;i<names.length;i++) {
            if(AppFileHelper.existsFile(dir+"/"+names[i])!==true) {
                ready=false;
            }
        }
        if(ready) {
            setLyricName(absfpath,mainName);
            return;
        }
        var ms=Math.floor((durationSec>0? durationSec:0)*1000);
        var text=AppFileHelper.readAudioLyrics(absfpath,ms);
        if(text==="") {
            setLyricName(absfpath,"");
            return;
        }
        for(var j=0;j<names.length;j++) {
            var p=dir+"/"+names[j];
            if(AppFileHelper.existsFile(p)!==true) {
                AppFileHelper.writeFile(p,text,"UTF-8");
            }
        }
        setLyricName(absfpath,mainName);
        lyricsCacheDirty=true;
        Assist.dlog("元数据","内嵌歌词已缓存: ",mainName);
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
        var v=mainArea_LocalPage.mainListViewModel;
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
        Assist.dlog("列表","播放整个列表: ",l," 项, 起点 ",one["absfpath"]);
        return thePlayer.playAll(v,one);
    }
    /* 播放某一行: 播放队列为空时以整个列表构造队列, 否则插到当前播放项之后 */
    function playRow(one) {
        Assist.dlog("列表","播放某一行: ",one["absfpath"]);
        if(GlobalFileStorage.playState.sortlist.length<=0) {
            return thePlayer.playAll(mainArea_LocalPage.mainListViewModel,one);
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
        var v=mainArea_LocalPage.mainListViewModel;
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
        var idx=mainArea_LocalPage.playingRowIndex();
        if(idx<0) {
            return false;
        }
        var top=idx*(mainListView.rowHeight+mainListView.spacing);
        var bottom=top+mainListView.rowHeight;
        return (bottom<=mainListView.contentY || top>=mainListView.contentY+mainListView.height);
    }
    /* 定位到当前播放的歌曲 */
    function jump2playing() {
        var idx=mainArea_LocalPage.playingRowIndex();
        if(idx<0) {
            Assist.dlog("列表","定位失败: 当前播放的歌曲不在列表中");
            return false;
        }
        mainListView.selectedWhich=GlobalFileStorage.playState.playingWhich;
        mainListView.positionViewAtIndex(idx,ListView.Beginning);
        Assist.dlog("列表","定位到当前播放行: 下标 ",idx);
        return true;
    }
    /* 入队探测元数据: 队列由空转非空时视为新的一批, 占用加载条并重置计数 */
    function probeMeta(absfpath) {
        if(theMemStorage.hasMeta(absfpath) || absfpath===probingPath) {
            return;
        }
        var l=probeQueue.length;
        var had=false;
        for(var i=0;i<l;i++) {
            if(probeQueue[i]===absfpath) {
                had=true;
                break;
            }
        }
        if(!had) {
            var v=probeQueue.slice();
            v.push(absfpath);
            probeQueue=v;
            if(probingPath==="" && probeQueue.length===1) {
                probeDone=0;
                theMemStorage.startLoading("元数据探测完成",mainArea_LocalPage.loadingId);
            }
        }
        startProbe();
    }
    /* 把本批探测进度推到加载条: 已完成项数占本批总数的比例 */
    function pushProbeRate() {
        var remaining=probeQueue.length+(probingPath!==""? 1:0);
        var total=probeDone+remaining;
        var rate=(total<=0? 100:Math.floor(probeDone*100/total));
        theMemStorage.updateLoading(rate,mainArea_LocalPage.loadingId);
    }
    /* 启动队列中的下一项探测; 队列排空后推进度到满并统一回填列表 */
    function startProbe() {
        if(probeQueue.length<=0) {
            mainArea_LocalPage.pushProbeRate();
            mainListView.applyMetaAll();
            return;
        }
        if(theProber===undefined || theProber===null || probingPath!=="") {
            return;
        }
        var v=probeQueue.slice();
        var one=v.shift();
        probeQueue=v;
        probingPath=one;
        cppProbing=false;
        fallbackTimeout.stop();
        probeTimeout.restart();
        Assist.dlog("元数据","开始探测: ",one,", 队列剩余 ",probeQueue.length);
        theProber.source=one;
    }
    /* FakePlayer 探测状态回调 */
    function onProbeStatus() {
        if(probingPath==="" || cppProbing) {
            return;
        }
        var st=theProber.mediaStatus;
        if(st===MediaPlayer.LoadedMedia || st===MediaPlayer.BufferedMedia) {
            var sec=Math.floor(theProber.duration/1000);
            var title=proberTitle();
            if(sec<=0 && title==="") {
                /* 加载完成但没拿到数据, 直接转兜底 */
                fallbackProbe();
                return;
            }
            finishProbe({"duration":sec,"title":title,"artist":proberArtist()});
        } else if(st===MediaPlayer.InvalidMedia) {
            fallbackProbe();
        }
    }
    /* FakePlayer 探测到的曲名 */
    function proberTitle() {
        var v=theProber.metaData.stringValue(MediaMetaData.Title);
        return (v===undefined? "":v);
    }
    /* FakePlayer 探测到的歌手: 优先贡献艺术家, 依次回退专辑艺术家与作者 */
    function proberArtist() {
        var md=theProber.metaData;
        var v=md.stringValue(MediaMetaData.ContributingArtist);
        if(v===undefined || v==="") {
            v=md.stringValue(MediaMetaData.AlbumArtist);
        }
        if(v===undefined || v==="") {
            v=md.stringValue(MediaMetaData.Author);
        }
        return (v===undefined? "":v);
    }
    /* 超时转 AppFileHelper 兜底 */
    function fallbackProbe() {
        if(probingPath==="" || cppProbing) {
            return;
        }
        probeTimeout.stop();
        cppProbing=true;
        Assist.dlog("元数据","探测超时, 转文件辅助类兜底: ",probingPath);
        /* 取消 FakePlayer 上未完成的加载 */
        theProber.source="";
        fallbackTimeout.restart();
        AppFileHelper.readAudioMeta(probingPath);
    }
    /* AppFileHelper 兜底结果回调 */
    function onFallbackMeta(absfpath,duration,title,artist) {
        if(cppProbing===false || absfpath!==probingPath) {
            return;
        }
        finishProbe({"duration":Math.floor(duration/1000),"title":title,"artist":artist});
    }
    /* 记录探测结果并继续队列 */
    function finishProbe(meta) {
        var done=probingPath;
        probingPath="";
        cppProbing=false;
        probeTimeout.stop();
        fallbackTimeout.stop();
        theMemStorage.setMeta(done,{"duration":(meta.duration>0? meta.duration:-1),
                                        "title":(meta.title===undefined? "":meta.title),
                                        "artist":(meta.artist===undefined? "":meta.artist)});
        /* 探测收尾时补内嵌封面与内嵌歌词, 两者都不占用探测与兜底的超时 */
        mainArea_LocalPage.cacheEmbeddedOf(done,(meta.duration>0? meta.duration:0));
        probeDone=probeDone+1;
        mainArea_LocalPage.pushProbeRate();
        startProbe();
    }
    function subsHide(scenePos) {
        if(Assist.hitItem(addSong, scenePos) || Assist.hitItem(addSongSubTab, scenePos)) {
            return;
        }
        addSongSubTab.hide();
    }
    function refresh() {
        mainListView.rebuild();
    }
    function jump2list() {
        ;
    }
    /* 关键字搜索: 走统一的搜索匹配算法过滤当前标签的列表条目 */
    function search(keyword) {
        return Assist.searchList(keyword,mainArea_LocalPage.mainListViewModel);
    }
    /* 红心状态会被其它页面改写, 显示时轻量同步一次;
     * 下载歌曲标签的数据来自下载记录, 显示时重建一次 */
    onVisibleChanged: {
        if(visible) {
            if(headRow.curr==="downloadedSongs") {
                mainListView.rebuild();
            } else {
                mainListView.syncLiked();
            }
        }
    }
    Component.onCompleted: {
        refresh();
    }
}
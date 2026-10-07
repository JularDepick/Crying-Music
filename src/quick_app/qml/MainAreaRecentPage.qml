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
                            width: 15;
                            height: 15;
                            source: `qrc:/assets/iconfont/function/batch.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            text: "批量";
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
                        mainListView.setAllChecked(true);
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
                                source: `qrc:/assets/iconfont/function/checked_stark.svg`;
                                color: Define.btnIconColor;
                            }
                            Text {
                                text: "全选";
                            }
                        }
                    }
                }
                CustomButtonA {
                    id: batchRemoveBtn;
                    width: 100;
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
                                width: 15;
                                height: 15;
                                source: `qrc:/assets/iconfont/function/close.svg`;
                                color: Define.btnIconColor;
                            }
                            Text {
                                text: "移除记录";
                            }
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
            width: parent.width*0.7;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortByName();
                }
                background: Row {
                    Text {
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
            width: parent.width*0.15;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortBy("size");
                }
                background: Row {
                    Text {
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
            width: parent.width*0.15;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortBy("duration");
                }
                background: Row {
                    Text {
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
            spacing: 1;
            clip: true;
            DragHandler {
                acceptedDevices: PointerDevice.Mouse;
                target: null;
            }
            boundsBehavior: Flickable.StopAtBounds;
            property string selectedWhich: "";
            property bool batchMode: false;
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
                    property bool hoveredRow: (boxClick.containsMouse||songAvatarBtn.hovered);
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
                            console.log("单击: ",mainListView.selectedWhich);
                        }
                        onDoubleClicked: {
                            if(mainListView.batchMode) {
                                return;
                            }
                            console.log("双击: ",modelData["absfpath"]);
                            if(GlobalFileStorage.playState.playingWhich===modelData["absfpath"]) {
                                return;
                            }
                            mainArea_RecentPage.playRow(modelData);
                        }
                    }
                    Row {
                        anchors.fill: parent;
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
                            icon.source: (mainListView.batchMode? "":(boxClick.containsMouse||hovered? "qrc:/assets/iconfont/playerbar/play.svg":""));
                            icon.color: (hovered? Define.btnHoverColor:Define.mainAreaColor);
                            icon.width: 17;
                            icon.height: 17;
                            onClicked: {
                                if(mainListView.batchMode) {
                                    mainListView.toggleChecked(index);
                                    return;
                                }
                                if(GlobalFileStorage.playState.playingWhich===modelData["absfpath"]) {
                                    return;
                                }
                                mainArea_RecentPage.playRow(modelData);
                            }
                            background: Item {
                                anchors.fill: parent;
                                Image {
                                    id: songAvatarImage;
                                    anchors.fill: parent;
                                    source: (modelData["absipath"]&&modelData["absipath"]!==""? modelData["absipath"]:"qrc:/favicon.jpg");
                                    fillMode: Image.PreserveAspectCrop;
                                    layer.enabled: true;
                                    layer.effect: MultiEffect {
                                        maskEnabled: true;
                                        maskSource: songAvatarMasker;
                                    }
                                    Item {
                                        id: songAvatarMasker;
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
                                    color: (songAvatarBtn.hovered||boxClick.containsMouse? Qt.rgba(0,0,0,0.3):Define.nocolor);
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter;
                            spacing: 5;
                            width: 240;
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
                        CustomButtonA {
                            visible: !mainListView.batchMode;
                            anchors.verticalCenter: parent.verticalCenter;
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
                                mainArea_RecentPage.mainListViewModel=v;
                            }
                        }
                        CustomButtonA {
                            visible: !mainListView.batchMode;
                            anchors.verticalCenter: parent.verticalCenter;
                            height: 20;
                            width: 20;
                            icon.source: "qrc:/assets/iconfont/function/addinto.svg";
                            transEnabled: false;
                            onClicked: {
                                thePlayer.insertNext(modelData);
                            }
                        }
                    }
                }
            }
            CustomButtonA {
                id: jump2PlayingBtn;
                anchors {bottom:jump2TopBtn.top; right:parent.right; bottomMargin:10; rightMargin:15;}
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
                anchors {bottom:parent.bottom; right:parent.right; bottomMargin:15; rightMargin:15;}
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
            /* 从 GlobalFileStorage 加载最近播放列表 */
            function rebuild() {
                mainArea_RecentPage.mainListViewModel=sortList(mainArea_RecentPage.collectRecentSongs());
                selectedWhich="";
                contentY=0;
            }
            /* 同步元数据缓存, 并按当前排序键返回重排副本 */
            function sortList(v) {
                var l=v.length;
                for(var i=0;i<l;i++) {
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
            }
            /* 曲名与歌手合并按钮: 0 歌名升, 1 歌名降, 2 歌手升, 3 歌手降, 每次点击进入下一态 */
            function sortByName() {
                nameSortStep=(nameSortStep+1)%4;
                sortKey=(nameSortStep<2? "songname":"singer");
                sortAsc=(nameSortStep===0 || nameSortStep===2);
                mainArea_RecentPage.mainListViewModel=sortList(mainArea_RecentPage.mainListViewModel);
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
                if(batchMode===on) {
                    return;
                }
                batchMode=on;
                selectedWhich="";
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
                var v=mainArea_RecentPage.mainListViewModel;
                var l=v.length;
                for(var i=0;i<l;i++) {
                    v[i]["checked"]=what;
                }
                mainArea_RecentPage.mainListViewModel=v.slice();
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
                    console.log("批量移除失败: 未勾选任何歌曲");
                    return false;
                }
                var paths=[];
                for(var i=0;i<l;i++) {
                    paths.push(items[i]["absfpath"]);
                }
                GlobalFileStorage.removeRecent(paths);
                console.log("批量移除记录: ",l);
                rebuild();
                return true;
            }
        }
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
            console.log("播放失败: 列表为空");
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
        return thePlayer.playAll(v,one);
    }
    /* 播放某一行: 播放队列为空时以整个列表构造队列, 否则插到当前播放项之后 */
    function playRow(one) {
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
            console.log("定位失败: 当前播放的歌曲不在列表中");
            return false;
        }
        mainListView.selectedWhich=GlobalFileStorage.playState.playingWhich;
        mainListView.positionViewAtIndex(idx,ListView.Beginning);
        return true;
    }
    function refresh() {
        mainListView.rebuild();
    }
    /* 最近播放由播放动作写入, 显示时重新加载 */
    onVisibleChanged: {
        if(visible) {
            refresh();
        }
    }
    Component.onCompleted: {
        refresh();
    }
}
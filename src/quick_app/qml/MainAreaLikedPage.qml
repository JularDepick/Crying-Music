import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Effects

import AppHelper 1.0

import "./"

MainAreaFatherPage {
    id: mainArea_LikedPage;
    visible: false;
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
            text: "我的喜欢";
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
                    mainArea_LikedPage.playAllSongs();
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
                    id: batchUnlikeBtn;
                    width: 100;
                    height: 30;
                    onClicked: {
                        mainListView.batchUnlike();
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
                                source: `qrc:/assets/iconfont/function/like.svg`;
                                color: Define.btnIconColor;
                            }
                            Text {
                                text: "取消喜欢";
                            }
                        }
                    }
                }
            }
        }
    }
    Row {
        id: sortHead;
        anchors {left:parent.left; right:parent.right; top:headColum.bottom;}
        anchors.leftMargin: 40;
        anchors.rightMargin: 40;
        height: 20;
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*0.4;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortBy("songname");
                }
                background: Row {
                    Text {
                        text: "歌名";
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
                        width: 10;
                        height: 10;
                        source: mainListView.sortIconOf("songname");
                        color: Define.btnIconColor;
                    }
                }
            }
        }
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*0.3;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    mainListView.sortBy("singer");
                }
                background: Row {
                    Text {
                        text: "歌手";
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
                        width: 10;
                        height: 10;
                        source: mainListView.sortIconOf("singer");
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
    property var mainListViewModel: ([]);
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
            model: mainArea_LikedPage.mainListViewModel;
            delegate: Item {
                width: ListView.view.width;
                height: 60;
                Rectangle {
                    id: box;
                    anchors.fill: parent;
                    anchors.leftMargin: 40;
                    anchors.rightMargin: 40;
                    radius: 10;
                    property bool checkedRow: (modelData["checked"]===true);
                    property bool selectedRow: (mainListView.selectedWhich===modelData["absfpath"]);
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
                            if(thePlayer.playingWhich===modelData["absfpath"]) {
                                return;
                            }
                            thePlayer.jump2play(modelData);
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
                                if(thePlayer.playingWhich===modelData["absfpath"]) {
                                    return;
                                }
                                thePlayer.jump2play(modelData);
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
                            Text {
                                width: parent.width;
                                text: modelData["songname"];
                                font.pixelSize: 14;
                                font.weight: 400;
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
                                GlobalFileStorage.setLiked(modelData["absfpath"],false);
                                mainListView.removeRow(index);
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
                visible: (mainArea_LikedPage.playingRowIndex()>=0);
                background: Rectangle {
                    anchors.fill: parent;
                    color: Qt.rgba(246,246,246,0.8);
                    border.width: 1.25;
                    border.color: (jump2PlayingBtn.hovered? Define.btnHoverColor:Define.subGrey);
                }
                onClicked: {
                    mainArea_LikedPage.jump2playing();
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
            /* 从 GlobalFileStorage 加载喜欢列表 */
            function rebuild() {
                mainArea_LikedPage.mainListViewModel=sortList(mainArea_LikedPage.collectLikedSongs());
                selectedWhich="";
                contentY=0;
            }
            /* 同步元数据缓存, 并按当前排序键返回重排副本 */
            function sortList(v) {
                var l=v.length;
                for(var i=0;i<l;i++) {
                    var m=GlobalFileStorage.metaOf(v[i]["absfpath"]);
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
                mainArea_LikedPage.mainListViewModel=sortList(mainArea_LikedPage.mainListViewModel);
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
                var v=mainArea_LikedPage.mainListViewModel.slice();
                v[idx]["checked"]=(v[idx]["checked"]!==true);
                mainArea_LikedPage.mainListViewModel=v;
            }
            /* 全选或取消全选 */
            function setAllChecked(what) {
                var v=mainArea_LikedPage.mainListViewModel;
                var l=v.length;
                for(var i=0;i<l;i++) {
                    v[i]["checked"]=what;
                }
                mainArea_LikedPage.mainListViewModel=v.slice();
            }
            /* 已勾选的条目 */
            function checkedItems() {
                var v=mainArea_LikedPage.mainListViewModel;
                var l=v.length;
                var res=[];
                for(var i=0;i<l;i++) {
                    if(v[i]["checked"]===true) {
                        res.push(v[i]);
                    }
                }
                return res;
            }
            /* 从当前列表移除单行, 不重建以免滚动位置跳动 */
            function removeRow(idx) {
                var v=mainArea_LikedPage.mainListViewModel;
                var l=v.length;
                var nv=[];
                for(var i=0;i<l;i++) {
                    if(i!==idx) {
                        nv.push(v[i]);
                    }
                }
                mainArea_LikedPage.mainListViewModel=nv;
            }
            /* 批量取消喜欢: 交由 GlobalFileStorage 处理, 外部不直接改写其数据 */
            function batchUnlike() {
                var items=checkedItems();
                var l=items.length;
                if(l<=0) {
                    console.log("批量取消喜欢失败: 未勾选任何歌曲");
                    return false;
                }
                var paths=[];
                for(var i=0;i<l;i++) {
                    paths.push(items[i]["absfpath"]);
                }
                GlobalFileStorage.removeLiked(paths);
                console.log("批量取消喜欢: ",l);
                rebuild();
                return true;
            }
        }
    }
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
    /* 由喜欢的路径列表生成条目 */
    function collectLikedSongs() {
        var vf=GlobalFileStorage.likedFiles;
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
        var m=GlobalFileStorage.metaOf(absfpath);
        var sz=AppFileHelper.fileSize(absfpath);
        v.push({
            "songname": (m && m.title!==""? m.title:nameOfFile(absfpath)),
            "singer": (m && m.artist!==""? m.artist:"未知歌手"),
            "absfpath": absfpath,
            "absipath": "",
            "size": (sz>0? sz:0),
            "duration": (m && m.duration>0? m.duration:0),
            "liked": true,
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
        var v=mainArea_LikedPage.mainListViewModel;
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
    /* 当前播放项在列表中的下标, 不在列表中返回 -1 */
    function playingRowIndex() {
        if(thePlayer===undefined || thePlayer===null) {
            return -1;
        }
        var which=thePlayer.playingWhich;
        if(which===undefined || which==="") {
            return -1;
        }
        var v=mainArea_LikedPage.mainListViewModel;
        var l=v.length;
        for(var i=0;i<l;i++) {
            if(v[i]["absfpath"]===which) {
                return i;
            }
        }
        return -1;
    }
    /* 定位到当前播放的歌曲 */
    function jump2playing() {
        var idx=mainArea_LikedPage.playingRowIndex();
        if(idx<0) {
            console.log("定位失败: 当前播放的歌曲不在列表中");
            return false;
        }
        mainListView.selectedWhich=thePlayer.playingWhich;
        mainListView.positionViewAtIndex(idx,ListView.Beginning);
        return true;
    }
    function refresh() {
        mainListView.rebuild();
    }
    /* 喜欢列表由其他页面写入, 显示时重新加载 */
    onVisibleChanged: {
        if(visible) {
            refresh();
        }
    }
    Component.onCompleted: {
        refresh();
    }
}
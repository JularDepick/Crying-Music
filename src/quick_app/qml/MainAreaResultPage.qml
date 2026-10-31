import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Effects

import "./"

/* 搜索结果页: 只由顶栏搜索触发进入, 展示发起搜索的页面交出的命中条目;
 * 本页不参与左侧栏路由, 也不写入界面状态, 重启后回到发起搜索前的页面 */
MainAreaFatherPage {
    id: mainArea_ResultPage;
    visible: false;
    /* 本次搜索的关键字与命中条目: 由主界面在触发搜索时写入 */
    property string keyword: "";
    property var resultModel: ([]);
    /* 发起搜索的页面: 刷新与再次搜索时回到它取结果 */
    property var originPage: null;
    /* 标题与功能行 */
    Column {
        id: headColum;
        anchors {left:parent.left; right:parent.right;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        Text {
            id: titleText;
            text: "搜索结果";
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
                width: 80;
                height: 30;
                visible: (mainArea_ResultPage.resultModel.length>0);
                onClicked: {
                    mainArea_ResultPage.playAllSongs();
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
            Text {
                anchors.verticalCenter: parent.verticalCenter;
                text: (mainArea_ResultPage.keyword===""? ""
                       :("关键字: "+mainArea_ResultPage.keyword+" · 共 "+mainArea_ResultPage.resultModel.length+" 首"));
                font.pixelSize: 13;
                color: Define.btnIconColor;
                elide: Text.ElideRight;
                width: Math.min(implicitWidth,functionBox.width-playAllBtn.width-40);
            }
        }
    }
    /* 列表区: 命中条目, 行内可播放, 喜欢与加入播放列表 */
    Rectangle {
        id: mainViewArea;
        anchors {left:parent.left; right:parent.right; top:headColum.bottom; bottom:parent.bottom;}
        color: Define.nocolor;
        ListView {
            id: mainListView;
            anchors.fill: parent;
            anchors.topMargin: 5;
            spacing: 0;
            clip: true;
            boundsBehavior: Flickable.StopAtBounds;
            DragHandler {
                acceptedDevices: PointerDevice.Mouse;
                target: null;
            }
            property string selectedWhich: "";
            property int rowHeight: 60;
            model: mainArea_ResultPage.resultModel;
            delegate: Item {
                width: ListView.view.width;
                height: mainListView.rowHeight;
                Rectangle {
                    id: box;
                    anchors.fill: parent;
                    anchors.leftMargin: 40;
                    anchors.rightMargin: 40;
                    radius: 10;
                    property bool selectedRow: (mainListView.selectedWhich===modelData["absfpath"]);
                    property bool playingRow: (GlobalFileStorage.playState.playingWhich===modelData["absfpath"]);
                    /* 行内可用内容宽度: 与三列列宽比例相乘得到列宽 */
                    property real rowContentW: (mainListView.width-anchors.leftMargin-anchors.rightMargin);
                    property bool hoveredRow: (boxClick.containsMouse||songAvatarBtn.hovered||songLikeBtn.hovered||songAddIntoBtn.hovered||songnameHh.hovered||singerHh.hovered);
                    color: (selectedRow? Define.choseDarkColor:(hoveredRow? Define.hoverDarkColor:(index%2===1? Define.canvasColor:Define.mainAreaColor)));
                    MouseArea {
                        id: boxClick;
                        anchors.fill: parent;
                        hoverEnabled: true;
                        onClicked: {
                            mainListView.selectedWhich=modelData["absfpath"];
                            Assist.dlog("列表","单击搜索结果: ",mainListView.selectedWhich);
                        }
                        onDoubleClicked: {
                            if(GlobalFileStorage.playState.playingWhich===modelData["absfpath"]) {
                                return;
                            }
                            mainArea_ResultPage.playRow(modelData);
                        }
                    }
                    Row {
                        anchors.fill: parent;
                        topPadding: 8;
                        leftPadding: 10;
                        rightPadding: 10;
                        spacing: 10;
                        CustomButtonA {
                            id: songAvatarBtn;
                            anchors.verticalCenter: parent.verticalCenter;
                            height: 40;
                            width: height;
                            transEnabled: false;
                            hoverHandlerEnabled: false;
                            icon.source: (boxClick.containsMouse||hovered? "qrc:/assets/iconfont/playerbar/play.svg":"");
                            icon.color: (hovered? Define.btnHoverColor:Define.mainAreaColor);
                            icon.width: 17;
                            icon.height: 17;
                            onClicked: {
                                if(GlobalFileStorage.playState.playingWhich===modelData["absfpath"]) {
                                    return;
                                }
                                mainArea_ResultPage.playRow(modelData);
                            }
                            background: Item {
                                anchors.fill: parent;
                                Image {
                                    id: songAvatarImage;
                                    anchors.fill: parent;
                                    /* 封面: 本地路径优先, 在线条目取在线图标缓存, 都没有时回退应用图标 */
                                    property string iconKey: (modelData["icon"]===undefined? "":modelData["icon"]);
                                    onIconKeyChanged: {
                                        Server.requestIcon(iconKey);
                                    }
                                    source: mainArea_ResultPage.coverOf(modelData);
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
                                    color: ((songAvatarBtn.hovered||boxClick.containsMouse)? Qt.rgba(0,0,0,0.3):Define.nocolor);
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter;
                            spacing: 5;
                            width: Define.songColWidth;
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
                        /* 喜欢与加入播放列表 */
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
                                    height: 20;
                                    width: 20;
                                    icon.source: (liked? "qrc:/assets/iconfont/function/liked.svg":"qrc:/assets/iconfont/function/like.svg");
                                    icon.color: ((liked||hovered)? Define.btnIconRed:Define.btnIconColor);
                                    transEnabled: false;
                                    property bool liked: (modelData["liked"]===true);
                                    onClicked: {
                                        var next=!liked;
                                        GlobalFileStorage.setLiked(modelData["absfpath"],next);
                                        var v=mainArea_ResultPage.resultModel.slice();
                                        v[index]["liked"]=next;
                                        mainArea_ResultPage.replaceModelKeepScroll(v);
                                    }
                                }
                                CustomButtonA {
                                    id: songAddIntoBtn;
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
                    /* 大小与时长两列: 按列宽比例算出左侧与宽度, 与其它列表页一致 */
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        x: (box.rowContentW*Define.listColumnRatios[0]);
                        width: (box.rowContentW*Define.listColumnRatios[1]);
                        text: Assist.fileSize2text(modelData["size"]);
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
                        text: Assist.int2mmss(modelData["duration"]);
                        font.pixelSize: 13;
                        font.weight: 400;
                        color: (box.playingRow? Define.choseCyanColor:"black");
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                }
            }
        }
        /* 空结果提示 */
        Text {
            id: emptyTip;
            anchors.centerIn: parent;
            visible: (mainArea_ResultPage.keyword!=="" && mainArea_ResultPage.resultModel.length<=0);
            text: "没有与当前关键字匹配的歌曲";
            font.pixelSize: 14;
            color: Define.btnIconColor;
        }
    }
    /* 整体替换结果列表模型时保住滚动位置: 只改条目内容也会重建列表, 不处理就会跳回顶部 */
    function replaceModelKeepScroll(v) {
        var keepY=mainListView.contentY;
        mainArea_ResultPage.resultModel=v;
        mainListView.contentY=keepY;
        return true;
    }
    /* 列表滚动条: 与其它列表共用同一个组件 */
    CustomSliderC {
        id: mainListViewScrollBar;
        anchors {top:mainViewArea.top; bottom:mainViewArea.bottom; right:parent.right;}
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
    /* 接收一次搜索结果: origin 为发起搜索的页面, 本页刷新与再次搜索都回到它 */
    function showResult(kw,list,origin) {
        keyword=String(kw===undefined || kw===null? "":kw);
        originPage=origin;
        resultModel=(list===undefined || list===null? []:list);
        mainListView.selectedWhich="";
        mainListView.contentY=0;
        return true;
    }
    /* 本页的搜索: 已经是结果页时向发起搜索的页面重新取结果 */
    function search(kw) {
        if(originPage===null || originPage===undefined) {
            return [];
        }
        return (typeof originPage.search==="function"? originPage.search(kw):[]);
    }
    /* 封面来源: 优先取本地封面, 其次在线图标缓存, 都没有时回退应用图标 */
    function coverOf(one) {
        if(one===undefined || one===null) {
            return "qrc:/favicon.jpg";
        }
        var ip=one["absipath"];
        if(typeof ip==="string" && ip!=="") {
            return ip;
        }
        var key=(one["icon"]===undefined? "":one["icon"]);
        if(typeof key!=="string" || key==="") {
            return "qrc:/favicon.jpg";
        }
        var p=Server.iconCache[key];
        return (typeof p==="string" && p!==""? p:"qrc:/favicon.jpg");
    }
    /* 喜欢状态会被其它页面改写, 显示时轻量同步一次 */
    function syncLiked() {
        var v=mainArea_ResultPage.resultModel;
        var l=v.length;
        for(var i=0;i<l;i++) {
            v[i]["liked"]=GlobalFileStorage.isLiked(v[i]["absfpath"]);
        }
        mainArea_ResultPage.resultModel=v.slice();
    }
    /* 播放: 以整个结果列表构造播放队列, 优先从选中项开始 */
    function playAllSongs() {
        var v=mainArea_ResultPage.resultModel;
        var l=v.length;
        if(l<=0) {
            Assist.dlog("列表","播放失败: 搜索结果为空");
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
        Assist.dlog("列表","播放搜索结果: ",l," 项, 起点 ",one["absfpath"]);
        return thePlayer.playAll(v,one);
    }
    /* 播放某一行: 播放队列为空时以整个结果列表构造队列, 否则插到当前播放项之后 */
    function playRow(one) {
        Assist.dlog("列表","播放搜索结果的行: ",one["absfpath"]);
        if(GlobalFileStorage.playState.sortlist.length<=0) {
            return thePlayer.playAll(mainArea_ResultPage.resultModel,one);
        }
        return thePlayer.jump2play(one);
    }
    function subsHide(scenePos) {
    }
    /* 顶栏刷新: 用同一个关键字向发起搜索的页面重新取结果 */
    function refresh() {
        if(keyword==="") {
            return false;
        }
        resultModel=mainArea_ResultPage.search(keyword);
        Assist.dlog("列表","搜索结果刷新: ",keyword,", 共 ",resultModel.length," 项");
        return true;
    }
    onVisibleChanged: {
        if(visible) {
            syncLiked();
        }
    }
}

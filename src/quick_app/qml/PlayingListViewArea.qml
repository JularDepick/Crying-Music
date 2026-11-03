import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "./"

/* 播放列表面板的内容: 可选头部(标题, 曲目数, 清空列表)加列表区(列表本体, 竖向滚动条, 两枚悬浮按钮).
 * 容器外壳(底色, 圆角, 宽度, 锚点, 显示状态)由宿主提供, 因此同一份实现可以被主界面面板与歌词页面板各放一份;
 * 队列与当前播放项一律来自注入的播放器对象, 两处实例共享同一份状态 */
Rectangle {
    id: root;
    /* 注入: 持有播放队列与播放命令的播放器对象 */
    property var thePlayer: null;
    /* 实例开关: 是否带面板头部(标题, 曲目数与清空列表); 关掉后只保留列表 */
    property bool headEnabled: true;
    /* 实例开关: 头部只留空白占位, 不显示标题, 曲目数与清空按钮; 歌词页用 */
    property bool headBlank: false;
    /* 实例开关: 播放状态变化时是否自动定位到当前播放行 */
    property bool autoFollow: true;
    /* 队列, 当前播放标识与下标: 统一从注入的播放器取, 未注入时按空队列处理 */
    readonly property var queue: (thePlayer===null? []:thePlayer.sortlist);
    readonly property string playingKey: (thePlayer===null? "":String(thePlayer.playingWhich));
    readonly property int playingIndex: (thePlayer===null? -1:thePlayer.playingIndex);
    color: Define.nocolor;
    /* 这一层既挡住面板下方主内容区的点击, 也吃掉列表没有消费的滚轮事件,
     * 避免列表滚到边界后继续滚动下层界面的列表 */
    MouseArea {
        anchors.fill: parent;
        onWheel: (wheel)=> {
            wheel.accepted=true;
        }
    }
    /* 头部: 标题, 曲目数与清空列表; 关闭时整段不占位, 只留空白时按内边距占位 */
    Column {
        id: playingListHead;
        anchors {left:parent.left; right:parent.right; top:parent.top;}
        visible: (root.headEnabled || root.headBlank);
        padding: 20;
        bottomPadding: (root.headEnabled? 10:20);
        spacing: 10;
        Rectangle {
            visible: root.headEnabled;
            width: parent.width-parent.padding*2;
            height: 30;
            color: Define.nocolor;
            Text {
                color: Define.textColor;
                id: playingListTitle;
                anchors.verticalCenter: parent.verticalCenter;
                text: "播放列表";
                font.pixelSize: 18;
                font.weight: 500;
            }
            Text {
                anchors {verticalCenter:parent.verticalCenter; left:playingListTitle.right; leftMargin:8;}
                text: "共 "+String(root.queue.length)+" 首";
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
                        color: Define.textColor;
                        anchors.centerIn: parent;
                        text: "清空列表";
                    }
                }
                onClicked: {
                    if(root.thePlayer!==null) {
                        root.thePlayer.clearList();
                    }
                }
            }
        }
        Rectangle {
            visible: root.headEnabled;
            width: parent.width-parent.padding*2;
            height: 2;
            radius: 1;
            color: Define.subGrey;
        }
    }
    Rectangle {
        id: playingListViewArea;
        anchors {left:parent.left; right:parent.right;}
        anchors.top: ((root.headEnabled||root.headBlank)? playingListHead.bottom:parent.top);
        anchors.bottom: parent.bottom;
        color: Define.nocolor;
        ListView {
            id: playingListView;
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
            /* 单行高度, 与委托保持一致 */
            property int rowHeight: 60;
            model: root.queue;
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
                    property bool playingRow: (root.playingKey===modelData["absfpath"]);
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
                            Assist.dlog("播放","单击: ",playingListView.selectedWhich);
                        }
                        onDoubleClicked: {
                            Assist.dlog("播放","双击: ",modelData["absfpath"]);
                            if(root.thePlayer===null || root.playingKey===modelData["absfpath"]) {
                                return;
                            }
                            root.thePlayer.playItem(modelData);
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
                                if(root.thePlayer===null || root.playingKey===modelData["absfpath"]) {
                                    return;
                                }
                                root.thePlayer.playItem(modelData);
                            }
                            background: Item {
                                anchors.fill: parent;
                                CoverImage {
                                    id: playingAvatarImage;
                                    cornerRadius: 10;
                                    anchors.fill: parent;
                                    /* 封面: 本地路径优先, 在线条目取曲库单例里的封面缓存, 都没有时回退应用图标;
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
                            visible: (root.playingKey!==modelData["absfpath"]);
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 12;
                            height: 12;
                            icon.source: "qrc:/assets/iconfont/function/close.svg";
                            icon.color: Define.btnIconColor;
                            transEnabled: false;
                            onClicked: {
                                if(root.thePlayer!==null) {
                                    root.thePlayer.removeItem(modelData);
                                }
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
                        playingListView.jump2playing();
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
            /* 定位到当前播放行: 选中它并滚到列表开头位置, 按钮与自动跟随共用 */
            function jump2playing() {
                if(root.playingIndex<0) {
                    return false;
                }
                selectedWhich=root.playingKey;
                positionViewAtIndex(root.playingIndex,ListView.Beginning);
                Assist.dlog("面板","定位到当前播放行: 下标 ",root.playingIndex);
                return true;
            }
            /* 当前播放行是否落在视域之外 */
            function playingOutOfView() {
                var idx=root.playingIndex;
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
    /* 播放状态变化时面板自动定位一次: 因此从歌曲列表点行播放或点"播放"按钮后, 面板已经停在当前播放项上;
     * 播放进度也会整体重写播放状态, 这里只在队列或当前项真的变化时才定位, 否则会把用户的手动滚动不断拉回 */
    property int _lastQueueLen: -1;
    property string _lastPlayingKey: "";
    Connections {
        target: GlobalFileStorage;
        function onPlayStateChanged() {
            var len=root.queue.length;
            var key=root.playingKey;
            var changed=((len!==root._lastQueueLen) || (key!==root._lastPlayingKey));
            root._lastQueueLen=len;
            root._lastPlayingKey=key;
            if(changed===true && root.autoFollow===true) {
                playingListView.jump2playing();
            }
        }
    }
}

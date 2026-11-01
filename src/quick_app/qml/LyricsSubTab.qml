import QtQuick
import "./"

import AppHelper 1.0

/* 全屏歌词页: 与 canvas 平级的整窗覆盖层, 圆角与边框沿用 canvas 的取值.
 * 左上角为退出入口, 右上角为窗口操控栏副本, 底部为与播放栏同源的播放条, 中部为歌词显示区.
 * 窗口, 播放器与播放栏都由主界面注入, 本页不引用主界面的任何控件 */
Rectangle {
    id: root;
    /* 注入: 被操控的窗口, 播放器, 播放栏 */
    property var theWindow: null;
    property var thePlayer: null;
    property var thePlayerBar: null;
    /* 歌词行: 每项形如 {t: 秒(无时间戳为 -1), text: 文本} */
    property var lyricLines: [];
    /* 当前播放位置对应的行下标, 无时间戳或未播放时为 -1 */
    property int currentLine: -1;
    topLeftRadius: Define.windowRadius;
    topRightRadius: Define.windowRadius;
    bottomLeftRadius: Define.windowRadius;
    bottomRightRadius: Define.windowRadius;
    border.width: 0.5;
    border.color: Define.windowBorderColor;
    color: Define.canvasColor;

    /* 拦截与拖动: 与 canvas 的拖动区同几何, 既拦住下层界面的点击, 又给窗口四边四角留出缩放区;
     * 判据与 canvas 一致, 落在 windowPadding 的内边距环内才开始拖动窗口 */
    MouseArea {
        id: pageDrag;
        anchors.fill: parent;
        anchors.margins: Define.edgeMouseAreaD;
        acceptedButtons: Qt.LeftButton|Qt.RightButton|Qt.MiddleButton;
        onPressed: (mouse)=> {
            if(mouse.button!==Qt.LeftButton) {
                return;
            }
            var mx=mouse.x;
            var my=mouse.y;
            var d=Define.windowPadding-Define.edgeMouseAreaD;
            if(mx<d || my<d || mx>(width-d) || my>(height-d)) {
                if(root.theWindow!==null) {
                    root.theWindow.startSystemMove();
                }
            }
        }
    }

    /* 左上角退出入口: 收起歌词页回到 canvas */
    CustomButtonA {
        id: closeLyricsBtn;
        anchors {left:parent.left; top:parent.top;}
        anchors.leftMargin: Define.windowPadding+controlBar.rowsTopMargin;
        anchors.topMargin: (Define.windowPadding+controlBar.rowsTopMargin
                           +(controlBar.rowsHeight-height)/2);
        icon.source: "qrc:/assets/iconfont/function/closedown.svg";
        onClicked: {
            root.hide();
        }
    }

    /* 右上角窗口操控栏: 与顶栏共用同一份实现, 两处副本操控同一个窗口 */
    WindowControlBar {
        id: controlBar;
        theWindow: root.theWindow;
        anchors {top:parent.top; right:parent.right;}
        anchors.topMargin: Define.windowPadding+rowsTopMargin;
        anchors.rightMargin: Define.windowPadding;
    }

    /* 封面大图: 放在左侧, 取当前播放项的封面, 没有时回退应用图标 */
    Rectangle {
        id: coverPanel;
        anchors {left:parent.left;}
        anchors.leftMargin: Define.windowPadding*6;
        anchors.verticalCenter: lyricArea.verticalCenter;
        width: (lyricArea.height*0.42);
        height: width;
        radius: Define.mainAreaRaduis*2;
        clip: true;
        color: Define.hoverDarkColor;
        Image {
            anchors.fill: parent;
            fillMode: Image.PreserveAspectCrop;
            source: root.coverSource;
        }
    }
    /* 歌词显示区: 封面右侧, 顶部操控栏与底部播放条之间 */
    Item {
        id: lyricArea;
        anchors {top:parent.top; bottom:playerBarSubone.top;}
        anchors.topMargin: Define.windowPadding+controlBar.rowsTopMargin+controlBar.rowsHeight+20;
        anchors.bottomMargin: 10;
        anchors.left: coverPanel.right;
        anchors.right: parent.right;
        anchors.leftMargin: 60;
        anchors.rightMargin: Define.windowPadding*6;
    }
    ListView {
        id: lyricView;
        anchors.fill: lyricArea;
        model: root.lyricLines;
        spacing: 12;
        clip: true;
        boundsBehavior: Flickable.StopAtBounds;
        delegate: Text {
            width: lyricView.width;
            horizontalAlignment: Text.AlignHCenter;
            wrapMode: Text.Wrap;
            text: (modelData===undefined || modelData===null? "":String(modelData["text"]));
            font.pixelSize: (index===root.currentLine? 22:16);
            font.bold: (index===root.currentLine);
            color: (index===root.currentLine? Define.btnIconColor:Define.forbdDarkColor);
        }
    }

    /* 底部播放条: 功能与播放栏等同, 状态绑定到播放栏, 改动一律经播放栏的命令下发 */
    Rectangle {
        id: playerBarSubone;
        anchors {left:parent.left; right:parent.right; bottom:parent.bottom;}
        anchors.leftMargin: Define.windowPadding;
        anchors.rightMargin: Define.windowPadding;
        anchors.bottomMargin: Define.windowPadding;
        height: 80;
        topLeftRadius: Define.mainAreaRaduis;
        topRightRadius: Define.mainAreaRaduis;
        bottomLeftRadius: Define.mainAreaRaduis;
        bottomRightRadius: Define.mainAreaRaduis;
        color: Define.mainAreaColor;
        /* 左侧: 封面缩略图, 曲名与歌手, 喜欢按钮 */
        Row {
            anchors {left:parent.left; verticalCenter:parent.verticalCenter;}
            leftPadding: 12;
            spacing: 10;
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter;
                width: 40;
                height: 40;
                radius: 5;
                clip: true;
                Image {
                    anchors.fill: parent;
                    fillMode: Image.PreserveAspectCrop;
                    source: root.coverSource;
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter;
                width: Define.playerTitleMaxWidth;
                elide: Text.ElideRight;
                text: (root.playingEntryData===null? "":String(root.playingEntryData["songname"]))
                      +(root.playingEntryData===null || root.playingEntryData["singer"]===""
                        ? "":(" - "+String(root.playingEntryData["singer"])));
                font.pixelSize: 14;
                color: Define.btnIconColor;
            }
            PlayerBarButton {
                anchors.verticalCenter: parent.verticalCenter;
                enabled: (root.thePlayerBar!==null && root.thePlayerBar.barLikeEnabled);
                property bool liked: (root.thePlayerBar!==null && root.thePlayerBar.barLiked);
                icon.source: (liked? "qrc:/assets/iconfont/function/liked.svg":"qrc:/assets/iconfont/function/like.svg");
                icon.color: (enabled===false? Define.forbdDarkColor:(liked? (hovered? Define.btnHoverRed:Define.btnIconRed):(hovered? Define.btnIconRed:Define.btnIconColor)));
                onClicked: {
                    if(root.thePlayerBar!==null) {
                        root.thePlayerBar.barToggleLike();
                    }
                }
            }
        }
        /* 中部: 上一曲, 播放暂停, 下一曲, 以及进度与两端时间 */
        Column {
            anchors {horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter;}
            spacing: 8;
            Row {
                anchors.horizontalCenter: parent.horizontalCenter;
                spacing: Define.btnSpacing;
                height: 20;
                PlayerBarButton {
                    icon.source: "qrc:/assets/iconfont/playerbar/lastone.svg";
                    onClicked: {
                        if(root.thePlayerBar!==null) {
                            root.thePlayerBar.barPrev();
                        }
                    }
                }
                PlayerBarButton {
                    id: subPlayPauseBtn;
                    property string svgBase: "qrc:/assets/iconfont/playerbar/";
                    property bool playing: (root.thePlayerBar!==null && root.thePlayerBar.barPlaying);
                    hoverEnabled: false;
                    transEnabled: false;
                    icon.source: svgBase+(playing? "pause.svg":"play.svg");
                    onClicked: {
                        if(root.thePlayerBar!==null) {
                            root.thePlayerBar.barTogglePlay();
                        }
                    }
                    background: Rectangle {
                        anchors.centerIn: parent;
                        width: parent.width+20;
                        height: parent.height+10;
                        color: Define.btnHoverColor;
                        radius: height/2;
                    }
                }
                PlayerBarButton {
                    icon.source: "qrc:/assets/iconfont/playerbar/nextone.svg";
                    onClicked: {
                        if(root.thePlayerBar!==null) {
                            root.thePlayerBar.barNext();
                        }
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter;
                spacing: 10;
                height: 20;
                Text {
                    anchors.verticalCenter: parent.verticalCenter;
                    text: Assist.int2mmss(subStampSlider.showedValue);
                }
                PlayerBarSliderA {
                    id: subStampSlider;
                    width: playerBarSubone.width*0.3;
                    anchors.verticalCenter: parent.verticalCenter;
                    maxStamp: (root.thePlayerBar===null? 0:root.thePlayerBar.barDuration);
                    property int showedValue: (pressed? value:(root.thePlayerBar===null? 0:root.thePlayerBar.barPosition));
                    onPressedChanged: {
                        if(!pressed && root.thePlayerBar!==null) {
                            root.thePlayerBar.barSeek(value);
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter;
                    text: Assist.int2mmss(subStampSlider.maxStamp);
                }
            }
        }
        /* 右侧: 静音, 音量与播放列表 */
        Row {
            anchors {right:parent.right; verticalCenter:parent.verticalCenter;}
            rightPadding: 12;
            spacing: 10;
            PlayerBarButton {
                anchors.verticalCenter: parent.verticalCenter;
                icon.source: ((root.thePlayerBar!==null && root.thePlayerBar.barVolume===0)
                              ? "qrc:/assets/iconfont/playerbar/soundless.svg"
                              : "qrc:/assets/iconfont/playerbar/sound.svg");
                onClicked: {
                    if(root.thePlayerBar!==null) {
                        root.thePlayerBar.barToggleMute();
                    }
                }
            }
            PlayerBarSliderA {
                id: subVolumeSlider;
                anchors.verticalCenter: parent.verticalCenter;
                width: 90;
                maxStamp: 100;
                value: (root.thePlayerBar===null? 0:root.thePlayerBar.barVolume);
                onPressedChanged: {
                    if(!pressed && root.thePlayerBar!==null) {
                        root.thePlayerBar.barSetVolume(value);
                        /* 拖动会打断绑定, 松手后按播放栏的音量重新接上 */
                        value=Qt.binding(function() {
                            return (root.thePlayerBar===null? 0:root.thePlayerBar.barVolume);
                        });
                    }
                }
            }
            PlayerBarButton {
                anchors.verticalCenter: parent.verticalCenter;
                icon.color: (((root.thePlayerBar!==null && root.thePlayerBar.barListVisible)
                             || (hovered&&hoverColorEnabled))? Define.btnHoverColor:Define.btnIconColor);
                icon.source: "qrc:/assets/iconfont/playerbar/playerlist.svg";
                onClicked: {
                    /* 播放列表面板属于主界面: 先收起歌词页, 再由播放栏打开面板 */
                    root.hide();
                    if(root.thePlayerBar!==null) {
                        root.thePlayerBar.barToggleList();
                    }
                }
            }
        }
    }

    /* 当前播放项的封面: 条目自带封面优先, 其次在线封面缓存, 都没有时回退应用图标 */
    readonly property var playingEntryData: ((thePlayer===null || typeof thePlayer.playingEntry!=="function")
                                             ? null:thePlayer.playingEntry());
    readonly property string playingLyricsName: ((playingEntryData===null
                                                  || playingEntryData["lyrics"]===undefined)
                                                 ? "":String(playingEntryData["lyrics"]));
    readonly property string coverSource: ((playingEntryData!==null && playingEntryData["absipath"])
                                           ? String(playingEntryData["absipath"])
                                           : coverOfEntry(playingEntryData));
    /* 按封面名取在线封面缓存, 没有缓存时回退应用图标 */
    function coverOfEntry(one) {
        var name=(one===null || one["cover"]===undefined? "":String(one["cover"]));
        if(name==="" || Server.coverCache[name]===undefined) {
            return "qrc:/favicon.jpg";
        }
        return String(Server.coverCache[name]);
    }
    /* 换歌时请求封面与歌词: 已缓存或本进程已失败时这两个请求直接返回 */
    onPlayingEntryDataChanged: {
        if(playingEntryData!==null) {
            var coverName=(playingEntryData["cover"]===undefined? "":String(playingEntryData["cover"]));
            if(coverName!=="") {
                Server.requestCover(coverName);
            }
        }
        root.syncLyrics();
    }
    function syncLyrics() {
        if(playingLyricsName==="") {
            lyricLines=[];
            currentLine=-1;
            return;
        }
        Server.requestLyrics(playingLyricsName);
        loadLyricText();
    }
    /* 读盘并解析歌词: 没有缓存时清空显示, 缓存就绪时由 lyricsUpdated 再次触发 */
    function loadLyricText() {
        if(playingLyricsName==="") {
            lyricLines=[];
            currentLine=-1;
            return false;
        }
        var path=Server.lyricsPathOf(playingLyricsName);
        if(path==="") {
            lyricLines=[];
            currentLine=-1;
            return false;
        }
        var text=AppFileHelper.readFile(path,"UTF-8");
        lyricLines=parseLyrics(text);
        syncCurrentLine();
        Assist.dlog("界面","歌词已载入: ",playingLyricsName,", 行数 ",lyricLines.length);
        return true;
    }
    /* 解析歌词文本: 取出每行的时间戳, 一行多个时间戳时拆成多条; 无时间戳的整行保留为普通文本 */
    function parseLyrics(text) {
        var out=[];
        if(typeof text!=="string" || text==="") {
            return out;
        }
        var tagRe=/\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g;
        var stripRe=/\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g;
        var rows=text.split(/\r?\n/);
        for(var i=0;i<rows.length;i++) {
            var line=String(rows[i]);
            var stamps=[];
            tagRe.lastIndex=0;
            var m=tagRe.exec(line);
            while(m!==null) {
                var mm=Number(m[1]);
                var ss=Number(m[2]);
                var frac=(m[3]===undefined? 0:Number("0."+m[3]));
                stamps.push(mm*60+ss+frac);
                m=tagRe.exec(line);
            }
            var body=line.replace(stripRe,"").trim();
            if(body==="") {
                continue;
            }
            if(stamps.length<=0) {
                out.push({"t":-1,"text":body});
                continue;
            }
            for(var j=0;j<stamps.length;j++) {
                out.push({"t":stamps[j],"text":body});
            }
        }
        /* 有带时间戳的行时: 带时间戳的按时间升序排在前, 无时间戳的按原顺序接在后面,
         * 这样按播放位置定位只需一次向前扫描, 夹在中间的说明行也不会打乱顺序 */
        var timed=[];
        var rest=[];
        for(var k=0;k<out.length;k++) {
            if(out[k]["t"]<0) {
                rest.push(out[k]);
            } else {
                timed.push(out[k]);
            }
        }
        if(timed.length>0) {
            timed.sort(function(a,b) { return (a["t"]-b["t"]); });
            out=timed.concat(rest);
        }
        return out;
    }
    /* 播放位置对应的行下标: 取最后一个时间戳不晚于当前秒数的行, 遇到无时间戳的行即停 */
    function lineIndexAt(sec) {
        var idx=-1;
        for(var i=0;i<lyricLines.length;i++) {
            var t=lyricLines[i]["t"];
            if(t<0) {
                break;
            }
            if(t>sec) {
                break;
            }
            idx=i;
        }
        return idx;
    }
    function syncCurrentLine() {
        if(thePlayerBar===null || lyricLines.length<=0) {
            currentLine=-1;
            return;
        }
        currentLine=lineIndexAt(thePlayerBar.barPosition);
    }
    /* 当前行变化时把该行滚到可视区中部 */
    onCurrentLineChanged: {
        if(currentLine>=0 && currentLine<lyricLines.length) {
            lyricView.positionViewAtIndex(currentLine,ListView.Center);
        }
    }
    Connections {
        target: root.thePlayerBar;
        function onBarPositionChanged() {
            if(!subStampSlider.pressed && root.thePlayerBar!==null) {
                subStampSlider.value=root.thePlayerBar.barPosition;
            }
            root.syncCurrentLine();
        }
    }
    Connections {
        target: Server;
        function onLyricsUpdated(lyricsName) {
            if(lyricsName===root.playingLyricsName) {
                root.loadLyricText();
            }
        }
    }
    /* 显示时同步一次播放条与歌词, 隐藏时只改可见性 */
    onVisibleChanged: {
        if(visible===true) {
            if(root.thePlayerBar!==null) {
                subStampSlider.value=root.thePlayerBar.barPosition;
            }
            root.syncLyrics();
        }
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
}

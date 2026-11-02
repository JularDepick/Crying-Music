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
    /* 注入: 内存枢纽(边播边下策略钩子)与侧栏展开状态(播放条按钮间距) */
    property var theMemStorage: null;
    property bool theSidebarSpreaded: true;
    /* 歌词行: 每项形如 {t: 秒(无时间戳为 -1), text: 文本} */
    property var lyricLines: [];
    /* 当前播放位置对应的行下标, 无时间戳或未播放时为 -1 */
    property int currentLine: -1;
    /* 当前行内已唱到的词下标: 只有增强歌词(elrc)带词级时间戳, 其它情况为 -1 */
    property int currentWord: -1;

    /* 控件可见性: 鼠标静止一段时间后淡出, 移动即恢复 */
    property bool chromeVisible: true;
    /* 锚定比例: 当前行固定在歌词视口高度的这个位置, 上下都能看到后续歌词 */
    readonly property real anchorRatio: 0.42;
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
            /* 收起子面板统一走 subsHide: 主界面在每次按下时把场景坐标传进来 */
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
        opacity: (root.chromeVisible? 1:0);
        enabled: root.chromeVisible;
        Behavior on opacity {
            NumberAnimation { duration: 150; }
        }
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
        opacity: (root.chromeVisible? 1:0);
        enabled: root.chromeVisible;
        Behavior on opacity {
            NumberAnimation { duration: 150; }
        }
        anchors {top:parent.top; right:parent.right;}
        anchors.topMargin: Define.windowPadding+controlBar.rowsTopMargin;
        anchors.rightMargin: Define.windowPadding;
    }

    /* 封面大图: 版面按参考图取宽 32%, 左起 17.1%, 顶起 26.1%, 高 46.5% */
    Rectangle {
        id: coverPanel;
        anchors {left:parent.left; top:parent.top;}
        anchors.leftMargin: root.width*0.171;
        anchors.topMargin: root.height*0.261;
        width: root.width*0.32;
        height: root.height*0.465;
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
        anchors.topMargin: root.height*0.227;
        anchors.bottomMargin: 20;
        anchors.left: parent.left;
        anchors.right: parent.right;
        anchors.leftMargin: root.width*0.576;
        anchors.rightMargin: root.width*0.176;
    }
    ListView {
        id: lyricView;
        anchors.fill: lyricArea;
        model: root.lyricLines;
        spacing: 12;
        clip: true;
        boundsBehavior: Flickable.StopAtBounds;
        /* 首尾留白: 让第一行与最后一行也能落到锚定线上, 否则 ListView 会把内容顶到边界 */
        header: Item {
            width: lyricView.width;
            height: lyricView.height*root.anchorRatio;
        }
        footer: Item {
            width: lyricView.width;
            height: lyricView.height*(1-root.anchorRatio);
        }
        /* 视口尺寸变化与用户拖动结束后都重新锚定一次 */
        onHeightChanged: Qt.callLater(root.anchorToCurrentLine);
        onMovementEnded: root.anchorToCurrentLine();
        delegate: Text {
            width: lyricView.width;
            horizontalAlignment: Text.AlignHCenter;
            wrapMode: Text.Wrap;
            /* 当前行且已唱到某个词时改用富文本, 已唱部分单独着色 */
            textFormat: (root.wordHighlightOn(index)? Text.StyledText:Text.PlainText);
            text: root.lineTextOf(index);
            font.pixelSize: (index===root.currentLine? root.currentFontSize:root.baseFontSize);
            font.bold: (index===root.currentLine);
            color: (index===root.currentLine? Define.btnIconColor:Define.forbdDarkColor);
        }
        /* 右键歌词区呼出调节菜单: 用 TapHandler, 不打断左键拖动与滚轮 */
        TapHandler {
            acceptedButtons: Qt.RightButton;
            onSingleTapped: (eventPoint)=> {
                var p=lyricView.mapToItem(root,eventPoint.position.x,eventPoint.position.y);
                root.openMenu(p.x,p.y);
            }
        }
    }

    /* 播放列表面板: 本页自己的一份实例, 内容与主界面共用同一份实现, 队列状态来自注入的播放器 */
    Rectangle {
        id: listPanel;
        anchors {top:parent.top; bottom:playerBarSubone.top; right:parent.right;}
        anchors.topMargin: Define.windowPadding+controlBar.rowsTopMargin+controlBar.rowsHeight+20;
        anchors.bottomMargin: 10;
        anchors.rightMargin: Define.windowPadding;
        width: 450;
        topLeftRadius: Define.mainAreaRaduis;
        topRightRadius: Define.mainAreaRaduis;
        bottomLeftRadius: Define.mainAreaRaduis;
        bottomRightRadius: Define.mainAreaRaduis;
        color: Define.mainAreaColor;
        border.color: Define.subGrey;
        border.width: 1;
        visible: playerBarSubone.listVisible;
        PlayingListViewArea {
            anchors.fill: parent;
            thePlayer: root.thePlayer;
            headEnabled: false;
            headBlank: true;
        }
    }
    /* 底部播放条: 与主界面播放栏共用同一份实现, 透明无外边距; 队列与播放状态的权威是注入的播放器 */
    PlayerBar {
        id: playerBarSubone;
        cardStyle: false;
        opacity: (root.chromeVisible? 1:0);
        enabled: root.chromeVisible;
        Behavior on opacity {
            NumberAnimation { duration: 150; }
        }
        thePlayer: root.thePlayer;
        theMemStorage: root.theMemStorage;
        sidebarSpreaded: root.theSidebarSpreaded;
        anchors {left:parent.left; right:parent.right; bottom:parent.bottom;}
        onLyricsOpenerClicked: {
            root.hide();
        }
        onVolumeMoved: (value)=> {
            if(root.theWindow!==null) {
                root.theWindow.outputVolume=value;
            }
        }
    }

    /* 歌词右键菜单: 字号与偏移调节; 点击菜单外或按 Esc 收起, 不用系统弹窗 */
    Rectangle {
        id: lyricMenu;
        visible: false;
        width: 250;
        height: menuColumn.implicitHeight+24;
        radius: Define.mainAreaRaduis;
        color: Define.mainAreaColor;
        border.color: Define.subGrey;
        border.width: 1;
        z: 10;
        /* 菜单自身的空白处也吃掉点击: 不穿透到下面的页面拖动区, 点空白处收起菜单 */
        MouseArea {
            anchors.fill: parent;
            onClicked: {
                root.closeMenu();
            }
        }
        Column {
            id: menuColumn;
            anchors {left:parent.left; right:parent.right; top:parent.top;}
            anchors.leftMargin: 12;
            anchors.rightMargin: 12;
            anchors.topMargin: 12;
            spacing: 10;
            Row {
                spacing: 8;
                Text {
                    width: 62;
                    text: "歌词字号";
                    font.pixelSize: 13;
                    anchors.verticalCenter: parent.verticalCenter;
                }
                CustomButtonA {
                    id: fontMinusBtn;
                    width: 26;
                    height: 24;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 12;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text { anchors.centerIn: parent; text: "-"; font.pixelSize: 13; }
                    }
                    onClicked: { root.adjustFontSize(-Define.lyricsFontSizeStep); }
                }
                Text {
                    width: 52;
                    text: root.baseFontSize+" px";
                    font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter;
                    anchors.verticalCenter: parent.verticalCenter;
                }
                CustomButtonA {
                    id: fontPlusBtn;
                    width: 26;
                    height: 24;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 12;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; }
                    }
                    onClicked: { root.adjustFontSize(Define.lyricsFontSizeStep); }
                }
            }
            Row {
                spacing: 8;
                Text {
                    width: 62;
                    text: "歌词偏移";
                    font.pixelSize: 13;
                    anchors.verticalCenter: parent.verticalCenter;
                }
                CustomButtonA {
                    id: offsetMinusBtn;
                    width: 26;
                    height: 24;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 12;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text { anchors.centerIn: parent; text: "-"; font.pixelSize: 13; }
                    }
                    onClicked: { root.adjustOffsetMs(-Define.lyricsOffsetStepMs); }
                }
                Text {
                    width: 66;
                    text: root.offsetText();
                    font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter;
                    anchors.verticalCenter: parent.verticalCenter;
                }
                CustomButtonA {
                    id: offsetPlusBtn;
                    width: 26;
                    height: 24;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 12;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; }
                    }
                    onClicked: { root.adjustOffsetMs(Define.lyricsOffsetStepMs); }
                }
            }
            Row {
                spacing: 8;
                CustomButtonA {
                    id: offsetResetBtn;
                    width: 70;
                    height: 24;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 12;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text { anchors.centerIn: parent; text: "偏移复位"; font.pixelSize: 12; }
                    }
                    onClicked: { root.resetOffsetMs(); }
                }
                Text {
                    text: (GlobalFileStorage.lyricsEnhanced()? "增强歌词(elrc)":"普通歌词(lrc)");
                    font.pixelSize: 12;
                    color: Define.btnIconColor;
                    anchors.verticalCenter: parent.verticalCenter;
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
    /* 实际使用的歌词名: 关闭歌词增强时为普通歌词, 开启时为增强歌词 */
    readonly property string activeLyricsName: Server.lyricsVariantName(playingLyricsName);
    /* 歌词字号: 取界面偏好, 当前行在字号基础上加固定差值 */
    readonly property int baseFontSize: GlobalFileStorage.lyricsFontSize();
    readonly property int currentFontSize: baseFontSize+Define.lyricsCurrentLineExtra;
    /* 当前歌词的偏移量(毫秒): 正值让歌词提前, 按歌词名落进歌词缓存的偏移索引 */
    readonly property int lyricsOffsetMs: (activeLyricsName===""? 0:Server.lyricsOffsetMs(activeLyricsName));
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
            currentWord=-1;
            return;
        }
        Server.requestLyrics(playingLyricsName);
        loadLyricText();
    }
    /* 歌词增强开关变化会换掉实际使用的歌词名: 页面可见时按新的一档重新同步 */
    onActiveLyricsNameChanged: {
        if(root.visible===true) {
            root.syncLyrics();
        }
    }
    /* 读盘并解析歌词: 没有缓存时清空显示, 缓存就绪时由 lyricsUpdated 再次触发 */
    function loadLyricText() {
        if(activeLyricsName==="") {
            lyricLines=[];
            currentLine=-1;
            currentWord=-1;
            return false;
        }
        var path=Server.lyricsPathOf(activeLyricsName);
        if(path==="") {
            lyricLines=[];
            currentLine=-1;
            currentWord=-1;
            return false;
        }
        var text=AppFileHelper.readFile(path,"UTF-8");
        lyricLines=parseLyrics(text);
        syncCurrentLine();
        /* 模型刚替换时列表还没完成布局, 延后一帧再锚定 */
        Qt.callLater(root.anchorToCurrentLine);
        Assist.dlog("界面","歌词已载入: ",activeLyricsName,", 行数 ",lyricLines.length);
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
            var body=parseWords(line.replace(stripRe,""));
            if(body["text"]==="") {
                continue;
            }
            if(stamps.length<=0) {
                out.push({"t":-1,"text":body["text"],"words":body["words"]});
                continue;
            }
            for(var j=0;j<stamps.length;j++) {
                out.push({"t":stamps[j],"text":body["text"],"words":body["words"]});
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
    /* 行号变化时重新锚定 */
    onCurrentLineChanged: anchorToCurrentLine();
    function syncCurrentLine() {
        if(thePlayerBar===null || lyricLines.length<=0) {
            currentLine=-1;
            currentWord=-1;
            return;
        }
        /* 偏移量正值让歌词提前: 用播放位置加偏移去匹配时间戳 */
        var sec=thePlayerBar.barPosition+lyricsOffsetMs/1000;
        currentLine=lineIndexAt(sec);
        currentWord=(currentLine<0? -1:wordIndexAt(lyricLines[currentLine],sec));
    }
    /* 流式歌词的节流提交: 每个节拍只提交一次最新文本, 避免逐块重建列表 */
    property string _partialText: "";
    function applyPartialLyrics(text) {
        _partialText=String(text);
        if(partialTimer.running!==true) {
            partialTimer.start();
        }
    }
    function commitPartialLyrics() {
        var t=_partialText;
        if(t==="") {
            return false;
        }
        var cut=t.lastIndexOf("\n");
        if(cut>0) {
            t=t.substring(0,cut);
        }
        var parsed=parseLyrics(t);
        if(parsed.length<=lyricLines.length) {
            return false;
        }
        lyricLines=parsed;
        syncCurrentLine();
        Qt.callLater(root.anchorToCurrentLine);
        Assist.dlog("界面","歌词流式显示: 已收到 ",parsed.length," 行");
        return true;
    }
    Timer {
        id: partialTimer;
        interval: 250;
        repeat: false;
        onTriggered: {
            root.commitPartialLyrics();
        }
    }
    /* 解析一行的词级时间戳: 增强歌词(elrc)在行内用 <mm:ss.xx> 标出每个词的起点,
     * 每个标记后到下一个标记前算一段词; 没有词级标记时 words 为空, 只保留整行文本 */
    function parseWords(text) {
        var raw=String(text);
        var wordRe=/<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>/g;
        var marks=[];
        var m=wordRe.exec(raw);
        while(m!==null) {
            marks.push({"start":m.index, "end":m.index+m[0].length,
                        "t":Number(m[1])*60+Number(m[2])+(m[3]===undefined? 0:Number("0."+m[3]))});
            m=wordRe.exec(raw);
        }
        if(marks.length<=0) {
            return ({"text":raw.trim(), "words":[]});
        }
        var head=raw.substring(0,marks[0]["start"]).trim();
        var words=[];
        var plain="";
        for(var i=0;i<marks.length;i++) {
            var from=marks[i]["end"];
            var to=(i+1<marks.length? marks[i+1]["start"]:raw.length);
            var seg=raw.substring(from,to);
            if(seg==="") {
                continue;
            }
            words.push({"t":marks[i]["t"], "text":seg});
            plain=plain+seg;
        }
        return ({"text":(head+plain).trim(), "words":words});
    }
    /* 行内已唱到的词下标: 取最后一个不晚于当前秒数的词; 没有词级时间戳时为 -1 */
    function wordIndexAt(line, sec) {
        var ws=(line===null || line===undefined? null:line["words"]);
        if(ws===null || ws===undefined || ws.length<=0) {
            return -1;
        }
        var idx=-1;
        for(var i=0;i<ws.length;i++) {
            if(ws[i]["t"]>sec) {
                break;
            }
            idx=i;
        }
        return idx;
    }
    /* 是否按逐字进度着色: 当前行且已经唱到某个词 */
    function wordHighlightOn(index) {
        return (index===root.currentLine && root.currentWord>=0);
    }
    /* 行文本: 非当前行给纯文本, 当前行把已唱部分与未唱部分分开着色 */
    function lineTextOf(index) {
        var one=(index>=0 && index<lyricLines.length? lyricLines[index]:null);
        if(one===null || one===undefined) {
            return "";
        }
        var plain=String(one["text"]);
        if(index!==root.currentLine || root.currentWord<0) {
            return plain;
        }
        var ws=one["words"];
        if(ws===undefined || ws===null || ws.length<=0) {
            return plain;
        }
        var sung=Assist.hexOf(Define.choseCyanColor);
        var res="";
        for(var i=0;i<ws.length;i++) {
            var t=String(ws[i]["text"]).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
            res=(i<=root.currentWord? res+"<font color=\""+sung+"\">"+t+"</font>":res+t);
        }
        return res;
    }
    /* 字号调节: 限制在设计常量的上下限内, 结果落盘为界面偏好 */
    function adjustFontSize(delta) {
        var next=root.baseFontSize+Number(delta);
        if(!(next>=Define.lyricsFontSizeMin && next<=Define.lyricsFontSizeMax)) {
            return false;
        }
        return GlobalFileStorage.setLyricsFontSize(next);
    }
    /* 偏移调节: 正值让歌词提前, 结果按歌词名落进歌词缓存的偏移索引 */
    function adjustOffsetMs(delta) {
        if(root.activeLyricsName==="") {
            return false;
        }
        var ok=Server.setLyricsOffsetMs(root.activeLyricsName,root.lyricsOffsetMs+Number(delta));
        root.syncCurrentLine();
        root.anchorToCurrentLine();
        return ok;
    }
    /* 偏移复位 */
    function resetOffsetMs() {
        if(root.activeLyricsName==="") {
            return false;
        }
        var ok=Server.setLyricsOffsetMs(root.activeLyricsName,0);
        root.syncCurrentLine();
        root.anchorToCurrentLine();
        return ok;
    }
    /* 偏移量的显示文本: 正值表示歌词提前 */
    function offsetText() {
        var ms=root.lyricsOffsetMs;
        var v=(Math.abs(ms)/1000).toFixed(1);
        return (ms>0? "+"+v+" 秒":(ms<0? "-"+v+" 秒":"0.0 秒"));
    }
    /* 鼠标在页面内移动即恢复控件并重新计时 */
    HoverHandler {
        id: pageHover;
        onPointChanged: root.bumpIdle();
    }
    /* 控件淡出计时: 页面可见时启动, 到点把控件淡出 */
    Timer {
        id: idleTimer;
        interval: 5000;
        repeat: false;
        onTriggered: {
            root.chromeVisible=false;
        }
    }
    function bumpIdle() {
        chromeVisible=true;
        idleTimer.restart();
    }
    /* Esc 退出歌词页 */
    Shortcut {
        sequence: "Esc";
        enabled: root.visible;
        onActivated: {
            /* 菜单开着时 Esc 只收菜单, 再按一次才退出歌词页 */
            if(root.closeMenu()!==true) {
                root.hide();
            }
        }
    }
    /* 把当前行钉到锚定线: 先按顶部对齐定位, 再上移一个锚定高度, 首尾由列表的首尾留白兜底;
     * 用户正在拖动时不抢占, 松手后由列表的 movementEnded 重新锚定 */
    function anchorToCurrentLine() {
        if(visible!==true || lyricView.moving===true) {
            return false;
        }
        if(currentLine<0 || currentLine>=lyricLines.length) {
            return false;
        }
        lyricView.positionViewAtIndex(currentLine,ListView.Beginning);
        var maxY=Math.max(0,lyricView.contentHeight-lyricView.height);
        lyricView.contentY=Math.max(0,Math.min(maxY,lyricView.contentY-lyricView.height*anchorRatio));
        return true;
    }
    Connections {
        target: root.thePlayerBar;
        function onBarPositionChanged() {
            root.syncCurrentLine();
        }
    }
    Connections {
        target: Server;
        /* 边下边显: 服务端把已收到的部分文本发过来, 这里只取完整行, 末尾半行丢弃 */
        function onLyricsPartial(lyricsName,text) {
            if(lyricsName!==root.activeLyricsName) {
                return;
            }
            root.applyPartialLyrics(text);
        }
        function onLyricsUpdated(lyricsName) {
            if(lyricsName===root.activeLyricsName) {
                root.loadLyricText();
            }
        }
    }
    /* 显示时同步一次播放条与歌词, 隐藏时只改可见性 */
    onVisibleChanged: {
        if(visible===true) {
            root.syncLyrics();
            Qt.callLater(root.anchorToCurrentLine);
            root.bumpIdle();
        } else {
            idleTimer.stop();
            root.chromeVisible=true;
        }
    }
    function show() {
        visible=true;
    }
    function hide() {
        root.closeMenu();
        playerBarSubone.sub_hideList();
        visible=false;
    }
    function tshow() {
        visible=!visible;
    }
    /* 右键菜单: 定位到点击处并夹在页面内 */
    function openMenu(x,y) {
        var w=lyricMenu.width;
        var h=lyricMenu.height;
        var mx=Math.max(Define.windowPadding,Math.min(Number(x),root.width-w-Define.windowPadding));
        var my=Math.max(Define.windowPadding,Math.min(Number(y),root.height-h-Define.windowPadding));
        lyricMenu.x=mx;
        lyricMenu.y=my;
        lyricMenu.visible=true;
        Assist.dlog("界面","歌词菜单: 打开");
        return true;
    }
    /* 收起右键菜单: 未打开时返回 false */
    function closeMenu() {
        if(lyricMenu.visible!==true) {
            return false;
        }
        lyricMenu.visible=false;
        Assist.dlog("界面","歌词菜单: 收起");
        return true;
    }
    /* 点击传播: 点击落在歌词页时收起本页的右键菜单与该页播放条的子面板,
     * 播放列表面板按落点判断, 与 canvas 层的口径一致 */
    function subsHide(scenePos) {
        var closed=root.closeMenu();
        playerBarSubone.subsHide(scenePos);
        if(playerBarSubone.listVisible===true && Assist.hitItem(listPanel,scenePos)!==true
           && playerBarSubone.hitsListOpener(scenePos)!==true) {
            playerBarSubone.sub_hideList();
        }
        return closed;
    }
}

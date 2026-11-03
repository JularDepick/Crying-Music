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
    /* 歌词增强开关: 关闭时用普通歌词且不做逐字着色, 开启时才按增强歌词显示逐字进度 */
    readonly property bool enhancedOn: GlobalFileStorage.lyricsEnhanced();
    /* 当前词的着色进度 0 到 1: 在两次播放位置上报之间按真实时间外推, 只用来决定字符级分界落在哪,
     * 颜色本身不插值, 已唱与未唱各是一档纯色 */
    property real wordProgress: 0;
    /* 用户手动把歌词滚离当前行: 为真时播放换行不强制锚定, 由复位计时器在 3 秒后拉回 */
    property bool userScrolled: false;
    /* 平滑插值的锚点: 播放器每次上报位置时刷新, 节拍按真实时间外推 */
    property real _animSec: 0;
    property real _animBaseSec: 0;
    property double _animAnchorMs: 0;

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
        CoverImage {
            anchors.fill: parent;
            cornerRadius: Define.mainAreaRaduis*2;
            outlineWidth: 0;
            source: root.coverSource;
        }
    }
    /* 歌词显示区: 封面右侧, 顶部操控栏与底部播放条之间;
     * 列宽由参考图的 24.8% 增至 31%(1.25 倍), 左右一起外扩,
     * 水平中轴线仍在窗口宽的 70% 处 */
    Item {
        id: lyricArea;
        anchors {top:parent.top; bottom:playerBarSubone.top;}
        anchors.topMargin: root.height*0.227;
        anchors.bottomMargin: 20;
        anchors.left: parent.left;
        anchors.right: parent.right;
        anchors.leftMargin: root.width*0.545;
        anchors.rightMargin: root.width*0.145;
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
        /* 视口尺寸变化后重新锚定一次; 用户拖动时不打断, 滚离当前行则 3 秒后拉回 */
        onHeightChanged: Qt.callLater(root.anchorToCurrentLine);
        onMovementStarted: {
            root.userScrolled=true;
            reanchorTimer.stop();
        }
        onMovementEnded: {
            if(root.isAnchoredAtCurrent()===true) {
                root.userScrolled=false;
                reanchorTimer.stop();
            } else {
                root.userScrolled=true;
                reanchorTimer.restart();
            }
        }
        delegate: Text {
            width: lyricView.width;
            horizontalAlignment: Text.AlignHCenter;
            wrapMode: Text.Wrap;
            /* 文本与格式取自同一份渲染结果, 不会出现文本带标签而格式仍是纯文本的错配 */
            readonly property var lineRender: root.renderOf(index);
            textFormat: (lineRender["styled"]===true? Text.StyledText:Text.PlainText);
            text: lineRender["text"];
            font.pixelSize: (index===root.currentLine? root.currentFontSize:root.baseFontSize);
            font.bold: (index===root.currentLine);
            color: (index===root.currentLine? Define.btnIconColor:Define.forbdDarkColor);
            /* 双击某行歌词: 把播放进度跳到这一行的起始时刻 */
            TapHandler {
                acceptedButtons: Qt.LeftButton;
                onDoubleTapped: (eventPoint)=> {
                    root.seekToLine(index);
                }
            }
        }
        /* 右键歌词区呼出调节菜单: 用 TapHandler, 不打断左键拖动与滚轮 */
        TapHandler {
            acceptedButtons: Qt.RightButton;
            onSingleTapped: (eventPoint)=> {
                /* 用场景坐标换算到页内坐标: 与点击收起的命中判定同一口径,
                 * 不受歌词列表滚动与页内偏移影响 */
                var sp=eventPoint.scenePosition;
                var p=root.mapFromItem(null,sp.x,sp.y);
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
    /* 底部播放条: 与主界面播放栏共用同一份实现, 透明无卡片底, 左右与底部各留 windowPadding 的外边距;
     * 队列与播放状态的权威是注入的播放器 */
    PlayerBar {
        id: playerBarSubone;
        cardStyle: false;
        /* 歌词页里这枚封面按钮的作用是退出歌词页, 悬停图标用关闭图形 */
        lyricsCloseIcon: true;
        opacity: (root.chromeVisible? 1:0);
        enabled: root.chromeVisible;
        Behavior on opacity {
            NumberAnimation { duration: 150; }
        }
        thePlayer: root.thePlayer;
        theMemStorage: root.theMemStorage;
        sidebarSpreaded: root.theSidebarSpreaded;
        anchors {left:parent.left; right:parent.right; bottom:parent.bottom;}
        anchors.leftMargin: Define.windowPadding;
        anchors.rightMargin: Define.windowPadding;
        anchors.bottomMargin: Define.windowPadding;
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
                    color: Define.textColor;
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
                        Text { anchors.centerIn: parent; text: "-"; font.pixelSize: 13; color: Define.textColor; }
                    }
                    onClicked: { root.adjustFontSize(-Define.lyricsFontSizeStep); }
                }
                Text {
                    color: Define.textColor;
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
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; color: Define.textColor; }
                    }
                    onClicked: { root.adjustFontSize(Define.lyricsFontSizeStep); }
                }
            }
            Row {
                spacing: 8;
                Text {
                    color: Define.textColor;
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
                        Text { anchors.centerIn: parent; text: "-"; font.pixelSize: 13; color: Define.textColor; }
                    }
                    onClicked: { root.adjustOffsetMs(-Define.lyricsOffsetStepMs); }
                }
                Text {
                    color: Define.textColor;
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
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; color: Define.textColor; }
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
        root.userScrolled=false;
        reanchorTimer.stop();
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
    /* 增强开关本身也决定是否解析逐字信息: 开关一变就按新口径重解析一次 */
    onEnhancedOnChanged: {
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
            /* 元信息标签行(ti/ar/al/by/offset 等)不是歌词: 整行的这类标签一律剥掉, 剥完为空就跳过 */
            var line=String(rows[i]).replace(/\[[A-Za-z_]+:[^\]]*\]/g,"");
            if(line.trim()==="") {
                continue;
            }
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
            /* 增强关闭时只保留纯文本: 词级标记已经从文本里剥掉, 也不再保留逐字信息 */
            var words=(root.enhancedOn===true? body["words"]:[]);
            if(stamps.length<=0) {
                out.push({"t":-1,"text":body["text"],"words":words});
                continue;
            }
            for(var j=0;j<stamps.length;j++) {
                out.push({"t":stamps[j],"text":body["text"],"words":words});
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
    /* 行号变化时重新锚定; 用户已经把歌词滚离当前行时不抢他的滚动位置 */
    onCurrentLineChanged: {
        if(root.userScrolled!==true) {
            root.anchorToCurrentLine();
        }
    }
    function syncCurrentLine() {
        if(thePlayerBar===null || lyricLines.length<=0) {
            currentLine=-1;
            currentWord=-1;
            return;
        }
        /* 偏移量正值让歌词提前: 用播放位置加偏移去匹配时间戳; 位置取小数秒, 逐字进度才有足够精度 */
        var sec=thePlayerBar.positionSec+lyricsOffsetMs/1000;
        var idx=lineIndexAt(sec);
        /* 边界: 播放位置还没到第一行的时间戳时, 先把第一行当作当前行锚定住;
         * 最后一行播完之后固定停在最后一个有时间戳的行, 歌词侧不再换行, 也不干预播放 */
        if(idx<0 && Number(lyricLines[0]["t"])>=0) {
            idx=0;
        }
        currentLine=idx;
        currentWord=(currentLine<0? -1:wordIndexAt(lyricLines[currentLine],sec));
        root.rebaseAnim(sec);
        root.wordProgress=root.wordProgressAt(sec);
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
    /* 行渲染: 一次算出这一行要显示的文本与是否按富文本渲染, 供委托同时取用;
     * 只有增强开启, 当前行且已经唱到某个词时才拼富文本;
     * 着色不做渐变: 已唱的词整段取高亮色, 正在唱的词按进度切成已唱与未唱两段,
     * 切点随进度连续前移, 两段各只有一档颜色 */
    function renderOf(index) {
        var one=(index>=0 && index<lyricLines.length? lyricLines[index]:null);
        if(one===null || one===undefined) {
            return ({"text":"", "styled":false});
        }
        var plain=String(one["text"]);
        if(root.enhancedOn!==true || index!==root.currentLine || root.currentWord<0) {
            return ({"text":plain, "styled":false});
        }
        var ws=one["words"];
        if(ws===undefined || ws===null || ws.length<=0) {
            return ({"text":plain, "styled":false});
        }
        var res="";
        for(var i=0;i<ws.length;i++) {
            var seg=String(ws[i]["text"]);
            if(i<root.currentWord) {
                res=res+root.sungMarkup(seg);
                continue;
            }
            if(i>root.currentWord) {
                res=res+root.escapeMarkup(seg);
                continue;
            }
            res=res+root.splitMarkup(seg,root.wordProgress);
        }
        return ({"text":res, "styled":true});
    }
    /* 富文本转义: 只处理会破坏标签的三个字符 */
    function escapeMarkup(text) {
        return String(text).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
    }
    /* 已唱整段: 一律取高亮色, 唱完的词不再残留中间色 */
    function sungMarkup(text) {
        var t=root.escapeMarkup(text);
        if(t==="") {
            return t;
        }
        return "<font color=\""+Assist.hexOf(Define.choseCyanColor)+"\">"+t+"</font>";
    }
    /* 正在唱的词: 按进度把字符切成已唱与未唱两段, 切点按字符数取整,
     * 因此分界随进度连续前移, 两侧各只有一档颜色, 不做渐变 */
    function splitMarkup(text,f) {
        var src=String(text);
        var total=0;
        var p=0;
        while(p<src.length) {
            total=total+1;
            p=p+((src.charCodeAt(p)>=0xD800 && src.charCodeAt(p)<=0xDBFF)? 2:1);
        }
        if(total<=0) {
            return "";
        }
        var k=(f<0? 0:(f>1? 1:f));
        var sung=Math.floor(total*k);
        if(sung<=0) {
            return root.escapeMarkup(src);
        }
        if(sung>=total) {
            return root.sungMarkup(src);
        }
        var head="";
        var tail="";
        var n=0;
        var i=0;
        while(i<src.length) {
            var step=((src.charCodeAt(i)>=0xD800 && src.charCodeAt(i)<=0xDBFF)? 2:1);
            var piece=src.substring(i,i+step);
            if(n<sung) {
                head=head+piece;
            } else {
                tail=tail+piece;
            }
            n=n+1;
            i=i+step;
        }
        return root.sungMarkup(head)+root.escapeMarkup(tail);
    }
    /* 刷新平滑插值的锚点: 播放器每次上报位置时调用 */
    function rebaseAnim(sec) {
        root._animBaseSec=Number(sec);
        root._animAnchorMs=Date.now();
        root._animSec=root._animBaseSec;
    }
    /* 当前词的着色比例: 词起点到下一个词起点之间线性插值, 末词用固定时长兜底 */
    function wordProgressAt(sec) {
        if(root.enhancedOn!==true || root.currentLine<0 || root.currentLine>=lyricLines.length
           || root.currentWord<0) {
            return 0;
        }
        var one=lyricLines[root.currentLine];
        var ws=one["words"];
        if(ws===undefined || ws===null || ws.length<=0 || root.currentWord>=ws.length) {
            return 0;
        }
        var t0=Number(ws[root.currentWord]["t"]);
        var t1=(t0+1.0);
        if(root.currentWord+1<ws.length) {
            t1=Number(ws[root.currentWord+1]["t"]);
        } else if(root.currentLine+1<lyricLines.length
                  && Number(lyricLines[root.currentLine+1]["t"])>t0) {
            t1=Number(lyricLines[root.currentLine+1]["t"]);
        }
        var span=Math.max(0.12,t1-t0);
        var f=(sec-t0)/span;
        if(f<0) {
            f=0;
        }
        if(f>1) {
            f=1;
        }
        /* 量化到 1/24, 避免每个节拍都产出新的富文本 */
        return Math.round(f*24)/24;
    }
    /* 平滑节拍: 按真实时间外推播放位置, 再算出当前词的着色比例 */
    function tickWordProgress() {
        var sec=root._animBaseSec+(Date.now()-root._animAnchorMs)/1000;
        root._animSec=sec;
        var f=root.wordProgressAt(sec);
        if(root.wordProgress!==f) {
            root.wordProgress=f;
        }
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
    /* 当前行是否已经落在锚定线上: 用来判断用户是否把歌词滚离了当前行 */
    function isAnchoredAtCurrent() {
        if(root.currentLine<0 || root.currentLine>=lyricLines.length) {
            return false;
        }
        var it=lyricView.itemAtIndex(root.currentLine);
        if(it===null || it===undefined) {
            return false;
        }
        var target=lyricView.height*root.anchorRatio;
        return (Math.abs(it.y-target)<=Math.max(6,it.height*0.5));
    }
    /* 双击某行歌词: 把播放进度跳到这一行的起始时刻, 按偏移量换算回真实播放位置 */
    function seekToLine(index) {
        if(index<0 || index>=lyricLines.length) {
            return false;
        }
        if(root.thePlayer===null) {
            return false;
        }
        var t=Number(lyricLines[index]["t"]);
        if(!(t>=0)) {
            Assist.dwarn("界面","歌词行没有时间戳, 不能跳转: 第 ",index," 行");
            return false;
        }
        var sec=Math.max(0,t-root.lyricsOffsetMs/1000);
        Assist.dlog("界面","歌词跳转: 第 ",index," 行, 位置 ",sec," 秒");
        root.thePlayer.position=Math.floor(sec*1000);
        root.userScrolled=false;
        reanchorTimer.stop();
        root.syncCurrentLine();
        root.anchorToCurrentLine();
        return true;
    }
    /* 逐字进度的平滑节拍: 只在增强歌词与当前行就绪且正在播放时跑 */
    Timer {
        id: wordTimer;
        interval: 33;
        repeat: true;
        running: (root.visible===true && root.enhancedOn===true && root.currentLine>=0
                  && root.currentWord>=0 && root.thePlayerBar!==null
                  && root.thePlayerBar.playing===true);
        onTriggered: {
            root.tickWordProgress();
        }
    }
    /* 用户把歌词滚离当前行后的复位计时: 3 秒内没有再滚动就拉回当前行 */
    Timer {
        id: reanchorTimer;
        interval: 3000;
        repeat: false;
        onTriggered: {
            root.userScrolled=false;
            root.anchorToCurrentLine();
        }
    }
    Connections {
        target: root.thePlayerBar;
        function onPositionSecChanged() {
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
    /* 右键菜单: 定位到点击处; 右下空间不够时改为向左上展开, 最后再夹在页面内,
     * 保证菜单始终贴着鼠标而不被推到页面另一侧 */
    function openMenu(x,y) {
        var w=lyricMenu.width;
        var h=lyricMenu.height;
        var pad=Define.windowPadding;
        var px=Number(x);
        var py=Number(y);
        if(isNaN(px) || isNaN(py)) {
            return false;
        }
        var mx=(px+w+pad>root.width? px-w:px);
        var my=(py+h+pad>root.height? py-h:py);
        mx=Math.max(pad,Math.min(mx,root.width-w-pad));
        my=Math.max(pad,Math.min(my,root.height-h-pad));
        lyricMenu.x=mx;
        lyricMenu.y=my;
        lyricMenu.visible=true;
        Assist.dlog("界面","歌词菜单: 打开 ",mx,",",my);
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
        /* 主界面在每次按下时都会分发一次: 落在菜单内不收起, 否则菜单里的控件点不动 */
        var closed=false;
        if(Assist.hitItem(lyricMenu,scenePos)!==true) {
            closed=root.closeMenu();
        }
        playerBarSubone.subsHide(scenePos);
        if(playerBarSubone.listVisible===true && Assist.hitItem(listPanel,scenePos)!==true
           && playerBarSubone.hitsListOpener(scenePos)!==true) {
            playerBarSubone.sub_hideList();
        }
        return closed;
    }
}

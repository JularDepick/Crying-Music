import QtQuick
import QtQuick.Effects
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
    /* 当前词的推进比例 0 到 1: 在两次播放位置上报之间按真实时间外推,
     * 用来决定已唱区域的右边界落在字内的哪个像素位置; 两侧各是一档纯色, 边界内不做颜色过渡 */
    property real wordProgress: 0;
    /* 用户手动把歌词滚离当前行: 为真时播放换行不强制锚定, 由复位计时器在 3 秒后拉回 */
    property bool userScrolled: false;
    /* 平滑插值的锚点: 播放器每次上报位置时刷新, 节拍按真实时间外推 */
    property real _animBaseSec: 0;
    property double _animAnchorMs: 0;
    /* 上一次锚定后的内容偏移: 与当前偏移相比即可判断用户是否把歌词滚离了基准高度 */
    property real _anchorContentY: 0;
    /* 上一行因断行口径不一致而放弃着色的行号: 只用来避免重复输出同一行日志 */
    property int _maskFallbackLine: -1;

    /* 底部播放条的可见性: 指针落在播放条或它展开的弹层上时保持常显, 离开这一片 3 秒没回来就淡出;
     * 弹层展开或滑块被按住期间处于锁定态, 不进入隐藏计时 */
    property bool barVisible: true;
    /* 指针是否还落在本页内: 离开页面后不再拿最后一次移动的坐标做热区几何判定 */
    property bool _pointerInPage: false;
    property real _pointerX: 0;
    property real _pointerY: 0;
    /* 锚定比例: 当前行固定在歌词视口高度的这个位置, 默认与封面从上往下 1/3 处对齐;
     * 用户在右键菜单里改过的比例来自界面偏好, 未设置时回落到设计默认值 */
    readonly property real anchorRatio: (GlobalFileStorage.lyricsAnchorRatio()>0
                                         ? GlobalFileStorage.lyricsAnchorRatio():(1.0/3.0));
    /* 当前行颜色: 界面偏好里设置过就用它, 否则用主题的图标色;
     * 已唱层仍用主题的选中色, 两层颜色互不影响 */
    readonly property color currentLineColor: (GlobalFileStorage.lyricsTextColor()!==""
                                               ? GlobalFileStorage.lyricsTextColor():Define.btnIconColor);
    /* 封面边长: 封面取正方形, 边长 32% 窗口宽; 过宽的窗口按可用高度收一档, 避免压到播放条 */
    readonly property real coverSide: Math.min(root.width*0.32, root.height*0.6);
    /* 基准高度范围的度量: 单独一份, 只跟歌词字号绑定, 不与逐字测量的共享对象互相触发 */
    FontMetrics {
        id: bandFontMetrics;
        font.pixelSize: root.baseFontSize;
        font.bold: false;
    }
    /* 基准高度范围: 高度取歌词行高, 因此"范围内"等价于这一行正好嵌在基准位置上, 随字号变化 */
    readonly property real anchorBandHeight: bandFontMetrics.height;
    /* 基准范围的容错: 不超过本身高度的十分之一 */
    readonly property real anchorBandTol: Math.max(1,root.anchorBandHeight*0.1);
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
        anchors.topMargin: Define.windowPadding+controlBar.rowsTopMargin;
        anchors.rightMargin: Define.windowPadding;
    }

    /* 封面大图: 取正方形, 位置与边长直接给出(不用锚点), 左起 17.1%, 顶起 26.1% */
    Rectangle {
        id: coverPanel;
        x: root.width*0.171;
        y: root.height*0.261;
        width: root.coverSide;
        height: root.coverSide;
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
    /* 歌词列: 上下边界与封面同顶同底, 高度与位置直接给出(不用锚点);
     * 宽度为窗口宽的 24.8%(原 31% 的 80%), 水平中轴线仍在窗口宽的 70% 处,
     * 因此左起 57.6%(0.7 减半个宽度), 歌词文字的换行与逐字断行都随之变窄 */
    Item {
        id: lyricArea;
        x: root.width*0.576;
        y: coverPanel.y;
        width: root.width*0.248;
        height: coverPanel.height;
    }
    /* 歌词列上方的两行: 曲名在前, 歌手在后, 水平居中且最大宽度与歌词列同宽 */
    Column {
        id: lyricHead;
        anchors {bottom:lyricArea.top; bottomMargin: 14;}
        x: lyricArea.x;
        width: lyricArea.width;
        spacing: 6;
        /* 曲名: 超出歌词列宽度时按播放栏那套循环轮播, 未超出时水平居中;
         * 宽度固定为歌词列宽度, 超出部分靠视口裁剪, 因此不会再出现省略号 */
        Item {
            id: songTitleViewport;
            width: parent.width;
            height: songTitleText.height;
            clip: true;
            readonly property bool overflowing: (songTitleText.implicitWidth>width);
            /* 轮播的横向位置: 未超出时不用它, 超出时由下面的动画推进 */
            property real scrollX: 0;
            Text {
                id: songTitleText;
                x: (songTitleViewport.overflowing
                    ? songTitleViewport.scrollX
                    : (songTitleViewport.width-implicitWidth)/2);
                text: root.playingSongName;
                color: Define.textColor;
                /* 原 22 的 1.25 倍: 字号按整数像素生效, 取四舍五入的 28 */
                font.pixelSize: 28;
                font.weight: 600;
                wrapMode: Text.NoWrap;
                /* 换歌或换文本时回到开头, 避免停在上一次的滚动位置 */
                onTextChanged: {
                    songTitleViewport.scrollX=0;
                }
                /* 轮播: 开头停 1 秒, 滚到文本末尾, 末尾停 1 秒, 再滚回开头, 如此往复 */
                SequentialAnimation {
                    running: songTitleViewport.overflowing;
                    loops: Animation.Infinite;
                    PauseAnimation {
                        duration: 1000;
                    }
                    NumberAnimation {
                        target: songTitleViewport;
                        property: "scrollX";
                        from: 0;
                        to: -(songTitleText.implicitWidth-songTitleViewport.width);
                        duration: Math.max(1200,(songTitleText.implicitWidth-songTitleViewport.width)*30);
                    }
                    PauseAnimation {
                        duration: 1000;
                    }
                    NumberAnimation {
                        target: songTitleViewport;
                        property: "scrollX";
                        from: -(songTitleText.implicitWidth-songTitleViewport.width);
                        to: 0;
                        duration: Math.max(1200,(songTitleText.implicitWidth-songTitleViewport.width)*30);
                    }
                    PauseAnimation {
                        duration: 1000;
                    }
                }
            }
        }
        /* 歌手: 仍按单行省略; 原 13 的 1.5 倍取四舍五入的 20, 字号按整数像素生效 */
        Text {
            width: parent.width;
            horizontalAlignment: Text.AlignHCenter;
            text: root.playingSingerName;
            color: Define.btnIconColor;
            font.pixelSize: 20;
            elide: Text.ElideRight;
            maximumLineCount: 1;
        }
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
        delegate: Item {
            width: lyricView.width;
            height: lineText.implicitHeight;
            /* 底色层: 整行按未唱色画一遍 */
            Text {
                id: lineText;
                width: parent.width;
                horizontalAlignment: Text.AlignHCenter;
                wrapMode: Text.Wrap;
                text: String(modelData["text"]);
                /* 全部歌词行同一字号与同一字重: 当前行只用颜色区分, 不放大也不加粗 */
                font.pixelSize: root.baseFontSize;
                font.bold: false;
                color: (index===root.currentLine? root.currentLineColor:Define.forbdDarkColor);
            }
            /* 已唱层: 同一份文本, 同一套排版, 只换颜色; 露出多少由遮罩按像素决定,
             * 因此边界可以停在字的中间而不是整字跳变 */
            Text {
                id: sungText;
                anchors.fill: lineText;
                horizontalAlignment: lineText.horizontalAlignment;
                wrapMode: lineText.wrapMode;
                text: lineText.text;
                font: lineText.font;
                color: Define.choseCyanColor;
                visible: (maskGeom["ready"]===true);
                layer.enabled: visible;
                layer.effect: MultiEffect {
                    maskEnabled: true;
                    maskSource: sungMask;
                }
            }
            /* 遮罩: 当前行之前的可视行整块铺白, 当前行只铺到边界, 其余透明;
             * 遮罩不可见, 只作为纹理供 MultiEffect 取用 */
            Item {
                id: sungMask;
                anchors.fill: lineText;
                visible: false;
                layer.enabled: true;
                Rectangle {
                    color: "white";
                    x: 0;
                    y: 0;
                    width: sungMask.width;
                    height: (maskGeom["ready"]===true? maskGeom["top"]:0);
                }
                Rectangle {
                    color: "white";
                    x: 0;
                    y: (maskGeom["ready"]===true? maskGeom["top"]:0);
                    width: (maskGeom["ready"]===true? maskGeom["width"]:0);
                    height: (maskGeom["ready"]===true? maskGeom["row"]:0);
                }
            }
            /* 可视行布局: 只有当前行需要, 断行与字宽在文本, 字号或列宽变化时重算, 进度变化不触发重排 */
            readonly property var sungLayout: (index===root.currentLine
                                               ? root.sungLayoutOf(lineText.text,lineText.font.pixelSize,
                                                                   lineText.font.bold,lineText.width):null);
            /* 遮罩几何: 随进度变化的只有当前行的右边界, 其它行直接不参与 */
            readonly property var maskGeom: (index===root.currentLine
                                             ? root.sungMaskOf(sungLayout,modelData,lineText.lineCount)
                                             : ({"ready":false,"top":0,"width":0,"row":0}));
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

    /* 基准高度处的跳转按钮: 圆钮加右侧时间, 纵向固定在基准高度上, 不随歌词滚动;
     * 横向放在歌词列的左侧并与之邻接(右边缘贴住歌词列左边缘), 不压住歌词文字;
     * 只在当前行被滚离基准高度范围时出现, 点击把进度跳到基准线对准的那一行 */
    Row {
        id: seekAnchorRow;
        x: (lyricArea.x-width);
        y: (lyricArea.y+lyricArea.height*root.anchorRatio-height/2);
        height: 32;
        spacing: 8;
        visible: root.seekAnchorReady();
        CustomButtonA {
            id: seekAnchorBtn;
            width: 32;
            height: 32;
            transEnabled: false;
            icon.source: "qrc:/assets/iconfont/playerbar/play.svg";
            icon.width: 14;
            icon.height: 14;
            background: Rectangle {
                anchors.fill: parent;
                radius: width/2;
                color: (parent.hovered? Define.choseCyanColor:Define.hoverDarkColor);
                border.color: Define.subGrey;
                border.width: 1;
            }
            onClicked: {
                root.seekToLine(root.anchorSeekLineIndex());
            }
        }
        Text {
            id: seekAnchorTime;
            anchors.verticalCenter: parent.verticalCenter;
            text: root.seekAnchorTimeText();
            color: Define.btnIconColor;
            font.pixelSize: 12;
        }
    }

    /* 播放列表面板: 本页自己的一份实例, 内容与主界面共用同一份实现, 队列状态来自注入的播放器;
     * 面板顶到窗口上沿, 因此打开时遮住右上角的窗口操控栏 */
    Rectangle {
        id: listPanel;
        anchors {top:parent.top; bottom:playerBarSubone.top; right:parent.right;}
        anchors.topMargin: Define.windowPadding;
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
        /* 收起时复位面板里清空按钮的确认态: 可见性切换发生在这层外壳上, 子项自身恒可见 */
        onVisibleChanged: {
            if(visible!==true) {
                listPanelView.resetClearButton();
            }
        }
        PlayingListViewArea {
            id: listPanelView;
            anchors.fill: parent;
            thePlayer: root.thePlayer;
            theMemStorage: root.theMemStorage;
            headEnabled: true;
            headClearable: false;
            /* 面板不跟随当前播放行滚动: 歌词页本身已按播放进度锚定歌词,
             * 两个位置同时跳动会互相干扰, 主界面那份实例保持跟随 */
            autoFollow: false;
        }
    }
    /* 播放条常驻热区: 播放条隐藏(禁用)时由它接住悬停与点击, 指针一进来就把整条播放条唤回;
     * 声明在播放条之前, 因此播放条可见时由播放条自己消费输入;
     * 隐藏时接受左键: 否则点在这一带会被页面的拖动区接管成拖动窗口 */
    MouseArea {
        id: barChromeSensor;
        x: 0;
        y: (playerBarSubone.y-Define.windowPadding);
        width: root.width;
        height: (playerBarSubone.height+Define.windowPadding*2);
        acceptedButtons: (root.barVisible? Qt.NoButton:Qt.LeftButton);
        hoverEnabled: true;
        onContainsMouseChanged: {
            if(containsMouse===true) {
                root.showBar();
            }
        }
        onClicked: {
            root.showBar();
        }
    }

    /* 底部播放条: 与主界面播放栏共用同一份实现, 透明无卡片底, 左右与底部各留 windowPadding 的外边距;
     * 队列与播放状态的权威是注入的播放器 */
    PlayerBar {
        id: playerBarSubone;
        cardStyle: false;
        /* 歌词页里这枚封面按钮的作用是退出歌词页, 悬停图标用关闭图形 */
        lyricsCloseIcon: true;
        /* 歌词页里这份播放栏同样控制桌面悬浮歌词, 点亮状态跟随悬浮窗 */
        lyricsOpened: (root.theWindow!==null && root.theWindow.desktopLyricsVisible===true);
        opacity: (root.barVisible? 1:0);
        enabled: root.barVisible;
        Behavior on opacity {
            NumberAnimation { duration: Define.playerBarFadeMs; }
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
        onDesktopLyricsRequested: {
            if(root.theWindow!==null && root.theWindow.toggleDesktopLyrics!==undefined) {
                root.theWindow.toggleDesktopLyrics();
            }
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
        width: 300;
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
            /* 歌词颜色: 一排候选色块, 空串那一档表示跟随主题 */
            Row {
                spacing: 8;
                Text {
                    color: Define.textColor;
                    width: 62;
                    text: "歌词颜色";
                    font.pixelSize: 13;
                    anchors.verticalCenter: parent.verticalCenter;
                }
                Repeater {
                    model: Define.lyricsColorOptions;
                    delegate: Rectangle {
                        width: 20;
                        height: 20;
                        radius: 10;
                        anchors.verticalCenter: parent.verticalCenter;
                        color: (modelData["id"]===""? Define.btnIconColor:modelData["id"]);
                        border.width: ((GlobalFileStorage.lyricsTextColor()===modelData["id"])? 2:0);
                        border.color: Define.choseCyanColor;
                        MouseArea {
                            anchors.fill: parent;
                            onClicked: {
                                GlobalFileStorage.setLyricsTextColor(modelData["id"]);
                                root.closeMenu();
                            }
                        }
                    }
                }
            }
            /* 显示位置: 当前行在歌词视口高度上的锚定比例 */
            Row {
                spacing: 8;
                Text {
                    color: Define.textColor;
                    width: 62;
                    text: "显示位置";
                    font.pixelSize: 13;
                    anchors.verticalCenter: parent.verticalCenter;
                }
                Repeater {
                    model: Define.lyricsAnchorOptions;
                    delegate: CustomButtonA {
                        width: 42;
                        height: 24;
                        transEnabled: false;
                        background: Rectangle {
                            anchors.fill: parent;
                            radius: 12;
                            color: (Math.abs(root.anchorRatio-modelData)<0.01
                                    ? Define.choseCyanColor:Define.hoverDarkColor);
                            Text {
                                anchors.centerIn: parent;
                                text: Math.round(modelData*100)+"%";
                                font.pixelSize: 12;
                                color: Define.textColor;
                            }
                        }
                        onClicked: {
                            GlobalFileStorage.setLyricsAnchorRatio(modelData);
                            root.closeMenu();
                        }
                    }
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
    /* 歌词列上方的曲名与歌手: 取当前播放项, 没有播放项时为空 */
    readonly property string playingSongName: ((playingEntryData===null || playingEntryData["songname"]===undefined)
                                               ? "":String(playingEntryData["songname"]));
    readonly property string playingSingerName: ((playingEntryData===null || playingEntryData["singer"]===undefined)
                                                 ? "":String(playingEntryData["singer"]));
    /* 歌词名: 条目自带优先; 早期落盘的条目没有这一项, 由 Server 按在线标识或下载记录回查清单,
     * 因此已下载到本地再播放的曲目同样能出歌词 */
    readonly property string playingLyricsName: Server.lyricsNameOfEntry(playingEntryData);
    /* 实际使用的歌词名: 关闭歌词增强时为普通歌词, 开启时为增强歌词 */
    readonly property string activeLyricsName: Server.lyricsVariantName(playingLyricsName);
    /* 歌词字号: 取界面偏好, 全部歌词行同一字号 */
    readonly property int baseFontSize: GlobalFileStorage.lyricsFontSize();
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
    /* 歌词同步与页面可见性脱钩: 桌面悬浮歌词在歌词页关闭时同样需要当前行与下一行,
     * 因此切歌与切档一律重新同步, 解析开销只是一次读文件 */
    onActiveLyricsNameChanged: {
        root.syncLyrics();
    }
    /* 增强开关本身也决定是否解析逐字信息: 开关一变就按新口径重解析一次 */
    onEnhancedOnChanged: {
        root.syncLyrics();
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
                out.push({"t":-1,"text":body["text"],"words":words,"headLength":body["headLength"]});
                continue;
            }
            for(var j=0;j<stamps.length;j++) {
                out.push({"t":stamps[j],"text":body["text"],"words":words,"headLength":body["headLength"]});
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
    /* 播放位置对应的行下标: 取最后一个时间戳不晚于当前秒数的行, 遇到无时间戳的行即停;
     * 全部行都没有时间戳时返回 -1, 由调用方按首行兜底 */
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
         * 全部行都没有时间戳的歌词同样把第 0 行当作当前行, 与首行兜底同一口径,
         * 否则这类歌词页不高亮任何行, 桌面歌词恒显示"暂无歌词";
         * 最后一行播完之后固定停在最后一个有时间戳的行, 歌词侧不再换行, 也不干预播放 */
        if(idx<0) {
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
        /* 首段在整行文本里的起始下标: 渲染时靠它把词下标换算成字符位置 */
        var full=head+plain;
        var trimmed=full.trim();
        var leadTrim=full.length-full.replace(/^\s+/,"").length;
        return ({"text":trimmed, "words":words, "headLength":Math.max(0,head.length-leadTrim)});
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
    /* 文本度量: 与委托里的 Text 用同一套字体, 边界位置按真实字宽算, 不按字数估算 */
    TextMetrics {
        id: lyricMetrics;
    }
    FontMetrics {
        id: lyricFontMetrics;
    }
    function measureTextWidth(text,pixelSize,bold) {
        lyricMetrics.font.pixelSize=pixelSize;
        lyricMetrics.font.bold=bold;
        lyricMetrics.text=String(text);
        return lyricMetrics.advanceWidth;
    }
    /* 与 Text 的默认行距一致的行高: 遮罩按它定位当前行的上下边界 */
    function rowHeightOf(pixelSize,bold) {
        lyricFontMetrics.font.pixelSize=pixelSize;
        lyricFontMetrics.font.bold=bold;
        return lyricFontMetrics.height;
    }
    /* 可断行位置: 空白与中日韩字符(含全角标点)之后都可以断, 与 Text 的换行口径对齐 */
    function isWrapPoint(ch) {
        var c=String(ch).charCodeAt(0);
        if(c===0x20 || c===0x09) {
            return true;
        }
        return (c>=0x2E80 && c<=0x9FFF)||(c>=0xF900 && c<=0xFAFF)
               ||(c>=0x3000 && c<=0x303F)||(c>=0xFF00 && c<=0xFFEF);
    }
    /* 当前行的可视行切分: 按列宽贪心断行, 返回每行在整行文本里的起止下标与宽度,
     * 以及逐字宽度与行高; 断行只在文本, 字号或列宽变化时重算 */
    function sungLayoutOf(text,pixelSize,bold,columnWidth) {
        var s=String(text);
        var n=s.length;
        var widths=[];
        for(var i=0;i<n;i++) {
            widths.push(root.measureTextWidth(s.charAt(i),pixelSize,bold));
        }
        var lines=[];
        var from=0;
        while(from<n) {
            var sum=0;
            var cur=from;
            var brk=from;
            while(cur<n) {
                var cw=Number(widths[cur]);
                if(sum+cw>Number(columnWidth) && cur>from) {
                    break;
                }
                sum=sum+cw;
                cur=cur+1;
                if(root.isWrapPoint(s.charAt(cur-1))===true) {
                    brk=cur;
                }
            }
            var to=(brk>from && brk<cur? brk:cur);
            var w=0;
            for(var j=from;j<to;j++) {
                w=w+Number(widths[j]);
            }
            lines.push({"from":from,"to":to,"w":w});
            from=to;
        }
        if(lines.length<=0) {
            lines.push({"from":0,"to":0,"w":0});
        }
        return ({"lines":lines,"widths":widths,"rowHeight":root.rowHeightOf(pixelSize,bold),
                 "columnWidth":Number(columnWidth)});
    }
    /* 遮罩几何: top 是当前行之前的整块高度, width 是当前行已唱到的像素位置, row 是行高;
     * 当前词落在哪一可视行由字符下标算出, 行内左偏移按居中排版补齐 */
    function sungMaskOf(layout,one,textLineCount) {
        var none={"ready":false,"top":0,"width":0,"row":0};
        if(layout===null || layout===undefined || one===null || one===undefined) {
            return none;
        }
        /* 自算断行与 Text 的行数对不上时不强行着色, 宁可这一行不上色也不要让边界落错行 */
        if(textLineCount!==undefined && textLineCount>0
           && layout["lines"].length!==textLineCount) {
            if(root._maskFallbackLine!==root.currentLine) {
                root._maskFallbackLine=root.currentLine;
                Assist.dlog("界面","逐字进度: 自算断行与 Text 行数不一致, 第 ",
                            root.currentLine," 行不上色");
            }
            return none;
        }
        var ws=one["words"];
        if(ws===undefined || ws===null || ws.length<=0
           || root.currentWord<0 || root.currentWord>=ws.length) {
            return none;
        }
        var off=Number(one["headLength"]===undefined? 0:one["headLength"]);
        var seg=String(ws[root.currentWord]["text"]);
        for(var i=0;i<root.currentWord;i++) {
            off=off+String(ws[i]["text"]).length;
        }
        var lines=layout["lines"];
        var widths=layout["widths"];
        var total=widths.length;
        var k=-1;
        for(var j=0;j<lines.length;j++) {
            if(off>=lines[j]["from"] && off<lines[j]["to"]) {
                k=j;
                break;
            }
        }
        if(k<0) {
            /* 当前词正好落在换行处: 归到下一行的开头 */
            for(var j2=0;j2<lines.length;j2++) {
                if(lines[j2]["from"]===off) {
                    k=j2;
                    break;
                }
            }
        }
        if(k<0) {
            return none;
        }
        var line=lines[k];
        var prefix=0;
        for(var p=line["from"];p<off && p<total;p++) {
            prefix=prefix+Number(widths[p]);
        }
        var segW=0;
        var segEnd=Math.min(line["to"],off+seg.length);
        for(var q=off;q<segEnd && q<total;q++) {
            segW=segW+Number(widths[q]);
        }
        var column=Number(layout["columnWidth"]);
        var lineLeft=Math.max(0,(column-Number(line["w"]))/2);
        var f=(root.wordProgress<0? 0:(root.wordProgress>1? 1:root.wordProgress));
        return ({"ready":true,
                 "top":(k*Number(layout["rowHeight"])),
                 "row":Number(layout["rowHeight"]),
                 "width":Math.min(column,lineLeft+prefix+segW*f)});
    }
    /* 刷新平滑插值的锚点: 播放器每次上报位置时调用 */
    function rebaseAnim(sec) {
        root._animBaseSec=Number(sec);
        root._animAnchorMs=Date.now();
    }
    /* 当前词的着色比例: 词起点到下一个词起点之间线性插值, 末词用固定时长兜底;
     * 单个字或词的着色窗口最多按 Define.lyricsWordMaxSpanMs 截断, 行间空档很大时
     * 最后一个字不会一直拖到下一行的开始时刻 */
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
        var cap=Define.lyricsWordMaxSpanMs/1000;
        var span=Math.min(cap,Math.max(0.12,t1-t0));
        var f=(sec-t0)/span;
        if(f<0) {
            f=0;
        }
        if(f>1) {
            f=1;
        }
        /* 边界按像素定位, 不再量化到整字; 只留很小的量化, 避免亚像素抖动带来的重复刷新 */
        return Math.round(f*96)/96;
    }
    /* 平滑节拍: 按真实时间外推播放位置, 再算出当前词的着色比例 */
    function tickWordProgress() {
        var sec=root._animBaseSec+(Date.now()-root._animAnchorMs)/1000;
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
    /* 鼠标在页面内移动: 记下当前位置, 落在播放条热区里就保持常显, 否则开始隐藏倒计时;
     * HoverHandler 的 pointChanged 不带入参, 位置一律取 point 属性, 写成 (p)=> 会拿到 undefined */
    HoverHandler {
        id: pageHover;
        onPointChanged: {
            root._pointerInPage=true;
            root._pointerX=point.position.x;
            root._pointerY=point.position.y;
            root.followPointer(point.position.x,point.position.y);
        }
        /* 指针移出窗口时没有后续移动事件: 记下指针已经离开并起表, 不让播放条一直挂着 */
        onHoveredChanged: {
            root._pointerInPage=hovered;
            if(hovered!==true) {
                root.startBarHideCountdown();
            }
        }
    }
    /* 播放条隐藏计时: 指针离开播放条这一片 3 秒还没回来就把整条播放条淡出;
     * 弹层展开或滑块被按住期间是锁定态, 到时也不隐藏 */
    Timer {
        id: rehideTimer;
        interval: Define.playerBarHideDelayMs;
        repeat: false;
        onTriggered: {
            if(root.barLocked()===true) {
                return;
            }
            /* 指针此刻就在热区里就不隐藏: 倒计时的起点可能早于指针进来 */
            if(root.pointerInBarHotArea()===true) {
                return;
            }
            root.hideBar();
        }
    }
    /* 交互锁: 本页播放条上有弹层展开或滑块被按住时不隐藏, 状态由播放条组件自己给出 */
    function barLocked() {
        if(playerBarSubone===null || playerBarSubone===undefined) {
            return false;
        }
        return (playerBarSubone.interactionLocked===true);
    }
    /* 播放条热区: 播放条自身与它展开的弹层, 外扩 Define.playerBarHotPad;
     * 弹层挂在播放条上方, 几何由播放条自己给出, 这里只做坐标换算 */
    function inBarHotArea(x,y) {
        if(playerBarSubone===null || playerBarSubone===undefined) {
            return false;
        }
        var p=playerBarSubone.mapFromItem(root,Number(x),Number(y));
        return (playerBarSubone.hotAreaContains(p.x,p.y,Define.playerBarHotPad)===true);
    }
    /* 指针此刻是否落在播放条热区里: 指针已经离开页面时一律算不在, 不回看最后一次移动的坐标 */
    function pointerInBarHotArea() {
        if(root._pointerInPage!==true) {
            return false;
        }
        if(barChromeSensor.containsMouse===true) {
            return true;
        }
        return root.inBarHotArea(root._pointerX,root._pointerY);
    }
    /* 指针移动时的可见性策略: 在热区里或处于锁定态即显示并停表, 否则只启动一次倒计时 */
    function followPointer(x,y) {
        if(root.inBarHotArea(x,y)===true || root.barLocked()===true) {
            root.showBar();
            return true;
        }
        return root.startBarHideCountdown();
    }
    /* 显示整条播放条并停掉隐藏倒计时 */
    function showBar() {
        if(root.barVisible!==true) {
            Assist.dlog("界面","播放条: 指针回到热区, 显示");
        }
        barVisible=true;
        rehideTimer.stop();
    }
    /* 隐藏整条播放条: 先把弹层与播放列表面板一起收起, 再淡出 */
    function hideBar() {
        if(playerBarSubone!==null && playerBarSubone!==undefined) {
            playerBarSubone.prepareHide();
        }
        if(root.barVisible===true) {
            Assist.dlog("界面","播放条: 离开热区, 隐藏");
        }
        barVisible=false;
        rehideTimer.stop();
    }
    /* 启动隐藏倒计时: 已在倒计时中时不重新计时, 避免指针在歌词区里移动就把播放条一直挂着 */
    function startBarHideCountdown() {
        if(root.barVisible!==true) {
            return false;
        }
        if(rehideTimer.running!==true) {
            rehideTimer.restart();
            Assist.dlog("界面","播放条: 指针离开热区, 开始隐藏计时 ",Define.playerBarHideDelayMs," 毫秒");
        }
        return true;
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
    /* 把当前行钉到锚定线: 先让列表把这一行实例化, 再按它的真实内容偏移算滚动位置;
     * 首尾由列表的首尾留白兜底; 用户正在拖动时不抢占, 松手后由列表的 movementEnded 重新锚定 */
    function anchorToCurrentLine() {
        if(visible!==true || lyricView.moving===true) {
            return false;
        }
        if(currentLine<0 || currentLine>=lyricLines.length) {
            return false;
        }
        lyricView.positionViewAtIndex(currentLine,ListView.Beginning);
        root.applyAnchorOffset();
        /* 行高要等委托完成排版才准: 下一帧按真实行高再校一次, 首次显示与重启后打开也能落准 */
        Qt.callLater(root.applyAnchorOffset);
        return true;
    }
    /* 按目标行的真实 y 与视口高度算滚动位置: 不用 positionViewAtIndex 的估算,
     * 也不拿可能尚未结算的内容总高去夹, 越界由列表按边界自己收住 */
    function applyAnchorOffset() {
        if(root.visible!==true || lyricView.moving===true || root.userScrolled===true) {
            return false;
        }
        if(root.currentLine<0 || root.currentLine>=lyricLines.length) {
            return false;
        }
        var it=lyricView.itemAtIndex(root.currentLine);
        if(it===null || it===undefined) {
            return false;
        }
        lyricView.contentY=Math.max(0,it.y-lyricView.height*root.anchorRatio);
        /* 记下锚定位置: 跳转按钮的可见性按它与当前偏移的差判断 */
        root._anchorContentY=lyricView.contentY;
        return true;
    }
    /* 当前行是否正好嵌在基准高度范围内: 锚定偏移与当前偏移之差不超过容错才算,
     * 不是有重叠就算; 不依赖当前行是否还在实例化的委托里, 滚得再远也判得准 */
    function currentLineInBand() {
        if(root.currentLine<0) {
            return true;
        }
        return (Math.abs(lyricView.contentY-root._anchorContentY)<=root.anchorBandTol);
    }
    /* 当前行是否已经落在锚定线上: 与基准高度的判定同一口径 */
    function isAnchoredAtCurrent() {
        if(root.currentLine<0) {
            return false;
        }
        return root.currentLineInBand();
    }
    /* 基准高度对准的歌词行: 优先取完全落在基准范围内的那一行(容许十分之一行高的误差),
     * 没有行正好嵌进去时退回取盖住基准线的行, 再没有就取第一行可见行 */
    function anchorLineIndex() {
        var anchorY=lyricView.height*root.anchorRatio;
        var bandH=root.anchorBandHeight;
        var tol=root.anchorBandTol;
        var target=lyricView.contentY+anchorY;
        var first=-1;
        var covering=-1;
        for(var i=0;i<lyricLines.length;i++) {
            var it=lyricView.itemAtIndex(i);
            if(it===null || it===undefined) {
                if(first>=0) {
                    break;
                }
                continue;
            }
            if(first<0) {
                first=i;
            }
            var top=it.y-lyricView.contentY;
            var h=(it.height>0? it.height:bandH);
            if(top>=anchorY-tol && (top+h)<=(anchorY+bandH+tol)) {
                return i;
            }
            if(covering<0 && target<=it.y+it.height) {
                covering=i;
            }
        }
        if(covering>=0) {
            return covering;
        }
        return first;
    }
    /* 基准高度上可跳转的行: 没有行或该行没有时间戳时返回 -1 */
    function anchorSeekLineIndex() {
        var idx=root.anchorLineIndex();
        if(idx<0 || idx>=lyricLines.length) {
            return -1;
        }
        return (Number(lyricLines[idx]["t"])>=0? idx:-1);
    }
    /* 跳转按钮的可见性: 当前行已离开基准高度范围, 且基准线上有带时间戳的行 */
    function seekAnchorReady() {
        if(root.visible!==true || root.currentLine<0) {
            return false;
        }
        if(root.currentLineInBand()===true) {
            return false;
        }
        return (root.anchorSeekLineIndex()>=0);
    }
    /* 基准线那行的时间: 与点击跳转后的播放进度一致, 显示成 mm:ss */
    function seekAnchorTimeText() {
        var idx=root.anchorSeekLineIndex();
        if(idx<0) {
            return "";
        }
        return root.timeText(Math.max(0,Number(lyricLines[idx]["t"])-root.lyricsOffsetMs/1000));
    }
    /* 秒数格式化为 mm:ss */
    function timeText(sec) {
        var s=Math.max(0,Math.floor(Number(sec)));
        var m=Math.floor(s/60);
        var r=s%60;
        return (m<10? "0"+m:String(m))+":"+(r<10? "0"+r:String(r));
    }
    /* 跳到某行的起始时刻: 按偏移量换算回真实播放位置 */
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
    /* 锁定态解除(弹层收起或松开滑块)后按指针位置重新判定:
     * 指针还在热区里就保持常显, 已经离开就起表, 不必等指针再动一次 */
    Connections {
        target: playerBarSubone;
        function onInteractionLockedChanged() {
            if(root.barLocked()===true) {
                return;
            }
            if(root._pointerInPage!==true) {
                root.startBarHideCountdown();
                return;
            }
            root.followPointer(root._pointerX,root._pointerY);
        }
    }
    /* 显示时同步一次播放条与歌词并亮出播放条, 隐藏时只改可见性并把下一轮复位成常显;
     * 隐藏计时不在这里起表: 只有指针真的离开播放条那一片才开始计时 */
    onVisibleChanged: {
        if(visible===true) {
            root.syncLyrics();
            Qt.callLater(root.anchorToCurrentLine);
            root.showBar();
        } else {
            rehideTimer.stop();
            root.barVisible=true;
        }
    }
    function show() {
        visible=true;
    }
    function hide() {
        root.closeMenu();
        playerBarSubone.prepareHide();
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

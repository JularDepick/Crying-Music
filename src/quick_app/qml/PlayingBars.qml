import QtQuick

/* 播放中的跳动柱: 四根圆头柱子按同一套比例重画, 由 QML 自己推进相位.
 * 原先这一处用的是带 SMIL animate 的 svg, 而 QML 的 Image 与 Button.icon 只把 svg 光栅化成
 * 一张静态图, 动画不会跑, 因此改为自绘, 顺带能跟随主题色与播放状态启停 */
Item {
    id: root;
    /* 是否继续推进相位: 为假时停在当前相位, 相当于暂停时定格的图标 */
    property bool active: true;
    /* 柱子颜色 */
    property color barColor: "#ffffff";
    /* 一个循环的时长与四根柱子的相位偏移, 对应参考 svg 的 dur 1200ms 与 begin 0 / -0.2s / -0.1s / -0.3s
     * (负 begin 等价于把相位整体前移, 这里换算成 0 到 1 的相位偏移) */
    readonly property int cycleMs: 1200;
    readonly property var phaseOffsets: [0.0,0.8,0.9,0.7];
    /* 循环相位 0 到 1 */
    property real phase: 0;
    /* 与参考 svg 的 960x640 视图同比例: 柱宽 128, 柱心间距 240, 满高 512, 底线 576 */
    readonly property real unit: (root.width>0? root.width/960:0);
    readonly property real contentHeight: 640*root.unit;
    readonly property real barWidth: 128*root.unit;
    readonly property real barFullHeight: 512*root.unit;
    readonly property real barStep: 240*root.unit;
    readonly property real barLeft0: 56*root.unit;
    readonly property real contentTop: Math.max(0,(root.height-root.contentHeight)/2);
    readonly property real barBottomY: (root.contentTop+576*root.unit);
    /* 相位到高度比例的映射: 抛物线弹跳, 顶点(相位 0.25)处速度为零, 形成唯一的静止时段;
     * 底点(相位 0.75)处速度最大并瞬时折返, 因此不再有第二个静止时段;
     * 相位 0 与 1 是同一处相位, 值与速度都连续, 循环接缝不跳变 */
    function heightRatioAt(p) {
        var t=Number(p);
        if(!(t>=0)) {
            t=0;
        }
        t=t-Math.floor(t);
        /* 到顶点的相位距离: 取环上较短的一侧, 0 为顶点, 0.5 为底点 */
        var d=(t-0.25);
        if(d<0) {
            d=d+1;
        }
        if(d>0.5) {
            d=1-d;
        }
        return (1-4*d*d);
    }
    /* 相位推进: 不可见时停下, active 为假时原地停住 */
    NumberAnimation on phase {
        from: 0;
        to: 1;
        duration: root.cycleMs;
        loops: Animation.Infinite;
        running: (root.visible===true);
        /* 只在动画运行时才设暂停: 不可见时动画本就停着, 这时设 paused 会让 QML 刷警告 */
        paused: (root.visible===true && root.active!==true);
    }
    Repeater {
        model: 4;
        delegate: Rectangle {
            width: root.barWidth;
            height: Math.max(root.barWidth,
                             root.barFullHeight*root.heightRatioAt(root.phase+Number(root.phaseOffsets[index])));
            radius: width/2;
            color: root.barColor;
            x: (root.barLeft0+index*root.barStep);
            y: (root.barBottomY-height);
        }
    }
}

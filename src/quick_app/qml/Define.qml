pragma Singleton
import QtQuick

Item {
    visible: false;
    /* 应用名常量: 同时用作窗口标题 */
    property string initTitle: "CryingMusic";
    /* 全局设计常量: 窗口与布局尺寸, 主题色, 列表上限与探测阈值 */
    property int windowPadding: 10;
    property int windowRadius: 7;
    property int mainAreaRaduis: 7;
    property int edgeMouseAreaD: 5; /* 不要改变 */
    property int cornerMouseAreaD: 10; /* 不要改变 */
    property color windowBorderColor: "#aaaaaa";
    property color nocolor: "transparent";
    property color canvasColor: "#f0f0f0";
    property color leftSidebarColor: "#f0f0f0";
    property color leftSidebarHeaderColor: "#f0f0f0";
    property color mainAreaColor: "#f6f6f6";
    property color topNavBarColor: "#f6f6f6";
    property int btnSize: 20;
    property int btnSpacing: 20;
    property int recentListSize: 200; /* 最近播放列表的条数上限 */
    property int probeTimeoutMs: 1000; /* FakePlayer 探测元数据的超时阈值, 超时转 AppFileHelper 兜底 */
    property int probeFallbackMs: 4000; /* AppFileHelper 兜底读取的超时阈值 */
    property color btnIconColor: "#434343";
    property color btnHoverColor: "#00eb81";
    property color btnIconRed: "#f45555";
    property color btnHoverRed: "#e44545";
    property color hoverDarkColor: "#e8e8e8";
    property color choseDarkColor: "#d8d8d8";
    property color choseCyanColor: "#00cc65";
    property color forbdDarkColor: "#bcbcbc";
    property color subGrey: "#e0e0e0";
    property color warnRed: "#ff4411";
    property color vipRed: "#fe3610";
    property color vipGold: "#ffc400";
    /* 允许扫描与手动添加的音频格式: 带点号, 顺序即界面上的顺序, 界面默认全选 */
    property var audioFormats: [".mp3",".m4a",".wav",".flac",".ogg"];
    /* 播放栏曲名与歌手的最大显示宽度: 未超出时宽度贴合文本, 超出该宽度时循环滚动轮播 */
    property int playerTitleMaxWidth: 180;
    /* 歌曲列表三列占列表内容宽度的比例: 曲名与歌手 / 大小 / 时长, 比例和为 1,
     * 排序表头与委托行内两处共用, 保证表头列与行内容列对齐 */
    property var listColumnRatios: [0.7,0.15,0.15];
    /* 歌曲列表行内曲名与歌手列的固定宽度: 不随列宽比例撑开, 超出时省略号截断 */
    property int songColWidth: 240;
    /* 调试输出的分类开关: 分类名到开关的映射, 置 false 即关闭该分类的输出;
     * 输出的统一格式为 [分类标签]<具体信息>, 由 Assist 的输出函数拼装 */
    property var debugCategoryOn:
    ({
        "存储目录": true,
        "落盘": true,
        "列表": true,
        "元数据": true,
        "进度条": true,
        "播放": true,
        "队列": true,
        "面板": true,
        "界面": true,
        "点击收起": true
    });
}
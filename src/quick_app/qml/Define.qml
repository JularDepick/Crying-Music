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
    /* 首页推荐卡片: 封面边长(卡片宽度同此值)与卡片间距 */
    property int homeCardWidth: 150;
    property int homeCardSpacing: 18;
    /* 在线音乐的下载文件命名模板: {songname} 与 {singer} 为占位符,
     * 默认取"歌曲名-歌手", 可在设置页修改, 修改结果落盘为界面偏好 */
    property string downloadNameTemplate: "{songname}-{singer}";
    /* 下载文件命名的三个换挡: 值就是命名模板, 顺序即界面上的顺序 */
    property var downloadNameTemplates: ["{songname}-{singer}","{singer}-{songname}","{songname}"];
    /* 在线播放策略的两个取值: 不下载(纯流式) 与 边播放边下载 */
    property string playStrategyNoDownload: "nodownload";
    property string playStrategyDownloadWhilePlaying: "downloadwhileplaying";
    /* 在线曲库单个候选地址的请求超时(毫秒): 超时即换下一个备用地址 */
    property int onlineRequestTimeoutMs: 8000;
    /* 封面(与在线歌曲的图标等价)缓存生命周期: 默认天数与设置页可选档位;
     * 生命周期在缓存写入那一刻定下, 之后改档位不影响已经缓存的封面 */
    property int iconCacheTtlDefaultDays: 7;
    property var iconCacheTtlDayOptions: [1,7,15,30];
    /* 后台全量补全封面时的并发上限 */
    property int iconFillLimit: 4;
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
        "点击收起": true,
        "在线": true,
        "下载": true
    });
    /* 换肤: 把选定主题的配色写进本单例的同名颜色属性, 这是修改主题与颜色的唯一形式;
     * 主题数据只从 Theme 只读, 本函数不修改 Theme; 入参为主题 id, 未知时回退到默认主题 */
    function applyTheme(themeId) {
        var t=Theme.presetById(themeId);
        var id=(t===null? Theme.defaultId:String(themeId));
        if(t===null) {
            Assist.dwarn("界面","换肤: 未知主题, 改用默认主题 ",Theme.defaultId);
            t=Theme.presetById(Theme.defaultId);
        }
        if(t===null) {
            Assist.derror("界面","换肤失败: 默认主题缺失");
            return false;
        }
        var keys=Theme.colorKeys;
        var miss=[];
        var n=0;
        for(var i=0;i<keys.length;i++) {
            var k=keys[i];
            var c=Theme.colorOf(t["colors"],k);
            if(c==="") {
                miss.push(k);
                continue;
            }
            this[k]=c;
            n=n+1;
        }
        if(miss.length>0) {
            Assist.dwarn("界面","换肤: 主题缺少颜色键 ",miss.join(","));
        }
        Assist.dlog("界面","换肤完成: ",id,", 写入颜色 ",n," 项");
        return (n>0);
    }
}
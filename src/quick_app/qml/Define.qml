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
    /* 正文文字色: 亮色主题取近黑, 暗色主题取近白; 未显式指定颜色的文本都取它 */
    property color textColor: "#1a1a1a";
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
    /* 设置页下载目录路径的最大显示宽度: 超出即截断, 悬停给出完整路径 */
    property int settingsPathMaxWidth: 360;
    /* 在线音乐的下载文件命名模板: {songname} 与 {singer} 为占位符,
     * 默认取"歌曲名-歌手", 可在设置页修改, 修改结果落盘为界面偏好 */
    property string downloadNameTemplate: "{songname}-{singer}";
    /* 下载文件命名的三个换挡: 值就是命名模板, 顺序即界面上的顺序 */
    property var downloadNameTemplates: ["{songname}-{singer}","{singer}-{songname}","{songname}"];
    /* 在线播放策略的两个取值: 不下载(纯流式) 与 边播放边下载 */
    property string playStrategyNoDownload: "nodownload";
    property string playStrategyDownloadWhilePlaying: "downloadwhileplaying";
    /* 对冲拉取: 某个候选源超过各自的等待时长仍未返回, 就并行拉起下一个备用源;
     * 从发起时刻起超过 onlineSourceTimeoutMs 仍未返回即判该源失败 */
    property int onlineMetaHedgeMs: 1000;
    property int onlineManifestHedgeMs: 1000;
    property int onlineCoverHedgeMs: 2000;
    property int onlineLyricsHedgeMs: 1500;
    property int onlineSourceTimeoutMs: 3000;
    /* 缓存模式下的后台元信息轮询节拍: meta 源全部失败后按此节拍持续取最新元信息,
     * 只更新缓存文件, 不打断本次运行已生效的数据; 缓存指向的对象存储失效时改为立即重取
     */
    property int onlineMetaPollMs: 60000;
    /* 在线曲库整组失败后的重试退避: 首次按下限等待, 每失败一次加一个步长, 到上限封顶, 成功后复位;
     * 缓存模式下的元信息轮询不受它影响, 仍按 onlineMetaPollMs 的固定节拍
     */
    property int onlineRetryBaseMs: 60000;
    property int onlineRetryMaxMs: 300000;
    property int onlineRetryStepMs: 60000;
    /* 歌词页字号: 默认值与调节步长, 当前行在字号基础上加一个固定差值 */
    property int lyricsFontSizeDefault: 16;
    property int lyricsFontSizeMin: 12;
    property int lyricsFontSizeMax: 32;
    property int lyricsFontSizeStep: 2;
    property int lyricsCurrentLineExtra: 6;
    /* 歌词偏移: 调节步长与上下限(毫秒), 正值表示歌词提前显示; 偏移量按歌词名落盘 */
    property int lyricsOffsetStepMs: 100;
    property int lyricsOffsetMaxMs: 5000;
    /* 在线封面缓存的生命周期: 默认天数与设置页可选档位;
     * 生命周期在缓存写入那一刻定下, 之后改档位不影响已经缓存的封面 */
    property int coverCacheTtlDefaultDays: 28;
    property var coverCacheTtlDayOptions: [1,7,28,30];
    /* 在线音频缓存: 默认上限(MB)与设置页可选档位, 超出上限按最近使用时间淘汰 */
    property int audioCacheCapDefaultMb: 1024;
    property var audioCacheCapMbOptions: [512,1024,2048,4096];
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
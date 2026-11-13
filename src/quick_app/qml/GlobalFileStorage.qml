pragma Singleton
import QtQuick

import "./"
import AppHelper 1.0

Item {
    /* 最终采用的存储目录, 由 verifyStorageDir 决定 */
    property string storageDirPath: "";
    /* 首选存储目录: 应用数据目录, 即 %APPDATA%/<组织>/<应用> */
    property string storageDirPathA: AppFileHelper.getAppDataPath();
    /* 次选存储目录: 用户目录下的应用同名目录 */
    property string storageDirPathB: AppFileHelper.getUserPath()+"/JularDepick/CryingMusic";
    /* 兜底存储目录: 二进制运行目录, 其余候选都不可用时才使用 */
    property string storageDirPathC: AppFileHelper.getAppPath();
    /* 存储布局: 数据文件放在 <storageDirPath>/data 下, 许可文本放在 <storageDirPath>/licenses 下 */
    property string dataDirName: "data";
    property string licensesDirName: "licenses";
    /* 数据文件名 */
    property string localScanFileName: "localScan.json";
    property string likedFilesFileName: "likedFiles.json";
    property string recentFilesFileName: "recentFiles.json";
    property string playStateFileName: "playState.json";
    property string uiStateFileName: "UI_State.json";
    property string downloadsFileName: "downloads.json";
    /* 用户登录记录: 邮箱, 登录时刻, 签名与登录状态秘钥, 四者一起落盘 */
    property string accountFileName: "account.json";
    /* 听歌时长上报状态: 服务端累计秒数与本地待补报秒数 */
    property string listenStateFileName: "listenState.json";
    /* 迁移标记: 记录已经并进本目录的来源目录, 同一来源只合并一次 */
    property string migrationMarkFileName: "migration.json";
    /* 存储布局: 在线音乐的下载文件放在 <storageDirPath>/downloads 下,
     * 在线封面缓存放在 <storageDirPath>/cache/covers 下,
     * 在线歌词缓存放在 <storageDirPath>/cache/lyrics 下 */
    property string downloadsDirName: "downloads";
    property string cacheDirName: "cache";
    property string coverCacheDirName: "covers";
    property string lyricsCacheDirName: "lyrics";
    /* 在线音频缓存放在 <storageDirPath>/cache/audio 下, 超出上限按最近使用时间淘汰 */
    property string audioCacheDirName: "audio";
    /* 用户头像缓存放在 <storageDirPath>/cache/avatars 下, 两种清晰度各一份, 不过期 */
    property string avatarCacheDirName: "avatars";
    /* 封面缓存索引: 记录每个封面的缓存时刻与该条目自己的生命周期 */
    property string coverCacheIndexFileName: "index.json";
    /* 歌词缓存索引: 记录每份歌词的偏移量(毫秒), 键为歌词缓存文件名 */
    property string lyricsCacheIndexFileName: "index.json";
    /* 音频缓存索引: 键为缓存文件名(即在线标识), 值形如 {size:字节, at:最近使用时刻} */
    property string audioCacheIndexFileName: "index.json";
    /* 在线曲库的元信息与清单缓存放在 <storageDirPath>/cache/online 下:
     * 启动时先读缓存让曲库立即可用, 再在后台静默刷新并覆写缓存 */
    property string onlineCacheDirName: "online";
    property string onlineMetaFileName: "meta.json";
    property string onlineManifestFileName: "manifest.json";
    /* 已播放在线歌曲的时长与大小缓存: 只是元数据就绪前的临时显示数据 */
    property string onlinePlayedMetaFileName: "played.json";
    /* 存储目录下必须齐全的许可文本, 缺失时从程序资源中补全 */
    property var licenseFileNames: ["COPYRIGHT","LICENSE","LICENSE.FDL","LICENSE.Qt"];
    /* 许可文本在程序资源中的目录, 与 licensesDirName 对应 */
    property string licenseResDir: ":/licenses/";
    /* 二进制运行目录下的存储目录指针文件, 记录上一次选定的存储目录 */
    property string storagePointerFileName: "storageDirPath.json";
    /* 落盘数据的结构版本号, 供将来做结构迁移 */
    property int dataVersion: 2;
    /* 下述 # 系指 storageDirPath */
    /* 存到 #/data/localScan.json */
    property var localScan:
    ({
        singleFiles: [],
        scanDirs: [],
        scanFmts: [],
        scanRadio: 0,
        excludedFiles: []
    });
    /* 独立的歌曲路径列表 */
    /* 存到 #/data/likedFiles.json */
    property var likedFiles: [];
    /* 存到 #/data/recentFiles.json */
    property var recentFiles: [];
    /* 在线音乐的下载记录: 每项含在线标识与下载后的本地路径, 同时充当本地与在线的映射表 */
    /* 存到 #/data/downloads.json */
    property var downloads: [];
    /* 用户登录记录: 邮箱为明文, loginAt 为验证通过时服务端给出的毫秒时刻,
     * sign 是服务端按内置密钥签出的 HMAC, 读取时由 Account 复核, 复核通过且未满保留期才算已登录;
     * sessionKey 是服务端签发的登录状态秘钥, 后续涉及用户的操作都要凭它做身份验证 */
    /* 存到 #/data/account.json */
    property var account:
    ({
        email: "",
        loginAt: 0,
        sign: "",
        sessionKey: ""
    });
    /* 听歌时长上报: 服务端给出的累计秒数, 用户等级按它派生;
     * 上报未确认时用 pendingSeconds 暂存本地已播出的秒数, 下次成功时补报 */
    /* 存到 #/data/listenState.json */
    property var listenState:
    ({
        totalSeconds: 0,
        pendingSeconds: 0
    });
    /* 播放状态枢纽: 播放队列, 当前播放项路径与下标, 播放顺序与播放进度; 跨模块只经此处交换 */
    /* 存到 #/data/playState.json */
    property var playState:
    ({
        sortlist: [],
        playingWhich: "",
        playingIndex: -1,
        playMode: 1,
        playingPosition: 0,
        volume: 100,
        /* 静音前音量: 播放栏有多个实例, 静音与取消静音共用这一份,
         * 否则主界面静音后到歌词页取消静音会跳到 100 */
        lastVolume: 100
    });
    /* 界面状态: 需要落盘的界面偏好(左侧栏展开, 当前页面, 下载命名与播放策略, 下载目录, 预设主题,
     * 缓存档位与歌词偏好, 快捷键自定义键位); 跨模块只经此处交换 */
    /* 存到 #/data/UI_State.json */
    property var uiState:
    ({
        leftSidebarSpreaded: true,
        mainAreaPage: "home",
        downloadNameTemplate: "",
        onlinePlayStrategy: "nodownload",
        downloadsDir: "",
        themeId: "",
        coverCacheTtlDays: 0,
        lyricsEnhanced: true,
        lyricsFontSize: 0,
        lyricsTextColor: "",
        lyricsAnchorRatio: 0,
        audioCacheCapMb: 0,
        /* 快捷键自定义键位: 动作名到按键序列, 空表表示全部用设计默认值 */
        shortcutKeys: ({}),
        /* 桌面悬浮歌词窗口位置: null 表示尚未记录过, 打开时落默认位置 */
        desktopLyricsX: null,
        desktopLyricsY: null
    });
    /* 目录决策: 指针优先, 其次 A, 再 B, 最后兜底 C; 三个候选都不可用时退出应用。
     * 全过程输出 [存储目录] 前缀的日志, 便于在运行控制台里追决策路径 */
    function verifyStorageDir() {
        Assist.dlog("存储目录","决策开始");
        Assist.dlog("存储目录","候选 A(应用数据目录): ",dirLabel(storageDirPathA));
        Assist.dlog("存储目录","候选 B(用户目录): ",dirLabel(storageDirPathB));
        Assist.dlog("存储目录","候选 C(二进制运行目录): ",dirLabel(storageDirPathC));
        /* 1. 指针文件指向的目录仍存在且可写时直接沿用, 本次启动不做数据迁移;
         * 目录已消失时不沿用, 走完整决策, 避免用新建的空目录盖掉其它目录里的数据 */
        var remembered=readStoragePointer();
        if(remembered==="") {
            Assist.dlog("存储目录","指针: 没有可用指向, 走完整决策");
        } else {
            Assist.dlog("存储目录","指针: 指向 ",dirLabel(remembered));
        }
        if(remembered!=="" && AppFileHelper.existsDir(remembered)===true
           && writableDir(remembered)===true) {
            storageDirPath=remembered;
            ensureLicenses(remembered);
            Assist.dlog("存储目录","决策: 沿用指针指向的目录");
            Assist.dlog("存储目录","最终采用: ",dirLabel(storageDirPath));
            return true;
        }
        if(remembered!=="") {
            Assist.dlog("存储目录","指针指向的目录不可用, 继续按候选顺序判断");
        }
        var aReady=writableDir(storageDirPathA);
        var bReadable=readableDir(storageDirPathB);
        /* B 只在已存在且可读时才参与判定, 避免无谓地在用户目录下新建空目录 */
        var bReady=(bReadable===true && writableDir(storageDirPathB)===true);
        Assist.dlog("存储目录","判定结果: A 可写=",aReady,", B 可读=",bReadable,", B 可写=",bReady);
        /* 2. A 可用: 优先 A; 仅当 A 的许可文本不齐而 B 齐全时才改用 B */
        if(aReady===true) {
            if(hasLicenses(storageDirPathA)===false && hasLicenses(storageDirPathB)===true) {
                Assist.dlog("存储目录","决策: A 可写但许可文本不齐, B 齐全, 改用 B");
                return adoptStorageDir(storageDirPathB,[storageDirPathA]);
            }
            Assist.dlog("存储目录","决策: 优先采用 A");
            return adoptStorageDir(storageDirPathA,(bReadable===true? [storageDirPathB]:[]));
        }
        /* 3. A 不可用而 B 可用: 改用 B, A 可读时把数据并进 B */
        if(bReady===true) {
            Assist.dlog("存储目录","决策: A 不可写而 B 可用, 改用 B");
            return adoptStorageDir(storageDirPathB,(readableDir(storageDirPathA)===true? [storageDirPathA]:[]));
        }
        /* 4. A 与 B 都不可用: 兜底到 C, 并把 A 与 B 中可读的数据并进来 */
        if(writableDir(storageDirPathC)===true) {
            var srcs=[];
            if(readableDir(storageDirPathA)===true) {
                srcs.push(storageDirPathA);
            }
            if(bReadable===true) {
                srcs.push(storageDirPathB);
            }
            Assist.dlog("存储目录","决策: A 与 B 都不可用, 兜底到 C");
            return adoptStorageDir(storageDirPathC,srcs);
        }
        /* 5. 三个候选都不可用: 报错并退出应用 */
        Assist.derror("存储目录","错误: 三个候选都不可写, 程序退出");
        Assist.derror("存储目录","  A: ",dirLabel(storageDirPathA));
        Assist.derror("存储目录","  B: ",dirLabel(storageDirPathB));
        Assist.derror("存储目录","  C: ",dirLabel(storageDirPathC));
        Qt.exit(1);
        return false;
    }
    /* 目录的日志标签: 把 file:/// 形式换成便于阅读的本地路径, 空路径给出明确提示 */
    function dirLabel(dir) {
        if(dir===undefined || dir==="") {
            return "(空路径)";
        }
        var p=AppFileHelper.clearPath(dir);
        return (p===""? dir:p);
    }
    /* 候选目录是否可读: 空路径视为不可用 */
    function readableDir(dir) {
        if(dir==="") {
            Assist.dlog("存储目录","  可读判定: (空路径) -> 否");
            return false;
        }
        var ok=(AppFileHelper.canReadDir(dir)===true);
        Assist.dlog("存储目录","  可读判定: ",dirLabel(dir)," -> ",ok);
        return ok;
    }
    /* 候选目录是否可写: 不存在时先尝试递归创建; 空路径视为不可用 */
    function writableDir(dir) {
        if(dir==="") {
            Assist.dlog("存储目录","  可写判定: (空路径) -> 否");
            return false;
        }
        if(AppFileHelper.existsDir(dir)===false) {
            Assist.dlog("存储目录","  可写判定: ",dirLabel(dir)," 不存在, 尝试创建");
            if(AppFileHelper.makeDir(dir,true)===false) {
                Assist.dwarn("存储目录","  可写判定: 目录创建失败: ",dirLabel(dir));
                return false;
            }
            Assist.dlog("存储目录","  可写判定: 目录已创建");
        }
        var ok=(AppFileHelper.canWriteDir(dir)===true);
        Assist.dlog("存储目录","  可写判定: ",dirLabel(dir)," -> ",ok);
        return ok;
    }
    /* 采用某个目录作为存储目录: 合并来源目录的数据, 补齐许可文本, 写入指针;
     * 每个来源目录对同一目标目录只合并一次, 判定依据是目标目录 data 下的
     * migration.json 里记下的来源目录清单: 指针写不进去时(例如安装到 Program Files)
     * 每次启动都会重新走完整决策, 若每次都无条件取并集, 旧目录里已删除的
     * 喜欢/最近播放/扫描项会被反复复活 */
    function adoptStorageDir(dir,sources) {
        Assist.dlog("存储目录","采用: ",dirLabel(dir),", 来源目录 ",sources.length," 个");
        storageDirPath=dir;
        var done=mergedSourcesOf(dir);
        var l=sources.length;
        for(var i=0;i<l;i++) {
            if(hasPath(done,sources[i])===true) {
                Assist.dlog("存储目录","跳过已迁移过的来源目录: ",dirLabel(sources[i]));
                continue;
            }
            if(mergeDataFrom(sources[i],dir)===true) {
                markMergedSource(dir,sources[i]);
            }
        }
        ensureLicenses(dir);
        writeStoragePointer(dir);
        Assist.dlog("存储目录","最终采用: ",dirLabel(storageDirPath));
        return true;
    }
    /* 许可文本是否齐全: 只验证存在性, 不验证内容 */
    function hasLicenses(dir) {
        if(dir==="") {
            return false;
        }
        var missing=[];
        var l=licenseFileNames.length;
        for(var i=0;i<l;i++) {
            var one=dir+"/"+licensesDirName+"/"+licenseFileNames[i];
            if(AppFileHelper.existsFile(one)===false) {
                missing.push(licenseFileNames[i]);
            }
        }
        if(missing.length>0) {
            Assist.dlog("存储目录","  许可文本不全: ",dirLabel(dir),", 缺少 ",missing.join(", "));
            return false;
        }
        Assist.dlog("存储目录","  许可文本齐全: ",dirLabel(dir));
        return true;
    }
    /* 补全许可文本: 只补缺失项, 不覆盖已存在的文件 */
    function ensureLicenses(dir) {
        if(dir==="") {
            return false;
        }
        var copied=0;
        var l=licenseFileNames.length;
        for(var i=0;i<l;i++) {
            var dst=dir+"/"+licensesDirName+"/"+licenseFileNames[i];
            if(AppFileHelper.existsFile(dst)===false) {
                if(AppFileHelper.copyFile(licenseResDir+licenseFileNames[i],dst)===false) {
                    Assist.derror("存储目录","许可文本补全失败: ",dirLabel(dst));
                } else {
                    Assist.dlog("存储目录","许可文本已补全: ",licenseFileNames[i]);
                    copied=copied+1;
                }
            }
        }
        Assist.dlog("存储目录","许可文本检查完成, 本次补全 ",copied," 个");
        return true;
    }
    /* 读取存储目录指针: 文件缺失或内容损坏时返回空字符串 */
    function readStoragePointer() {
        var f=storageDirPathC+"/"+storagePointerFileName;
        if(storageDirPathC==="") {
            Assist.dlog("存储目录","指针: 候选 C 为空, 无法定位指针文件");
            return "";
        }
        if(AppFileHelper.existsFile(f)===false) {
            Assist.dlog("存储目录","指针: 文件不存在 ",dirLabel(f));
            return "";
        }
        var txt=AppFileHelper.readFile(f,"UTF-8");
        if(txt==="") {
            Assist.dlog("存储目录","指针: 文件为空 ",dirLabel(f));
            return "";
        }
        var obj=null;
        try {
            obj=JSON.parse(txt);
        } catch(e) {
            Assist.dwarn("存储目录","指针解析失败: ",e);
            return "";
        }
        if(obj===null || obj===undefined || typeof obj.storageDirPath!=="string") {
            Assist.dlog("存储目录","指针: 内容缺少 storageDirPath 字段");
            return "";
        }
        return obj.storageDirPath;
    }
    /* 写入存储目录指针: 写入失败不影响本次运行 */
    function writeStoragePointer(dir) {
        if(storageDirPathC==="" || dir==="") {
            Assist.dlog("存储目录","指针: 候选 C 或目标为空, 跳过写入");
            return false;
        }
        var f=storageDirPathC+"/"+storagePointerFileName;
        var txt=JSON.stringify({"version":dataVersion,"storageDirPath":dir});
        if(AppFileHelper.writeFile(f,txt,"UTF-8")===false) {
            Assist.dwarn("存储目录","指针写入失败: ",dirLabel(f));
            return false;
        }
        Assist.dlog("存储目录","指针已写入: ",dirLabel(f));
        return true;
    }
    /* 读取迁移标记里的来源目录清单: 标记缺失或类型异常时按空清单处理 */
    function mergedSourcesOf(dir) {
        var one=readPayload(dir,migrationMarkFileName);
        if(isPayloadObject(one)!==true) {
            return [];
        }
        return (isPayloadArray(one.sources)===true? one.sources:[]);
    }
    /* 记录某个来源目录已合并进目标目录: 写失败只记日志, 不阻断采用流程,
     * 下次启动会再合并一次(并集本身幂等, 只是白做一遍) */
    function markMergedSource(dir,srcDir) {
        var list=mergedSourcesOf(dir);
        if(hasPath(list,srcDir)===true) {
            return true;
        }
        list.push(srcDir);
        var ok=writePayload(dir,migrationMarkFileName,({"sources":list}));
        if(ok!==true) {
            Assist.dwarn("存储目录","迁移标记写入失败: ",dirLabel(dir));
        }
        return ok;
    }
    /* 读取某目录下某个数据文件的有效载荷: 文件缺失或内容损坏时返回 null */
    function readPayload(dir,fileName) {
        if(dir==="") {
            return null;
        }
        var f=dir+"/"+dataDirName+"/"+fileName;
        if(AppFileHelper.existsFile(f)===false) {
            return null;
        }
        var txt=AppFileHelper.readFile(f,"UTF-8");
        if(txt==="") {
            return null;
        }
        var obj=null;
        try {
            obj=JSON.parse(txt);
        } catch(e) {
            Assist.dwarn("落盘","数据文件解析失败: ",f,e);
            return null;
        }
        if(obj===null || obj===undefined || obj.payload===undefined) {
            return null;
        }
        return obj.payload;
    }
    /* 写入某目录下某个数据文件: 统一带上结构版本号; 存储目录未确定时拒绝写入 */
    function writePayload(dir,fileName,payload) {
        if(dir==="") {
            Assist.dwarn("落盘","保存失败: 存储目录未确定");
            return false;
        }
        var f=dir+"/"+dataDirName+"/"+fileName;
        var txt=JSON.stringify({"version":dataVersion,"payload":payload});
        var ok=AppFileHelper.writeFile(f,txt,"UTF-8");
        if(ok===true) {
            Assist.dlog("落盘","写入数据文件: ",fileName);
        } else {
            Assist.dwarn("落盘","写入数据文件失败: ",f);
        }
        return ok;
    }
    /* 载荷类型判定: 数组要求是数组, 对象要求是普通对象(非 null, 非数组);
     * 数据文件被外部改坏成数字/字符串/数组时, 各合并函数据此跳过该文件 */
    function isPayloadArray(v) {
        return (Array.isArray(v)===true);
    }
    function isPayloadObject(v) {
        return (v!==null && v!==undefined && typeof v==="object" && Array.isArray(v)===false);
    }
    /* 载荷类型名: 只用于日志, 让类型异常的记录能看出实际拿到的是什么 */
    function payloadKind(v) {
        if(v===null || v===undefined) {
            return "空";
        }
        if(Array.isArray(v)===true) {
            return "数组";
        }
        if(typeof v==="object") {
            return "对象";
        }
        return typeof v;
    }
    /* 数据迁移: 目标目录数据为主, 来源目录做并集补齐; 结果直接写回目标目录;
     * 整体兜底: 单个文件类型异常由各 merge 函数自行跳过, 这里再包一层 try/catch,
     * 任何意外都不许抛到启动流程上(否则 Main.qml 的 Component.onCompleted 中断, 窗口不再显示) */
    function mergeDataFrom(srcDir,dstDir) {
        if(srcDir==="" || dstDir==="" || srcDir===dstDir) {
            return false;
        }
        try {
            Assist.dlog("存储目录","迁移数据: ",dirLabel(srcDir)," -> ",dirLabel(dstDir));
            mergeLocalScan(srcDir,dstDir);
            mergePathList(srcDir,dstDir,likedFilesFileName);
            mergePathList(srcDir,dstDir,recentFilesFileName);
            mergeDownloadList(srcDir,dstDir);
            mergeWholePayload(srcDir,dstDir,playStateFileName);
            mergeWholePayload(srcDir,dstDir,uiStateFileName);
            mergeAccount(srcDir,dstDir);
            mergeListenState(srcDir,dstDir);
            Assist.dlog("存储目录","迁移完成: ",dirLabel(srcDir)," -> ",dirLabel(dstDir));
            return true;
        } catch(e) {
            Assist.derror("存储目录","迁移失败, 已跳过该来源目录: ",dirLabel(srcDir),", ",e);
            return false;
        }
    }
    /* 路径列表合并: 目标在前, 来源独有的项按原顺序追加; 任一侧不是数组时按空列表处理 */
    function unionPaths(main,other) {
        var res=(isPayloadArray(main)===true? main.slice():[]);
        if(isPayloadArray(other)!==true) {
            return res;
        }
        var l=other.length;
        for(var i=0;i<l;i++) {
            if(hasPath(res,other[i])===false) {
                res.push(other[i]);
            }
        }
        return res;
    }
    /* 合并一个路径数组数据文件: 两侧都必须是数组, 类型异常时跳过该文件 */
    function mergePathList(srcDir,dstDir,fileName) {
        var src=readPayload(srcDir,fileName);
        if(src===null) {
            Assist.dlog("存储目录","  合并 ",fileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        if(isPayloadArray(src)!==true) {
            Assist.dwarn("存储目录","  合并 ",fileName,": 来源数据类型异常(",payloadKind(src),"), 跳过");
            return false;
        }
        var dst=readPayload(dstDir,fileName);
        if(dst===null) {
            Assist.dlog("存储目录","  合并 ",fileName,": 目标目录没有该文件, 直接采用来源的 ",src.length," 项");
            return writePayload(dstDir,fileName,src);
        }
        if(isPayloadArray(dst)!==true) {
            Assist.dwarn("存储目录","  合并 ",fileName,": 目标数据类型异常(",payloadKind(dst),"), 跳过");
            return false;
        }
        var merged=unionPaths(dst,src);
        Assist.dlog("存储目录","  合并 ",fileName,": 目标 ",dst.length," 项, 来源 ",src.length," 项, 结果 ",merged.length," 项");
        return writePayload(dstDir,fileName,merged);
    }
    /* 下载记录合并: 以在线标识取并集, 目标目录的记录在前 */
    function mergeDownloadList(srcDir,dstDir) {
        var src=readPayload(srcDir,downloadsFileName);
        if(src===null) {
            Assist.dlog("存储目录","  合并 ",downloadsFileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        if(isPayloadArray(src)!==true) {
            Assist.dwarn("存储目录","  合并 ",downloadsFileName,": 来源数据类型异常(",payloadKind(src),"), 跳过");
            return false;
        }
        var dst=readPayload(dstDir,downloadsFileName);
        if(dst===null) {
            Assist.dlog("存储目录","  合并 ",downloadsFileName,": 目标目录没有该文件, 直接采用来源的 ",src.length," 项");
            return writePayload(dstDir,downloadsFileName,src);
        }
        if(isPayloadArray(dst)!==true) {
            Assist.dwarn("存储目录","  合并 ",downloadsFileName,": 目标数据类型异常(",payloadKind(dst),"), 跳过");
            return false;
        }
        var res=dst.slice();
        var ls=src.length;
        for(var i=0;i<ls;i++) {
            var had=false;
            var lr=res.length;
            for(var j=0;j<lr;j++) {
                if(res[j]["onlineId"]===src[i]["onlineId"]) {
                    had=true;
                    break;
                }
            }
            if(had===false) {
                res.push(src[i]);
            }
        }
        Assist.dlog("存储目录","  合并 ",downloadsFileName,": 目标 ",dst.length," 项, 来源 ",src.length," 项, 结果 ",res.length," 项");
        return writePayload(dstDir,downloadsFileName,res);
    }
    /* 扫描文件夹清单合并: 以文件夹路径为唯一标识, 目标目录的勾选状态优先 */
    function unionScanDirs(main,other) {
        var res=[];
        var l=(isPayloadArray(main)===true? main.length:0);
        for(var i=0;i<l;i++) {
            if(isPayloadObject(main[i])!==true) {
                continue;
            }
            res.push({"absdpath":main[i]["absdpath"],"included":(main[i]["included"]===true)});
        }
        if(isPayloadArray(other)!==true) {
            return res;
        }
        var lo=other.length;
        for(var j=0;j<lo;j++) {
            var one=other[j];
            if(isPayloadObject(one)!==true) {
                continue;
            }
            var had=false;
            var lr=res.length;
            for(var k=0;k<lr;k++) {
                if(res[k]["absdpath"]===one["absdpath"]) {
                    had=true;
                    break;
                }
            }
            if(had===false) {
                res.push({"absdpath":one["absdpath"],"included":(one["included"]===true)});
            }
        }
        return res;
    }
    /* 合并扫描配置: 逐项并集, 时长下限以目标目录为准 */
    function mergeLocalScan(srcDir,dstDir) {
        var src=readPayload(srcDir,localScanFileName);
        if(src===null) {
            Assist.dlog("存储目录","  合并 ",localScanFileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        if(isPayloadObject(src)!==true) {
            Assist.dwarn("存储目录","  合并 ",localScanFileName,": 来源数据类型异常(",payloadKind(src),"), 跳过");
            return false;
        }
        var dst=readPayload(dstDir,localScanFileName);
        if(dst===null) {
            Assist.dlog("存储目录","  合并 ",localScanFileName,": 目标目录没有该文件, 直接采用来源的");
            return writePayload(dstDir,localScanFileName,src);
        }
        if(isPayloadObject(dst)!==true) {
            Assist.dwarn("存储目录","  合并 ",localScanFileName,": 目标数据类型异常(",payloadKind(dst),"), 跳过");
            return false;
        }
        var res=({});
        res.singleFiles=unionPaths(dst.singleFiles,src.singleFiles);
        res.excludedFiles=unionPaths(dst.excludedFiles,src.excludedFiles);
        res.scanFmts=unionPaths(dst.scanFmts,src.scanFmts);
        res.scanDirs=unionScanDirs(dst.scanDirs,src.scanDirs);
        res.scanRadio=(dst.scanRadio===undefined? src.scanRadio:dst.scanRadio);
        Assist.dlog("存储目录","  合并 ",localScanFileName,": 手动歌曲 ",res.singleFiles.length,
                    " 项, 扫描文件夹 ",res.scanDirs.length," 个, 格式 ",res.scanFmts.length,
                    " 个, 移除项 ",res.excludedFiles.length," 项, 时长下限 ",res.scanRadio);
        return writePayload(dstDir,localScanFileName,res);
    }
    /* 合并整份数据: 目标目录有该文件时整体以目标为准, 否则采用来源目录的;
     * 播放状态与界面状态都走这条规则 */
    function mergeWholePayload(srcDir,dstDir,fileName) {
        var dst=readPayload(dstDir,fileName);
        if(dst!==null) {
            if(isPayloadObject(dst)!==true) {
                Assist.dwarn("存储目录","  合并 ",fileName,": 目标数据类型异常(",payloadKind(dst),"), 跳过");
                return false;
            }
            Assist.dlog("存储目录","  合并 ",fileName,": 目标目录已有该文件, 以目标为准");
            return false;
        }
        var src=readPayload(srcDir,fileName);
        if(src===null) {
            Assist.dlog("存储目录","  合并 ",fileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        if(isPayloadObject(src)!==true) {
            Assist.dwarn("存储目录","  合并 ",fileName,": 来源数据类型异常(",payloadKind(src),"), 跳过");
            return false;
        }
        Assist.dlog("存储目录","  合并 ",fileName,": 采用来源目录的整份内容");
        return writePayload(dstDir,fileName,src);
    }
    /* 合并听歌上报状态: 与登录记录同一套规则, 取累计秒数较多的一份 */
    function mergeListenState(srcDir,dstDir) {
        var dst=readPayload(dstDir,listenStateFileName);
        var src=readPayload(srcDir,listenStateFileName);
        if(src===null) {
            Assist.dlog("存储目录","  合并 ",listenStateFileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        if(isPayloadObject(src)!==true) {
            Assist.dwarn("存储目录","  合并 ",listenStateFileName,": 来源数据类型异常(",payloadKind(src),"), 跳过");
            return false;
        }
        if(dst!==null && isPayloadObject(dst)!==true) {
            Assist.dwarn("存储目录","  合并 ",listenStateFileName,": 目标数据类型异常(",payloadKind(dst),"), 跳过");
            return false;
        }
        var d=(dst!==null && typeof dst.totalSeconds==="number"? dst.totalSeconds:0);
        var s=(typeof src.totalSeconds==="number"? src.totalSeconds:0);
        if(dst!==null && d>=s) {
            Assist.dlog("存储目录","  合并 ",listenStateFileName,": 目标目录的记录较新, 以目标为准");
            return false;
        }
        Assist.dlog("存储目录","  合并 ",listenStateFileName,": 采用来源目录的记录");
        return writePayload(dstDir,listenStateFileName,src);
    }
    /* 合并登录记录: 两边都有记录时取登录时刻较新的一份, 只有一边有时直接搬过来;
     * 登录状态秘钥随记录一起搬, 缺秘钥的旧记录搬过来后由 Account 复核时按未登录处理 */
    function mergeAccount(srcDir,dstDir) {
        var dst=readPayload(dstDir,accountFileName);
        var src=readPayload(srcDir,accountFileName);
        if(src===null) {
            Assist.dlog("存储目录","  合并 ",accountFileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        if(isPayloadObject(src)!==true) {
            Assist.dwarn("存储目录","  合并 ",accountFileName,": 来源数据类型异常(",payloadKind(src),"), 跳过");
            return false;
        }
        if(dst!==null && isPayloadObject(dst)!==true) {
            Assist.dwarn("存储目录","  合并 ",accountFileName,": 目标数据类型异常(",payloadKind(dst),"), 跳过");
            return false;
        }
        if(dst!==null && (typeof dst.loginAt==="number") && (typeof src.loginAt==="number")
           && dst.loginAt>=src.loginAt) {
            Assist.dlog("存储目录","  合并 ",accountFileName,": 目标目录的记录较新, 以目标为准");
            return false;
        }
        Assist.dlog("存储目录","  合并 ",accountFileName,": 采用来源目录的记录");
        return writePayload(dstDir,accountFileName,src);
    }
    /* 读取落盘数据: 存储目录未确定或数据文件缺失时保持默认值 */
    function load() {
        if(storageDirPath==="") {
            Assist.dwarn("落盘","加载失败: 存储目录未确定");
            return false;
        }
        Assist.dlog("落盘","读取落盘数据: ",storageDirPath);
        var ls=readPayload(storageDirPath,localScanFileName);
        if(ls!==null) {
            localScan=({"singleFiles":(ls.singleFiles===undefined? []:ls.singleFiles),
                        "scanDirs":(ls.scanDirs===undefined? []:ls.scanDirs),
                        "scanFmts":(ls.scanFmts===undefined? []:ls.scanFmts),
                        "scanRadio":(ls.scanRadio===undefined? 0:ls.scanRadio),
                        "excludedFiles":(ls.excludedFiles===undefined? []:ls.excludedFiles)});
        }
        var lk=readPayload(storageDirPath,likedFilesFileName);
        if(Array.isArray(lk)===true) {
            likedFiles=lk;
        }
        var rc=readPayload(storageDirPath,recentFilesFileName);
        if(Array.isArray(rc)===true) {
            recentFiles=rc;
        }
        var dl=readPayload(storageDirPath,downloadsFileName);
        if(Array.isArray(dl)===true) {
            downloads=dl;
        }
        var ps=readPayload(storageDirPath,playStateFileName);
        if(ps!==null) {
            playState=({"sortlist":(Array.isArray(ps.sortlist)===true? ps.sortlist:[]),
                        "playingWhich":(typeof ps.playingWhich==="string"? ps.playingWhich:""),
                        "playingIndex":(typeof ps.playingIndex==="number"? ps.playingIndex:-1),
                        "playMode":(typeof ps.playMode==="number"? ps.playMode:1),
                        "playingPosition":(typeof ps.playingPosition==="number"? ps.playingPosition:0),
                        "volume":(typeof ps.volume==="number"? ps.volume:100),
                        /* 静音前音量: 缺失或非数字时回落到 100 */
                        "lastVolume":normalizeLastVolume(ps.lastVolume)});
        }
        var us=readPayload(storageDirPath,uiStateFileName);
        if(us!==null) {
            /* 只有明确写成 false 才算折叠, 其余情况按展开处理; 页面键缺失或非法时回到首页 */
            uiState=({"leftSidebarSpreaded":(us.leftSidebarSpreaded!==false),
                       "mainAreaPage":(typeof us.mainAreaPage==="string" && us.mainAreaPage!==""? us.mainAreaPage:"home"),
                       "downloadNameTemplate":(typeof us.downloadNameTemplate==="string"? us.downloadNameTemplate:""),
                       "onlinePlayStrategy":(us.onlinePlayStrategy===Define.playStrategyDownloadWhilePlaying
                                             ? Define.playStrategyDownloadWhilePlaying:Define.playStrategyNoDownload),
                       "downloadsDir":(typeof us.downloadsDir==="string"? us.downloadsDir:""),
                       "themeId":(typeof us.themeId==="string"? us.themeId:""),
                       "coverCacheTtlDays":(typeof us.coverCacheTtlDays==="number"? us.coverCacheTtlDays:0),
                       "lyricsEnhanced":(us.lyricsEnhanced!==false),
                       "lyricsFontSize":(typeof us.lyricsFontSize==="number"? us.lyricsFontSize:0),
                       /* 歌词当前行颜色: 空串表示跟随主题 */
                       "lyricsTextColor":(typeof us.lyricsTextColor==="string"? us.lyricsTextColor:""),
                       /* 歌词当前行锚定比例: 0 表示用设计默认值 */
                       "lyricsAnchorRatio":(typeof us.lyricsAnchorRatio==="number"? us.lyricsAnchorRatio:0),
                       "audioCacheCapMb":(typeof us.audioCacheCapMb==="number"? us.audioCacheCapMb:0),
                       /* 快捷键自定义键位: 动作名到按键序列, 空表表示全部用设计默认值 */
                       "shortcutKeys":(us.shortcutKeys!==null && typeof us.shortcutKeys==="object"
                                       ? us.shortcutKeys:{}),
                       /* 桌面悬浮歌词窗口位置: 缺失或非法时记为未设置 */
                       "desktopLyricsX":(typeof us.desktopLyricsX==="number"? Math.round(us.desktopLyricsX):null),
                       "desktopLyricsY":(typeof us.desktopLyricsY==="number"? Math.round(us.desktopLyricsY):null)});
        }
        var ac=readPayload(storageDirPath,accountFileName);
        if(ac!==null) {
            account=({"email":(typeof ac.email==="string"? ac.email:""),
                      "loginAt":(typeof ac.loginAt==="number"? ac.loginAt:0),
                      "sign":(typeof ac.sign==="string"? ac.sign:""),
                      "sessionKey":(typeof ac.sessionKey==="string"? ac.sessionKey:"")});
        }
        var ls2=readPayload(storageDirPath,listenStateFileName);
        if(ls2!==null) {
            listenState=({"totalSeconds":(typeof ls2.totalSeconds==="number"? ls2.totalSeconds:0),
                          "pendingSeconds":(typeof ls2.pendingSeconds==="number"? ls2.pendingSeconds:0)});
        }
        Assist.dlog("落盘","读取完成: 手动歌曲 ",localScan.singleFiles.length,
                    " 项, 扫描文件夹 ",localScan.scanDirs.length,
                    " 个, 喜欢 ",likedFiles.length,
                    " 项, 最近播放 ",recentFiles.length,
                    " 项, 下载 ",downloads.length,
                    " 项, 队列 ",playState.sortlist.length,
                    " 项, 音量 ",playState.volume,
                    ", 页面 ",uiState.mainAreaPage,
                    ", 左侧栏展开 ",uiState.leftSidebarSpreaded,
                    ", 登录邮箱 ",(account.email===""? "无":account.email),
                    ", 累计听歌 ",listenState.totalSeconds," 秒");
        return true;
    }
    /* 写入全部落盘数据: 退出与数据迁移时使用 */
    function save() {
        if(storageDirPath==="") {
            Assist.dwarn("落盘","保存失败: 存储目录未确定");
            return false;
        }
        Assist.dlog("落盘","保存全部落盘数据: ",storageDirPath);
        writePayload(storageDirPath,localScanFileName,localScan);
        writePayload(storageDirPath,likedFilesFileName,likedFiles);
        writePayload(storageDirPath,recentFilesFileName,recentFiles);
        writePayload(storageDirPath,downloadsFileName,downloads);
        writePayload(storageDirPath,playStateFileName,playState);
        writePayload(storageDirPath,uiStateFileName,uiState);
        writePayload(storageDirPath,accountFileName,account);
        writePayload(storageDirPath,listenStateFileName,listenState);
        return true;
    }
    /* 只写听歌上报状态 */
    function saveListenState() {
        return writePayload(storageDirPath,listenStateFileName,listenState);
    }
    /* 只写扫描配置 */
    function saveLocalScan() {
        return writePayload(storageDirPath,localScanFileName,localScan);
    }
    /* 只写喜欢列表 */
    function saveLiked() {
        return writePayload(storageDirPath,likedFilesFileName,likedFiles);
    }
    /* 只写最近播放列表 */
    function saveRecent() {
        return writePayload(storageDirPath,recentFilesFileName,recentFiles);
    }
    /* 只写播放状态 */
    function savePlayState() {
        return writePayload(storageDirPath,playStateFileName,playState);
    }
    /* 只写界面状态 */
    function saveUIState() {
        return writePayload(storageDirPath,uiStateFileName,uiState);
    }
    /* 快捷键: 某个动作当前生效的按键序列; 用户改过就用改过的, 否则用设计默认值 */
    function shortcutKeyOf(action) {
        var id=String(action===undefined || action===null? "":action);
        var m=uiState.shortcutKeys;
        if(m!==null && m!==undefined && typeof m==="object"
           && typeof m[id]==="string" && m[id]!=="") {
            return String(m[id]);
        }
        return (Define.shortcutKeys[id]===undefined? "":String(Define.shortcutKeys[id]));
    }
    /* 快捷键: 某个动作是否被用户改过(与设计默认值不同) */
    function shortcutIsCustom(action) {
        var id=String(action===undefined || action===null? "":action);
        return (shortcutKeyOf(id)!==(Define.shortcutKeys[id]===undefined? "":String(Define.shortcutKeys[id])));
    }
    /* 快捷键: 某个序列当前被哪个动作占用, 没有被占用返回空串 */
    function shortcutOwnerOf(sequence) {
        var seq=String(sequence===undefined || sequence===null? "":sequence);
        if(seq==="") {
            return "";
        }
        var list=Define.shortcutActions;
        for(var i=0;i<list.length;i++) {
            var id=String(list[i]["id"]);
            if(shortcutKeyOf(id)===seq) {
                return id;
            }
        }
        return "";
    }
    /* 快捷键: 写入一个动作的键位; 与设计默认值相同时从自定义表里删掉, 表里只留真正的改动 */
    function setShortcutKey(action, sequence) {
        var id=String(action===undefined || action===null? "":action);
        var seq=String(sequence===undefined || sequence===null? "":sequence);
        if(Define.shortcutKeys[id]===undefined || seq==="") {
            Assist.dwarn("落盘","写入快捷键失败: 动作或序列非法 ",id," / ",seq);
            return false;
        }
        var owner=shortcutOwnerOf(seq);
        if(owner!=="" && owner!==id) {
            Assist.dwarn("落盘","写入快捷键失败: 序列已被占用 ",seq," -> ",owner);
            return false;
        }
        var m={};
        for(var k in uiState.shortcutKeys) {
            m[k]=uiState.shortcutKeys[k];
        }
        if(String(Define.shortcutKeys[id])===seq) {
            delete m[id];
        } else {
            m[id]=seq;
        }
        uiState=_uiStateWith({"shortcutKeys":m});
        var ok=saveUIState();
        Assist.dlog("落盘","写入快捷键: ",id," -> ",seq," 结果 ",ok);
        return ok;
    }
    /* 快捷键: 单个动作恢复设计默认值 */
    function resetShortcutKey(action) {
        var id=String(action===undefined || action===null? "":action);
        if(Define.shortcutKeys[id]===undefined) {
            return false;
        }
        var m={};
        for(var k in uiState.shortcutKeys) {
            m[k]=uiState.shortcutKeys[k];
        }
        if(m[id]===undefined) {
            return true;
        }
        delete m[id];
        uiState=_uiStateWith({"shortcutKeys":m});
        var ok=saveUIState();
        Assist.dlog("落盘","快捷键恢复默认: ",id," 结果 ",ok);
        return ok;
    }
    /* 快捷键: 全部恢复设计默认值 */
    function resetAllShortcutKeys() {
        uiState=_uiStateWith({"shortcutKeys":{}});
        var ok=saveUIState();
        Assist.dlog("落盘","全部快捷键恢复默认, 结果 ",ok);
        return ok;
    }
    /* 用户头像缓存目录: 存储目录未确定时返回空字符串 */
    function avatarCacheDir() {
        if(storageDirPath==="") {
            return "";
        }
        return storageDirPath+"/"+cacheDirName+"/"+avatarCacheDirName;
    }
    /* 只写登录记录 */
    function saveAccount() {
        return writePayload(storageDirPath,accountFileName,account);
    }
    /* 写入登录记录: 邮箱, 登录时刻, 签名与登录状态秘钥四件齐全才写, 缺一项都不落盘;
     * 秘钥为空时视为未签发, 后续涉及用户的操作会因为缺少秘钥而失败 */
    function setAccount(email,loginAt,sign,sessionKey) {
        var e=String(email===undefined || email===null? "":email);
        var t=(typeof loginAt==="number"? loginAt:0);
        var s=String(sign===undefined || sign===null? "":sign);
        var k=String(sessionKey===undefined || sessionKey===null? "":sessionKey);
        if(e==="" || t<=0 || s==="") {
            Assist.dwarn("落盘","写入登录记录失败: 参数不完整");
            return false;
        }
        if(k==="") {
            Assist.dwarn("落盘","写入登录记录失败: 缺少登录状态秘钥");
            return false;
        }
        Assist.dlog("落盘","写入登录记录: ",e);
        account=({"email":e,"loginAt":t,"sign":s,"sessionKey":k});
        return saveAccount();
    }
    /* 清除登录记录: 退出登录时使用, 登录状态秘钥随之作废 */
    function clearAccount() {
        Assist.dlog("落盘","清除登录记录");
        account=({"email":"","loginAt":0,"sign":"","sessionKey":""});
        return saveAccount();
    }
    /* 写入服务端给出的累计听歌秒数: 只在服务端确认过之后调用 */
    function setListenTotalSeconds(seconds) {
        var n=Math.floor(Number(seconds));
        if(!(n>=0)) {
            n=0;
        }
        var was=listenState.totalSeconds;
        listenState=({"totalSeconds":n,
                      "pendingSeconds":listenState.pendingSeconds});
        if(was!==n) {
            saveListenState();
        }
        return true;
    }
    /* 暂存一段本地已播出但服务端未确认的秒数: 上报失败时累加, 上报成功时清零 */
    function addListenPendingSeconds(seconds) {
        var n=Math.floor(Number(seconds));
        if(!(n>0)) {
            return false;
        }
        var p=(typeof listenState.pendingSeconds==="number"? listenState.pendingSeconds:0)+n;
        listenState=({"totalSeconds":(typeof listenState.totalSeconds==="number"? listenState.totalSeconds:0),
                      "pendingSeconds":p});
        saveListenState();
        return true;
    }
    /* 清零待补报秒数: 上报成功时调用 */
    function clearListenPending() {
        listenState=({"totalSeconds":(typeof listenState.totalSeconds==="number"? listenState.totalSeconds:0),
                      "pendingSeconds":0});
        return saveListenState();
    }
    /* 整体写回扫描规则 */
    function setMALocalP(a,b,c) {
        Assist.dlog("落盘","写回扫描规则: 文件夹 ",a.length," 个, 格式 ",b.length," 种, 时长下限 ",c);
        localScan.scanDirs=a;
        localScan.scanFmts=b;
        localScan.scanRadio=c;
        saveLocalScan();
    }
    /* 判断列表中是否含有指定路径 */
    function hasPath(list,absfpath) {
        var l=list.length;
        for(var i=0;i<l;i++) {
            if(list[i]===absfpath) {
                return true;
            }
        }
        return false;
    }
    /* 从列表中剔除指定路径, 返回新列表 */
    function removePaths(list,absfpaths) {
        var l=list.length;
        var res=[];
        for(var i=0;i<l;i++) {
            if(hasPath(absfpaths,list[i])===false) {
                res.push(list[i]);
            }
        }
        return res;
    }
    /* 在列表中添加或移除单个路径, 返回新列表 */
    function setPath(list,absfpath,on) {
        var res=removePaths(list,[absfpath]);
        if(on===true) {
            res.push(absfpath);
        }
        return res;
    }
    /* 添加手动歌曲: 去重写入, 并解除这些路径的移除标记, 收尾统一保存一次 */
    function addSingleFiles(files) {
        Assist.dlog("落盘","添加手动歌曲: ",files.length," 项");
        var vg=localScan.singleFiles;
        var ls=files.length;
        var newvg=vg.slice();
        var newe=localScan.excludedFiles.slice();
        for(var i=0;i<ls;i++) {
            var one=files[i];
            if(one===undefined || one==="") {
                continue;
            }
            if(hasPath(newvg,one)===false) {
                newvg.push(one);
            }
            newe=removePaths(newe,[one]);
        }
        localScan.singleFiles=newvg;
        localScan.excludedFiles=newe;
        saveLocalScan();
    }
    /* 移除歌曲: 手动添加项直接移除, 扫描得到的项记为移除项 */
    function removeSongs(absfpaths) {
        Assist.dlog("落盘","移除歌曲: ",absfpaths.length," 项");
        localScan.singleFiles=removePaths(localScan.singleFiles,absfpaths);
        var newe=localScan.excludedFiles.slice();
        var ls=absfpaths.length;
        for(var i=0;i<ls;i++) {
            if(hasPath(newe,absfpaths[i])===false) {
                newe.push(absfpaths[i]);
            }
        }
        localScan.excludedFiles=newe;
        saveLocalScan();
    }
    /* 解除单个路径的移除标记 */
    function removeExclude(absfpath) {
        localScan.excludedFiles=removePaths(localScan.excludedFiles,[absfpath]);
        saveLocalScan();
    }
    /* 判断路径是否已被移除 */
    function isExcluded(absfpath) {
        return hasPath(localScan.excludedFiles,absfpath);
    }
    /* 在线标识里的文件名: 带前缀的去掉前缀, 历史遗留的播放地址按末段解码后取文件名,
     * 本地路径原样返回; 连续编码的地址最多剥三层 */
    function onlineNameOf(key) {
        var tag=String(Define.onlineKeyTag);
        var s=String(key===undefined || key===null? "":key);
        if(s==="") {
            return "";
        }
        if(s.indexOf(tag)===0) {
            return s.substring(tag.length);
        }
        if(s.indexOf("http://")!==0 && s.indexOf("https://")!==0) {
            return s;
        }
        var name=s;
        for(var n=0;n<3;n++) {
            var cut=name.lastIndexOf("/");
            if(cut<0) {
                break;
            }
            name=name.substring(cut+1);
            try {
                name=decodeURIComponent(name);
            } catch(e) {
                break;
            }
            if(name.indexOf("://")<0) {
                break;
            }
        }
        return name;
    }
    /* 把任意历史键归一成在线标识: 播放地址按文件名重建, 本地路径与已归一的键原样返回 */
    function onlineKeyOf(value) {
        var tag=String(Define.onlineKeyTag);
        var s=String(value===undefined || value===null? "":value);
        if(s==="" || s.indexOf(tag)===0) {
            return s;
        }
        if(s.indexOf("http://")===0 || s.indexOf("https://")===0) {
            var name=onlineNameOf(s);
            return (name===""? "":tag+name);
        }
        return s;
    }
    /* 在线标识迁移: 把喜欢, 最近播放, 播放队列, 当前播放项与下载记录里的历史播放地址
     * 一次性换成与数据根无关的在线标识; 没有变化时不写盘 */
    function migrateOnlineKeys() {
        var n=0;
        var i;
        var k;
        var lk=[];
        for(i=0;i<likedFiles.length;i++) {
            var a=onlineKeyOf(likedFiles[i]);
            if(a!==likedFiles[i]) {
                n=n+1;
            }
            if(lk.indexOf(a)<0) {
                lk.push(a);
            }
        }
        var rc=[];
        for(i=0;i<recentFiles.length;i++) {
            var b=onlineKeyOf(recentFiles[i]);
            if(b!==recentFiles[i]) {
                n=n+1;
            }
            if(rc.indexOf(b)<0) {
                rc.push(b);
            }
        }
        var st=playState;
        var list=[];
        for(i=0;i<st.sortlist.length;i++) {
            var one=st.sortlist[i];
            var v=({});
            for(k in one) {
                v[k]=one[k];
            }
            if(one["online"]===true) {
                var kk=onlineKeyOf(one["absfpath"]);
                if(kk!==one["absfpath"]) {
                    n=n+1;
                }
                v["absfpath"]=kk;
                v["onlineId"]=kk;
            }
            list.push(v);
        }
        var which=onlineKeyOf(st.playingWhich);
        if(which!==st.playingWhich) {
            n=n+1;
        }
        var dl=[];
        for(i=0;i<downloads.length;i++) {
            var d=downloads[i];
            var item=({});
            for(k in d) {
                item[k]=d[k];
            }
            var dk=onlineKeyOf(d["onlineId"]);
            if(dk!==d["onlineId"]) {
                n=n+1;
            }
            item["onlineId"]=dk;
            dl.push(item);
        }
        if(n<=0) {
            return 0;
        }
        likedFiles=lk;
        saveLiked();
        recentFiles=rc;
        saveRecent();
        downloads=dl;
        saveDownloads();
        playState=_playStateWith({"sortlist":list,
                                  "playingWhich":which,
                                  "playingIndex":st.playingIndex,
                                  "playMode":st.playMode});
        savePlayState();
        Assist.dlog("落盘","在线标识迁移: 共改写 ",n," 处");
        return n;
    }
    /* 设置喜欢状态 */
    function setLiked(absfpath,on) {
        Assist.dlog("落盘","喜欢状态: ",absfpath," -> ",on);
        likedFiles=setPath(likedFiles,absfpath,on);
        saveLiked();
    }
    /* 判断路径是否已喜欢 */
    function isLiked(absfpath) {
        return hasPath(likedFiles,absfpath);
    }
    /* 批量取消喜欢 */
    function removeLiked(absfpaths) {
        Assist.dlog("落盘","批量取消喜欢: ",absfpaths.length," 项");
        likedFiles=removePaths(likedFiles,absfpaths);
        saveLiked();
    }
    /* 记录最近播放: 去重后最新在前, 超出上限丢弃最旧 */
    function addRecent(absfpath) {
        if(absfpath===undefined || absfpath==="") {
            return;
        }
        var v=[absfpath];
        var l=recentFiles.length;
        for(var i=0;i<l;i++) {
            if(recentFiles[i]!==absfpath) {
                v.push(recentFiles[i]);
            }
        }
        while(v.length>Define.recentListSize) {
            v.pop();
        }
        recentFiles=v;
        saveRecent();
    }
    /* 批量移除最近播放记录 */
    function removeRecent(absfpaths) {
        Assist.dlog("落盘","批量移除最近播放记录: ",absfpaths.length," 项");
        recentFiles=removePaths(recentFiles,absfpaths);
        saveRecent();
    }
    /* 按当前播放状态生成一份新对象, 只覆盖传入的字段;
     * 一律整体替换, 使外部能收到变更通知 */
    function _playStateWith(overrides) {
        var st=({"sortlist":playState.sortlist,
                 "playingWhich":playState.playingWhich,
                 "playingIndex":playState.playingIndex,
                 "playMode":playState.playMode,
                 "playingPosition":(playState.playingPosition===undefined? 0:playState.playingPosition),
                 "volume":(playState.volume===undefined? 100:playState.volume),
                 /* 静音前音量必须跟着整体替换走, 否则每次替换都会把它丢掉 */
                 "lastVolume":normalizeLastVolume(playState.lastVolume)});
        for(var k in overrides) {
            st[k]=overrides[k];
        }
        return st;
    }
    /* 写入播放状态: 队列, 当前播放项与播放顺序一起写, 播放进度与音量沿用枢纽当前值 */
    function setPlayState(list,which,index,mode) {
        Assist.dlog("落盘","写入播放状态: 队列 ",list.length," 项, 当前 ",which,", 下标 ",index,", 顺序 ",mode);
        playState=_playStateWith({"sortlist":list,
                                  "playingWhich":which,
                                  "playingIndex":index,
                                  "playMode":mode});
        savePlayState();
    }
    /* 写入播放进度: 只改进度, 其余播放状态保持不变 */
    function setPlayPosition(ms) {
        var pos=Math.floor(ms);
        if(pos<0 || isNaN(pos)) {
            pos=0;
        }
        playState=_playStateWith({"playingPosition":pos});
        savePlayState();
    }
    /* 写入音量: 只改音量, 其余播放状态保持不变; 取值限定为 0 到 100 的整数 */
    function setVolume(v) {
        var vol=Math.floor(v);
        if(isNaN(vol) || vol<0) {
            vol=0;
        }
        if(vol>100) {
            vol=100;
        }
        Assist.dlog("落盘","写入音量: ",vol);
        playState=_playStateWith({"volume":vol});
        savePlayState();
    }
    /* 静音前音量归一化: 只接受 1 到 100 的整数, 其余回落到 100 */
    function normalizeLastVolume(v) {
        var n=Math.round(Number(v));
        if(!isFinite(n) || n<1) {
            return 100;
        }
        return (n>100? 100:n);
    }
    /* 读取静音前音量: 播放栏任一实例取消静音时都按这一份恢复 */
    function lastVolume() {
        return normalizeLastVolume(playState.lastVolume);
    }
    /* 写入静音前音量: 供播放栏在音量归零前记录; 值没变时不写文件 */
    function setLastVolume(v) {
        var vol=normalizeLastVolume(v);
        if(typeof playState.lastVolume==="number" && playState.lastVolume===vol) {
            return true;
        }
        Assist.dlog("落盘","写入静音前音量: ",vol);
        playState=_playStateWith({"lastVolume":vol});
        return savePlayState();
    }
    /* 按当前界面状态生成一份新对象, 只覆盖传入的字段;
     * 一律整体替换, 使外部能收到变更通知 */
    function _uiStateWith(overrides) {
        var st=({"leftSidebarSpreaded":(uiState.leftSidebarSpreaded!==false),
                 "mainAreaPage":(uiState.mainAreaPage===undefined? "home":uiState.mainAreaPage),
                 "downloadNameTemplate":(uiState.downloadNameTemplate===undefined? "":uiState.downloadNameTemplate),
                 "onlinePlayStrategy":(uiState.onlinePlayStrategy===Define.playStrategyDownloadWhilePlaying
                                       ? Define.playStrategyDownloadWhilePlaying:Define.playStrategyNoDownload),
                 "downloadsDir":(uiState.downloadsDir===undefined? "":uiState.downloadsDir),
                 "themeId":(uiState.themeId===undefined? "":String(uiState.themeId)),
                 "coverCacheTtlDays":(typeof uiState.coverCacheTtlDays!=="number"? 0:uiState.coverCacheTtlDays),
                 "lyricsEnhanced":(uiState.lyricsEnhanced!==false),
                 "lyricsFontSize":(typeof uiState.lyricsFontSize!=="number"? 0:uiState.lyricsFontSize),
                 "lyricsTextColor":(typeof uiState.lyricsTextColor!=="string"? "":uiState.lyricsTextColor),
                 "lyricsAnchorRatio":(typeof uiState.lyricsAnchorRatio!=="number"? 0:uiState.lyricsAnchorRatio),
                 "audioCacheCapMb":(typeof uiState.audioCacheCapMb!=="number"? 0:uiState.audioCacheCapMb),
                 /* 快捷键自定义键位: 非对象时按空表处理, 保持"只存改动"的口径 */
                 "shortcutKeys":(uiState.shortcutKeys!==null && typeof uiState.shortcutKeys==="object"
                                 ? uiState.shortcutKeys:{}),
                 /* 桌面悬浮歌词位置: 未设置时保持 null, 不能在这里丢掉 */
                 "desktopLyricsX":(typeof uiState.desktopLyricsX!=="number"? null:uiState.desktopLyricsX),
                 "desktopLyricsY":(typeof uiState.desktopLyricsY!=="number"? null:uiState.desktopLyricsY)});
        for(var k in overrides) {
            st[k]=overrides[k];
        }
        return st;
    }
    /* 写入左侧栏展开状态: 只改这一项, 其余界面状态保持不变 */
    function setLeftSidebarSpreaded(on) {
        Assist.dlog("落盘","写入左侧栏展开状态: ",(on===true));
        uiState=_uiStateWith({"leftSidebarSpreaded":(on===true)});
        saveUIState();
    }
    /* 写入主内容区当前页面: 只改这一项, 其余界面状态保持不变; 入参为页面路由键 */
    function setMainAreaPage(route) {
        if(route===undefined || route==="") {
            return false;
        }
        Assist.dlog("落盘","写入主内容区当前页面: ",route);
        uiState=_uiStateWith({"mainAreaPage":route});
        return saveUIState();
    }
    /* 桌面悬浮歌词窗口位置: 未记录过时返回 null, 由界面决定默认位置 */
    function desktopLyricsPos() {
        var x=uiState.desktopLyricsX;
        var y=uiState.desktopLyricsY;
        if(typeof x!=="number" || typeof y!=="number") {
            return null;
        }
        return ({"x":Math.round(x), "y":Math.round(y)});
    }
    /* 写入桌面悬浮歌词窗口位置: 只改这两项, 其余界面状态保持不变 */
    function setDesktopLyricsPos(x,y) {
        var nx=Math.round(Number(x));
        var ny=Math.round(Number(y));
        if(!isFinite(nx) || !isFinite(ny)) {
            Assist.dwarn("落盘","写入桌面歌词位置失败: 非法坐标 ",x,", ",y);
            return false;
        }
        Assist.dlog("落盘","写入桌面歌词位置: ",nx,", ",ny);
        uiState=_uiStateWith({"desktopLyricsX":nx, "desktopLyricsY":ny});
        return saveUIState();
    }
    /* 预设主题偏好: 未设置或不是 Theme 里的预设时回退到默认主题 */
    function themeId() {
        var t=Theme.presetById(uiState.themeId);
        if(t===null) {
            return Theme.defaultId;
        }
        return String(t["id"]);
    }
    /* 写入预设主题偏好: 只改这一项, 其余界面状态保持不变; 未知主题不写入 */
    function setThemeId(id) {
        var t=Theme.presetById(id);
        if(t===null) {
            Assist.dwarn("落盘","写入预设主题失败: 未知主题 ",id);
            return false;
        }
        Assist.dlog("落盘","写入预设主题: ",t["id"]);
        uiState=_uiStateWith({"themeId":String(t["id"])});
        return saveUIState();
    }
    /* 封面缓存生命周期(天): 未设置或超出 1 到 365 时取设计常量里的默认值 */
    function coverCacheTtlDays() {
        var d=uiState.coverCacheTtlDays;
        if(typeof d!=="number" || d<1 || d>365) {
            return Define.coverCacheTtlDefaultDays;
        }
        return Math.floor(d);
    }
    /* 写入封面缓存生命周期: 只改这一项; 已经缓存下来的封面按各自记录的时长到期, 不受影响 */
    function setCoverCacheTtlDays(days) {
        var n=Math.floor(Number(days));
        if(!(n>=1 && n<=365)) {
            Assist.dwarn("落盘","写入封面缓存生命周期失败: 非法天数 ",days);
            return false;
        }
        Assist.dlog("落盘","写入封面缓存生命周期: ",n," 天");
        uiState=_uiStateWith({"coverCacheTtlDays":n});
        return saveUIState();
    }
    /* 在线音频缓存上限(MB): 未设置或不在可选档位内时取设计常量里的默认值 */
    function audioCacheCapMb() {
        var mb=uiState.audioCacheCapMb;
        var opts=Define.audioCacheCapMbOptions;
        for(var i=0;i<opts.length;i++) {
            if(typeof mb==="number" && mb===opts[i]) {
                return mb;
            }
        }
        return Define.audioCacheCapDefaultMb;
    }
    /* 写入在线音频缓存上限: 只改这一项, 已经缓存的音频按到达上限时的最近使用时间淘汰 */
    function setAudioCacheCapMb(mb) {
        var n=Math.floor(Number(mb));
        var opts=Define.audioCacheCapMbOptions;
        var hit=false;
        for(var i=0;i<opts.length;i++) {
            if(n===opts[i]) {
                hit=true;
            }
        }
        if(hit!==true) {
            Assist.dwarn("落盘","写入音频缓存上限失败: 非法档位 ",mb);
            return false;
        }
        Assist.dlog("落盘","写入音频缓存上限: ",n," MB");
        uiState=_uiStateWith({"audioCacheCapMb":n});
        return saveUIState();
    }
    /* 歌词增强开关: 关闭时用普通歌词(lrc), 开启时用增强歌词(elrc) */
    function lyricsEnhanced() {
        return (uiState.lyricsEnhanced===true);
    }
    /* 写入歌词增强开关: 只改这一项, 其余界面状态保持不变 */
    function setLyricsEnhanced(on) {
        Assist.dlog("落盘","写入歌词增强开关: ",(on===true));
        uiState=_uiStateWith({"lyricsEnhanced":(on===true)});
        return saveUIState();
    }
    /* 歌词页字号: 未设置或越界时取设计常量里的默认值 */
    function lyricsFontSize() {
        var s=uiState.lyricsFontSize;
        if(typeof s!=="number" || s<Define.lyricsFontSizeMin || s>Define.lyricsFontSizeMax) {
            return Define.lyricsFontSizeDefault;
        }
        return Math.floor(s);
    }
    /* 写入歌词页字号: 限制在设计常量给出的上下限内 */
    function setLyricsFontSize(px) {
        var n=Math.floor(Number(px));
        if(!(n>=Define.lyricsFontSizeMin && n<=Define.lyricsFontSizeMax)) {
            Assist.dwarn("落盘","写入歌词字号失败: 非法字号 ",px);
            return false;
        }
        Assist.dlog("落盘","写入歌词字号: ",n," px");
        uiState=_uiStateWith({"lyricsFontSize":n});
        return saveUIState();
    }
    /* 歌词当前行颜色: 空串表示跟随主题, 取值由设计常量给出候选 */
    function lyricsTextColor() {
        var c=uiState.lyricsTextColor;
        return (typeof c==="string"? c:"");
    }
    /* 写入歌词当前行颜色: 空串写回跟随主题 */
    function setLyricsTextColor(color) {
        var c=String(color===undefined || color===null? "":color);
        Assist.dlog("落盘","写入歌词颜色: ",(c===""? "跟随主题":c));
        uiState=_uiStateWith({"lyricsTextColor":c});
        return saveUIState();
    }
    /* 歌词当前行锚定比例: 越界或未设置时返回 0, 由界面回落到设计默认值 */
    function lyricsAnchorRatio() {
        var r=uiState.lyricsAnchorRatio;
        if(typeof r!=="number" || !(r>0) || !(r<1)) {
            return 0;
        }
        return r;
    }
    /* 写入歌词锚定比例: 非法值按 0 处理, 即回到设计默认值 */
    function setLyricsAnchorRatio(ratio) {
        var r=Number(ratio);
        if(!(r>0) || !(r<1)) {
            r=0;
        }
        Assist.dlog("落盘","写入歌词锚定比例: ",r);
        uiState=_uiStateWith({"lyricsAnchorRatio":r});
        return saveUIState();
    }
    /* 下载目录: 用户指定过目录时用指定的, 否则用存储目录下的默认目录;
     * 存储目录未确定时返回空字符串 */
    function downloadsDir() {
        if(storageDirPath==="") {
            return "";
        }
        var o=downloadsDirOverride();
        return (o!==""? o:storageDirPath+"/"+downloadsDirName);
    }
    /* 在线封面缓存目录: 存储目录未确定时返回空字符串 */
    function coverCacheDir() {
        if(storageDirPath==="") {
            return "";
        }
        return storageDirPath+"/"+cacheDirName+"/"+coverCacheDirName;
    }
    /* 在线歌词缓存目录: 存储目录未确定时返回空字符串 */
    function lyricsCacheDir() {
        if(storageDirPath==="") {
            return "";
        }
        return storageDirPath+"/"+cacheDirName+"/"+lyricsCacheDirName;
    }
    /* 在线音频缓存目录: 存储目录未确定时返回空字符串 */
    function audioCacheDir() {
        if(storageDirPath==="") {
            return "";
        }
        return storageDirPath+"/"+cacheDirName+"/"+audioCacheDirName;
    }
    /* 在线曲库元信息与清单的缓存目录: 存储目录未确定时返回空字符串 */
    function onlineCacheDir() {
        if(storageDirPath==="") {
            return "";
        }
        return storageDirPath+"/"+cacheDirName+"/"+onlineCacheDirName;
    }
    /* 下载文件命名模板: 只认设计常量里的候选模板, 未设置或已不再提供的旧模板(例如旧的只取歌名一档)
     * 一律回到默认值; 读出来只用于新建下载文件, 已下载的文件名不会因此改变 */
    function downloadNameTemplate() {
        var t=uiState.downloadNameTemplate;
        if(typeof t!=="string" || Define.downloadNameTemplates.indexOf(t)<0) {
            return Define.downloadNameTemplate;
        }
        return t;
    }
    /* 写入下载文件命名模板: 空值或不在候选内的值回到默认值 */
    function setDownloadNameTemplate(t) {
        var v=(typeof t==="string"? t.trim():"");
        if(Define.downloadNameTemplates.indexOf(v)<0) {
            v=Define.downloadNameTemplate;
        }
        Assist.dlog("落盘","写入下载命名模板: ",v);
        uiState=_uiStateWith({"downloadNameTemplate":v});
        return saveUIState();
    }
    /* 在线歌曲的播放策略: 不下载(纯流式) 或 边播放边下载; 未设置时取不下载 */
    function onlinePlayStrategy() {
        return (uiState.onlinePlayStrategy===Define.playStrategyDownloadWhilePlaying
                ? Define.playStrategyDownloadWhilePlaying:Define.playStrategyNoDownload);
    }
    /* 写入在线播放策略: 非法值回到不下载 */
    function setOnlinePlayStrategy(v) {
        var n=(v===Define.playStrategyDownloadWhilePlaying? v:Define.playStrategyNoDownload);
        Assist.dlog("落盘","写入在线播放策略: ",n);
        uiState=_uiStateWith({"onlinePlayStrategy":n});
        return saveUIState();
    }
    /* 用户指定的下载目录: 未指定时返回空字符串, 表示使用存储目录下的默认目录 */
    function downloadsDirOverride() {
        var v=uiState.downloadsDir;
        return (typeof v==="string"? v:"");
    }
    /* 写入用户指定的下载目录: 传空字符串表示恢复默认;
     * 目录必须可写, 否则拒绝写入并保留原值 */
    function setDownloadsDir(p) {
        var raw=String(p===undefined || p===null? "":p).trim();
        var v="";
        if(raw!=="") {
            v=AppFileHelper.formatPath(raw);
            if(v==="") {
                Assist.dwarn("落盘","下载目录无效: ",raw);
                return false;
            }
            if(AppFileHelper.canWriteDir(v)===false) {
                Assist.dwarn("落盘","下载目录不可写: ",v);
                return false;
            }
        }
        Assist.dlog("落盘","写入下载目录: ",(v===""? "(默认)":v));
        uiState=_uiStateWith({"downloadsDir":v});
        return saveUIState();
    }
    /* 恢复默认下载目录 */
    function resetDownloadsDir() {
        return setDownloadsDir("");
    }
    /* 按在线标识取下载记录, 没有该项时返回 null */
    function downloadOf(onlineId) {
        var l=downloads.length;
        for(var i=0;i<l;i++) {
            if(downloads[i]["onlineId"]===onlineId) {
                return downloads[i];
            }
        }
        return null;
    }
    /* 按本地路径取下载记录: 已经下载成文件再播放的条目只有路径, 靠它回查在线标识, 没有时返回 null */
    function downloadOfPath(absfpath) {
        var p=String(absfpath===undefined || absfpath===null? "":absfpath);
        if(p==="") {
            return null;
        }
        var l=downloads.length;
        for(var i=0;i<l;i++) {
            if(String(downloads[i]["absfpath"])===p) {
                return downloads[i];
            }
        }
        return null;
    }
    /* 判断某个在线标识是否已下载 */
    function isDownloaded(onlineId) {
        return (downloadOf(onlineId)!==null);
    }
    /* 已下载且文件仍在的本地路径: 缺失时返回空字符串, 调用方据此退回在线播放 */
    function downloadedPathOf(onlineId) {
        var one=downloadOf(onlineId);
        if(one===null) {
            return "";
        }
        var p=one["absfpath"];
        if(typeof p!=="string" || p==="") {
            return "";
        }
        if(AppFileHelper.existsFile(p)===false) {
            return "";
        }
        return p;
    }
    /* 写入一条下载记录: 按在线标识去重后整体替换该条, 收尾写盘 */
    function addDownloaded(one) {
        if(one===undefined || one===null || one["onlineId"]===undefined || one["onlineId"]==="") {
            return false;
        }
        Assist.dlog("下载","记录下载完成: ",one["onlineId"]," -> ",one["absfpath"]);
        var res=[];
        var l=downloads.length;
        for(var i=0;i<l;i++) {
            if(downloads[i]["onlineId"]!==one["onlineId"]) {
                res.push(downloads[i]);
            }
        }
        res.push(one);
        downloads=res;
        saveDownloads();
        return true;
    }
    /* 移除一条下载记录: 只改记录, 不删除已下载的文件 */
    function removeDownloaded(onlineId) {
        Assist.dlog("下载","移除下载记录: ",onlineId);
        var res=[];
        var l=downloads.length;
        for(var i=0;i<l;i++) {
            if(downloads[i]["onlineId"]!==onlineId) {
                res.push(downloads[i]);
            }
        }
        downloads=res;
        return saveDownloads();
    }
    /* 只写下载记录 */
    function saveDownloads() {
        return writePayload(storageDirPath,downloadsFileName,downloads);
    }
}

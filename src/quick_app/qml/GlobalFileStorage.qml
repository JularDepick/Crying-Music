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
    /* 存储目录下必须齐全的许可文本, 缺失时从程序资源中补全 */
    property var licenseFileNames: ["COPYRIGHT","LICENSE","LICENSE.FDL","LICENSE.Qt"];
    /* 许可文本在程序资源中的目录, 与 licensesDirName 对应 */
    property string licenseResDir: ":/licenses/";
    /* 二进制运行目录下的存储目录指针文件, 记录上一次选定的存储目录 */
    property string storagePointerFileName: "storageDirPath.json";
    /* 落盘数据的结构版本号, 供将来做结构迁移 */
    property int dataVersion: 1;
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
    /* 播放状态枢纽: 播放队列, 当前播放项路径与下标, 播放顺序与播放进度; 跨模块只经此处交换 */
    /* 存到 #/data/playState.json */
    property var playState:
    ({
        sortlist: [],
        playingWhich: "",
        playingIndex: -1,
        playMode: 1,
        playingPosition: 0,
        volume: 100
    });
    /* 界面状态: 需要落盘的界面偏好, 目前是左侧栏展开状态与主内容区当前页面; 跨模块只经此处交换 */
    /* 存到 #/data/UI_State.json */
    property var uiState:
    ({
        leftSidebarSpreaded: true,
        mainAreaPage: "home"
    });
    /* 目录决策: 指针优先, 其次 A, 再 B, 最后兜底 C; 三个候选都不可用时退出应用。
     * 全过程输出 [存储目录] 前缀的日志, 便于在运行控制台里追决策路径 */
    function verifyStorageDir() {
        console.log("[存储目录] 决策开始");
        console.log("[存储目录] 候选 A(应用数据目录): ",dirLabel(storageDirPathA));
        console.log("[存储目录] 候选 B(用户目录): ",dirLabel(storageDirPathB));
        console.log("[存储目录] 候选 C(二进制运行目录): ",dirLabel(storageDirPathC));
        /* 1. 指针文件指向的目录仍存在且可写时直接沿用, 本次启动不做数据迁移;
         * 目录已消失时不沿用, 走完整决策, 避免用新建的空目录盖掉其它目录里的数据 */
        var remembered=readStoragePointer();
        if(remembered==="") {
            console.log("[存储目录] 指针: 没有可用指向, 走完整决策");
        } else {
            console.log("[存储目录] 指针: 指向 ",dirLabel(remembered));
        }
        if(remembered!=="" && AppFileHelper.existsDir(remembered)===true
           && writableDir(remembered)===true) {
            storageDirPath=remembered;
            ensureLicenses(remembered);
            console.log("[存储目录] 决策: 沿用指针指向的目录");
            console.log("[存储目录] 最终采用: ",dirLabel(storageDirPath));
            return true;
        }
        if(remembered!=="") {
            console.log("[存储目录] 指针指向的目录不可用, 继续按候选顺序判断");
        }
        var aReady=writableDir(storageDirPathA);
        var bReadable=readableDir(storageDirPathB);
        /* B 只在已存在且可读时才参与判定, 避免无谓地在用户目录下新建空目录 */
        var bReady=(bReadable===true && writableDir(storageDirPathB)===true);
        console.log("[存储目录] 判定结果: A 可写=",aReady,", B 可读=",bReadable,", B 可写=",bReady);
        /* 2. A 可用: 优先 A; 仅当 A 的许可文本不齐而 B 齐全时才改用 B */
        if(aReady===true) {
            if(hasLicenses(storageDirPathA)===false && hasLicenses(storageDirPathB)===true) {
                console.log("[存储目录] 决策: A 可写但许可文本不齐, B 齐全, 改用 B");
                return adoptStorageDir(storageDirPathB,[storageDirPathA]);
            }
            console.log("[存储目录] 决策: 优先采用 A");
            return adoptStorageDir(storageDirPathA,(bReadable===true? [storageDirPathB]:[]));
        }
        /* 3. A 不可用而 B 可用: 改用 B, A 可读时把数据并进 B */
        if(bReady===true) {
            console.log("[存储目录] 决策: A 不可写而 B 可用, 改用 B");
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
            console.log("[存储目录] 决策: A 与 B 都不可用, 兜底到 C");
            return adoptStorageDir(storageDirPathC,srcs);
        }
        /* 5. 三个候选都不可用: 报错并退出应用 */
        console.error("[存储目录] 错误: 三个候选都不可写, 程序退出");
        console.error("[存储目录]   A: ",dirLabel(storageDirPathA));
        console.error("[存储目录]   B: ",dirLabel(storageDirPathB));
        console.error("[存储目录]   C: ",dirLabel(storageDirPathC));
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
            console.log("[存储目录]   可读判定: (空路径) -> 否");
            return false;
        }
        var ok=(AppFileHelper.canReadDir(dir)===true);
        console.log("[存储目录]   可读判定: ",dirLabel(dir)," -> ",ok);
        return ok;
    }
    /* 候选目录是否可写: 不存在时先尝试递归创建; 空路径视为不可用 */
    function writableDir(dir) {
        if(dir==="") {
            console.log("[存储目录]   可写判定: (空路径) -> 否");
            return false;
        }
        if(AppFileHelper.existsDir(dir)===false) {
            console.log("[存储目录]   可写判定: ",dirLabel(dir)," 不存在, 尝试创建");
            if(AppFileHelper.makeDir(dir,true)===false) {
                console.warn("[存储目录]   可写判定: 目录创建失败: ",dirLabel(dir));
                return false;
            }
            console.log("[存储目录]   可写判定: 目录已创建");
        }
        var ok=(AppFileHelper.canWriteDir(dir)===true);
        console.log("[存储目录]   可写判定: ",dirLabel(dir)," -> ",ok);
        return ok;
    }
    /* 采用某个目录作为存储目录: 合并来源目录的数据, 补齐许可文本, 写入指针 */
    function adoptStorageDir(dir,sources) {
        console.log("[存储目录] 采用: ",dirLabel(dir),", 来源目录 ",sources.length," 个");
        storageDirPath=dir;
        var l=sources.length;
        for(var i=0;i<l;i++) {
            mergeDataFrom(sources[i],dir);
        }
        ensureLicenses(dir);
        writeStoragePointer(dir);
        console.log("[存储目录] 最终采用: ",dirLabel(storageDirPath));
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
            console.log("[存储目录]   许可文本不全: ",dirLabel(dir),", 缺少 ",missing.join(", "));
            return false;
        }
        console.log("[存储目录]   许可文本齐全: ",dirLabel(dir));
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
                    console.error("[存储目录] 许可文本补全失败: ",dirLabel(dst));
                } else {
                    console.log("[存储目录] 许可文本已补全: ",licenseFileNames[i]);
                    copied=copied+1;
                }
            }
        }
        console.log("[存储目录] 许可文本检查完成, 本次补全 ",copied," 个");
        return true;
    }
    /* 读取存储目录指针: 文件缺失或内容损坏时返回空字符串 */
    function readStoragePointer() {
        var f=storageDirPathC+"/"+storagePointerFileName;
        if(storageDirPathC==="") {
            console.log("[存储目录] 指针: 候选 C 为空, 无法定位指针文件");
            return "";
        }
        if(AppFileHelper.existsFile(f)===false) {
            console.log("[存储目录] 指针: 文件不存在 ",dirLabel(f));
            return "";
        }
        var txt=AppFileHelper.readFile(f,"UTF-8");
        if(txt==="") {
            console.log("[存储目录] 指针: 文件为空 ",dirLabel(f));
            return "";
        }
        var obj=null;
        try {
            obj=JSON.parse(txt);
        } catch(e) {
            console.warn("[存储目录] 指针解析失败: ",e);
            return "";
        }
        if(obj===null || obj===undefined || typeof obj.storageDirPath!=="string") {
            console.log("[存储目录] 指针: 内容缺少 storageDirPath 字段");
            return "";
        }
        return obj.storageDirPath;
    }
    /* 写入存储目录指针: 写入失败不影响本次运行 */
    function writeStoragePointer(dir) {
        if(storageDirPathC==="" || dir==="") {
            console.log("[存储目录] 指针: 候选 C 或目标为空, 跳过写入");
            return false;
        }
        var f=storageDirPathC+"/"+storagePointerFileName;
        var txt=JSON.stringify({"version":dataVersion,"storageDirPath":dir});
        if(AppFileHelper.writeFile(f,txt,"UTF-8")===false) {
            console.warn("[存储目录] 指针写入失败: ",dirLabel(f));
            return false;
        }
        console.log("[存储目录] 指针已写入: ",dirLabel(f));
        return true;
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
            console.warn("数据文件解析失败: ",f,e);
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
            console.warn("保存失败: 存储目录未确定");
            return false;
        }
        var f=dir+"/"+dataDirName+"/"+fileName;
        var txt=JSON.stringify({"version":dataVersion,"payload":payload});
        return AppFileHelper.writeFile(f,txt,"UTF-8");
    }
    /* 数据迁移: 目标目录数据为主, 来源目录做并集补齐; 结果直接写回目标目录 */
    function mergeDataFrom(srcDir,dstDir) {
        if(srcDir==="" || dstDir==="" || srcDir===dstDir) {
            return false;
        }
        console.log("[存储目录] 迁移数据: ",dirLabel(srcDir)," -> ",dirLabel(dstDir));
        mergeLocalScan(srcDir,dstDir);
        mergePathList(srcDir,dstDir,likedFilesFileName);
        mergePathList(srcDir,dstDir,recentFilesFileName);
        mergeWholePayload(srcDir,dstDir,playStateFileName);
        mergeWholePayload(srcDir,dstDir,uiStateFileName);
        console.log("[存储目录] 迁移完成: ",dirLabel(srcDir)," -> ",dirLabel(dstDir));
        return true;
    }
    /* 路径列表合并: 目标在前, 来源独有的项按原顺序追加 */
    function unionPaths(main,other) {
        var res=(main===null || main===undefined? []:main.slice());
        if(other===null || other===undefined) {
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
    /* 合并一个路径数组数据文件 */
    function mergePathList(srcDir,dstDir,fileName) {
        var src=readPayload(srcDir,fileName);
        if(src===null) {
            console.log("[存储目录]   合并 ",fileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        var dst=readPayload(dstDir,fileName);
        if(dst===null) {
            console.log("[存储目录]   合并 ",fileName,": 目标目录没有该文件, 直接采用来源的 ",src.length," 项");
            return writePayload(dstDir,fileName,src);
        }
        var merged=unionPaths(dst,src);
        console.log("[存储目录]   合并 ",fileName,": 目标 ",dst.length," 项, 来源 ",src.length," 项, 结果 ",merged.length," 项");
        return writePayload(dstDir,fileName,merged);
    }
    /* 扫描文件夹清单合并: 以文件夹路径为唯一标识, 目标目录的勾选状态优先 */
    function unionScanDirs(main,other) {
        var res=[];
        var l=(main===null || main===undefined? 0:main.length);
        for(var i=0;i<l;i++) {
            res.push({"absdpath":main[i]["absdpath"],"included":(main[i]["included"]===true)});
        }
        if(other===null || other===undefined) {
            return res;
        }
        var lo=other.length;
        for(var j=0;j<lo;j++) {
            var one=other[j];
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
            console.log("[存储目录]   合并 ",localScanFileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        var dst=readPayload(dstDir,localScanFileName);
        if(dst===null) {
            console.log("[存储目录]   合并 ",localScanFileName,": 目标目录没有该文件, 直接采用来源的");
            return writePayload(dstDir,localScanFileName,src);
        }
        var res=({});
        res.singleFiles=unionPaths(dst.singleFiles,src.singleFiles);
        res.excludedFiles=unionPaths(dst.excludedFiles,src.excludedFiles);
        res.scanFmts=unionPaths(dst.scanFmts,src.scanFmts);
        res.scanDirs=unionScanDirs(dst.scanDirs,src.scanDirs);
        res.scanRadio=(dst.scanRadio===undefined? src.scanRadio:dst.scanRadio);
        console.log("[存储目录]   合并 ",localScanFileName,": 手动歌曲 ",res.singleFiles.length,
                    " 项, 扫描文件夹 ",res.scanDirs.length," 个, 格式 ",res.scanFmts.length,
                    " 个, 移除项 ",res.excludedFiles.length," 项, 时长下限 ",res.scanRadio);
        return writePayload(dstDir,localScanFileName,res);
    }
    /* 合并整份数据: 目标目录有该文件时整体以目标为准, 否则采用来源目录的;
     * 播放状态与界面状态都走这条规则 */
    function mergeWholePayload(srcDir,dstDir,fileName) {
        if(readPayload(dstDir,fileName)!==null) {
            console.log("[存储目录]   合并 ",fileName,": 目标目录已有该文件, 以目标为准");
            return false;
        }
        var src=readPayload(srcDir,fileName);
        if(src===null) {
            console.log("[存储目录]   合并 ",fileName,": 来源目录没有该文件, 跳过");
            return false;
        }
        console.log("[存储目录]   合并 ",fileName,": 采用来源目录的整份内容");
        return writePayload(dstDir,fileName,src);
    }
    /* 读取落盘数据: 存储目录未确定或数据文件缺失时保持默认值 */
    function load() {
        if(storageDirPath==="") {
            console.warn("加载失败: 存储目录未确定");
            return false;
        }
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
        var ps=readPayload(storageDirPath,playStateFileName);
        if(ps!==null) {
            playState=({"sortlist":(Array.isArray(ps.sortlist)===true? ps.sortlist:[]),
                        "playingWhich":(typeof ps.playingWhich==="string"? ps.playingWhich:""),
                        "playingIndex":(typeof ps.playingIndex==="number"? ps.playingIndex:-1),
                        "playMode":(typeof ps.playMode==="number"? ps.playMode:1),
                        "playingPosition":(typeof ps.playingPosition==="number"? ps.playingPosition:0),
                        "volume":(typeof ps.volume==="number"? ps.volume:100)});
        }
        var us=readPayload(storageDirPath,uiStateFileName);
        if(us!==null) {
            /* 只有明确写成 false 才算折叠, 其余情况按展开处理; 页面键缺失或非法时回到首页 */
            uiState=({"leftSidebarSpreaded":(us.leftSidebarSpreaded!==false),
                       "mainAreaPage":(typeof us.mainAreaPage==="string" && us.mainAreaPage!==""? us.mainAreaPage:"home")});
        }
        console.log("读取落盘数据完成: ",storageDirPath);
        return true;
    }
    /* 写入全部落盘数据: 退出与数据迁移时使用 */
    function save() {
        if(storageDirPath==="") {
            console.warn("保存失败: 存储目录未确定");
            return false;
        }
        writePayload(storageDirPath,localScanFileName,localScan);
        writePayload(storageDirPath,likedFilesFileName,likedFiles);
        writePayload(storageDirPath,recentFilesFileName,recentFiles);
        writePayload(storageDirPath,playStateFileName,playState);
        writePayload(storageDirPath,uiStateFileName,uiState);
        return true;
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
    /* 整体写回扫描规则 */
    function setMALocalP(a,b,c) {
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
    /* 设置喜欢状态 */
    function setLiked(absfpath,on) {
        likedFiles=setPath(likedFiles,absfpath,on);
        saveLiked();
    }
    /* 判断路径是否已喜欢 */
    function isLiked(absfpath) {
        return hasPath(likedFiles,absfpath);
    }
    /* 批量取消喜欢 */
    function removeLiked(absfpaths) {
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
                 "volume":(playState.volume===undefined? 100:playState.volume)});
        for(var k in overrides) {
            st[k]=overrides[k];
        }
        return st;
    }
    /* 写入播放状态: 队列, 当前播放项与播放顺序一起写, 播放进度与音量沿用枢纽当前值 */
    function setPlayState(list,which,index,mode) {
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
        playState=_playStateWith({"volume":vol});
        savePlayState();
    }
    /* 按当前界面状态生成一份新对象, 只覆盖传入的字段;
     * 一律整体替换, 使外部能收到变更通知 */
    function _uiStateWith(overrides) {
        var st=({"leftSidebarSpreaded":(uiState.leftSidebarSpreaded!==false),
                 "mainAreaPage":(uiState.mainAreaPage===undefined? "home":uiState.mainAreaPage)});
        for(var k in overrides) {
            st[k]=overrides[k];
        }
        return st;
    }
    /* 写入左侧栏展开状态: 只改这一项, 其余界面状态保持不变 */
    function setLeftSidebarSpreaded(on) {
        uiState=_uiStateWith({"leftSidebarSpreaded":(on===true)});
        saveUIState();
    }
    /* 写入主内容区当前页面: 只改这一项, 其余界面状态保持不变; 入参为页面路由键 */
    function setMainAreaPage(route) {
        if(route===undefined || route==="") {
            return false;
        }
        uiState=_uiStateWith({"mainAreaPage":route});
        return saveUIState();
    }
}

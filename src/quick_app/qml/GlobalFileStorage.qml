pragma Singleton
import QtQuick

Item {
    property var localScan:
    ({
        singleFiles: [],
        scanDirs: [],
        scanFmts: [],
        scanRadio: 0
    });
    function load() {
    }
    function save() {
    }
    function setMALocalP(a,b,c) {
        localScan.scanDirs=a;
        localScan.scanFmts=b;
        localScan.scanRadio=c;
    }
}

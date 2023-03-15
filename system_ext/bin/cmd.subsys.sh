#! /system/bin/sh

option="$1"

function copyDcsOlog() {
    timeStamp=`date "+%Y_%m_%d_%H_%M_%S"`
    fieldNum=`cat /proc/sys/kernel/random/uuid`
    otaVersion=`getprop ro.build.version.ota`
    dcsZipName="olog@"${fieldNum:0-12:12}@${otaVersion}@${timeStamp}".zip"
    dcsLogPath="/data/persist_log/DCS/de/olog"
    dcsLimitSize="102400"
    dcsCurrentSize=`du -s -k ${dcsLogPath} | awk '{print $1}'`
    if [[ ${dcsCurrentSize} -le ${dcsLimitSize} ]]; then
        mv -f /sdcard/.dcs_olog ${dcsLogPath}/${dcsZipName}
    else
        rm -f /sdcard/.dcs_olog
        echo "full_lost" > ${dcsLogPath}/${dcsZipName}
    fi
    chmod 0777 ${dcsLogPath}/${dcsZipName}
    chown system:system ${dcsLogPath}/${dcsZipName}
}

case "$option" in
    "copyDcsOlog")
        copyDcsOlog
        ;;
    *)
        ;;
esac

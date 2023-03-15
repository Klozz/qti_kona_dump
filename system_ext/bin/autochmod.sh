#! /system/bin/sh

CURTIME=`date +%F_%H-%M-%S`
CURTIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S"`

BASE_PATH=/sdcard/Android/data/com.oplus.olc
SDCARD_LOG_BASE_PATH=${BASE_PATH}/files/Log
SDCARD_LOG_TRIGGER_PATH=${BASE_PATH}/trigger

DATA_DEBUGGING_PATH=/data/debugging
DATA_OPLUS_LOG_PATH=/data/persist_log
ANR_BINDER_PATH=${DATA_DEBUGGING_PATH}/anr_binder_info
CACHE_PATH=${DATA_DEBUGGING_PATH}/cache

config="$1"

#================================== COMMON LOG =========================

function backup_unboot_log(){
    CACHE_EMPTY=`ls ${CACHE_PATH} | wc -l`
    if [ "${CACHE_EMPTY}" == "0" ];then
        return
    fi

    CACHE_PATH_FILES=`ls ${CACHE_PATH}/*`
    if [ "${CACHE_PATH_FILES}" = "" ];then
        traceTransferState "CACHE_PATH is empty"
    else
        traceTransferState "mv ${CACHE_PATH} TO ${DATA_DEBUGGING_PATH}/unboot"
        mv ${CACHE_PATH} ${DATA_DEBUGGING_PATH}/unboot
    fi
}

function initcache(){
    traceTransferState "initcache..."
    BOOT_MODE=`getprop sys.oplus_boot_mode`
    if [ x"${BOOT_MODE}" = x"ftm_at" ]; then
        traceTransferState "bootMode:${BOOT_MODE}, return!!!"
        return
    fi
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    boot_completed=`getprop sys.boot_completed`
    if [[ x"${panicenable}" = x"true" ]] || [[ x"${camerapanic}" = x"true" ]] && [[ x"${boot_completed}" != x"1" ]]; then
        if [ ! -d /dev/log ];then
            mkdir -p /dev/log
            chmod -R 755 /dev/log
        fi
        backup_unboot_log
        traceTransferState "INITCACHE: mkdir ${CACHE_PATH}"
        mkdir -p ${CACHE_PATH}
        mkdir -p ${CACHE_PATH}/apps
        mkdir -p ${CACHE_PATH}/kernel
        mkdir -p ${CACHE_PATH}/netlog
        mkdir -p ${CACHE_PATH}/fingerprint
        chmod -R 777 ${CACHE_PATH}
        setprop sys.oplus.collectcache.start true
    fi
}

# 10M*5
function logcatcache() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    if [[ "${panicenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        traceTransferState "panicenable: ${panicenable}"
        logdsize=`getprop persist.logd.size`
        if [ "${logdsize}" = "" ]; then
            /system/bin/logcat -G 16M
        fi
        /system/bin/logcat -b main -b system -b crash -f ${CACHE_PATH}/apps/android_boot.txt -r 10240 -n 5 -v threadtime
    fi
}

# 4M*3
function radiocache() {
    radioenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    if [[ "${radioenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        /system/bin/logcat -b radio -f ${CACHE_PATH}/apps/radio_boot.txt -r 4096 -n 3 -v threadtime
    fi
}

# 4M*10
function eventcache() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    if [[ "${panicenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        /system/bin/logcat -b events -f ${CACHE_PATH}/apps/events_boot.txt -r 4096 -n 10 -v threadtime
    fi
}

# 10M*5
function kernelcache() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    RELEASE_TYPE=`getprop ro.build.release_type`
    if [[ "${panicenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        dmesg > ${CACHE_PATH}/kernel/dmesg_boot.txt
        cat proc/boot_dmesg > ${CACHE_PATH}/kernel/uboot.txt
        cat proc/bootloader_log > ${CACHE_PATH}/kernel/bootloader.txt
        cat /sys/pmic_info/pon_reason > ${CACHE_PATH}/kernel/pon_poff_reason.txt
        cat /sys/pmic_info/poff_reason >> ${CACHE_PATH}/kernel/pon_poff_reason.txt
        cat /sys/pmic_info/ocp_status >> ${CACHE_PATH}/kernel/pon_poff_reason.txt
        if [ x"${RELEASE_TYPE}" != x"true" ]; then
            /system/bin/logcat -b kernel -f ${CACHE_PATH}/kernel/kernel_boot.txt -r 10240 -n 5 -v threadtime -A
        else
            /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${CACHE_PATH}/kernel/kernel_boot.txt | awk 'NR%400==0'
        fi
    fi
}

#================================== COMMON LOG =========================

#================================== POWER =========================
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get dmesg at O
function kernelcacheforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  chmod 777 -R ${DATA_DEBUGGING_PATH}/

  mkdir -p /data/oplus/psw/powermonitor
  chmod 777 -R /data/oplus/psw/powermonitor
  chmod 777 -R ${opmlogpath}

  temp_kernel_dir=${DATA_DEBUGGING_PATH}/powermonitor_temp/kernel

  mkdir -p ${temp_kernel_dir}
  chown system:system ${temp_kernel_dir}
  chmod 777 -R ${DATA_DEBUGGING_PATH}/powermonitor_temp
  chmod 777 -R ${temp_kernel_dir}

  touch ${temp_kernel_dir}/dmesg.txt
  chown system:system ${temp_kernel_dir}/dmesg.txt
  chmod 777 -R ${temp_kernel_dir}/dmesg.txt

  dmesg > ${temp_kernel_dir}/dmesg.txt

  cp ${temp_kernel_dir}/dmesg.txt ${opmlogpath}dmesg.txt
  chown system:system ${opmlogpath}dmesg.txt

  chmod 777 -R ${opmlogpath}dmesg.txt

  rm -rf ${DATA_DEBUGGING_PATH}/powermonitor_temp/kernel
  
}
#Jianfa.Chen@PSW.AD.PowerMonitor,add for powermonitor getting Xlog
function catchWXlogForOpm() {
  currentDateWXlog=$(date "+%Y%m%d")
  newpath=`getprop sys.opm.logpath`

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"

  mkdir -p ${newpath}/wxlog
  chmod 777 -R ${newpath}/wxlog
  #wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/xlog
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/xlog/
    done
  fi

  if [ -d "${CRASH_DIR}" ];then
    mkdir -p ${newpath}/wxlog/crash
    ALL_FILE = $(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE;do
      cp $file ${newpath}/wxlog/crash
    done
  fi
  chown -R system:system ${newpath}
}

# Qiurun.Zhou@ANDROID.DEBUG, 2022/6/17, copy wxlog for EAP
function eapCopyWXlog() {
  currentDateWXlog=$(date "+%Y%m%d")
  newpath=`getprop sys.opm.logpath`

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"

  mkdir -p ${newpath}/wxlog
  chmod 777 -R ${newpath}/wxlog
  #wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/xlog
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/xlog/
    done
  fi

  if [ -d "${CRASH_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/crash
    ALL_FILE=$(find ${CRASH_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/crash/
    done
  fi
  chown -R system:system ${newpath}
}

function catchQQlogForOpm() {
  currentDateQlog=$(date "+%y.%m.%d")
  newpath=`getprop sys.opm.logpath`
  QLOG_DIR="/sdcard/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq"
  #qlog
  mkdir -p ${newpath}/qlog
  chmod 777 -R ${newpath}/qlog
  if [ -d "${QLOG_DIR}" ]; then
    mkdir -p ${newpath}/qlog/log
    ALL_FILE=$(find ${QLOG_DIR} | grep -E ${currentDateQlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/qlog
    done
  fi
  chown -R system:system ${newpath}
}

function catchClockForOpm() {
  opmlogpath=`getprop sys.opm.logpath`
  if [ -f /proc/power/clk_enabled_list ]
  then
    cat /proc/power/clk_enabled_list > ${opmlogpath}clk_enabled_list.txt
    chown system:system ${opmlogpath}clk_enabled_list.txt
    chmod 777 -R ${opmlogpath}clk_enabled_list.txt
  fi
  if [ -f /proc/clk/clk_enabled_list ]
  then
    cat /proc/clk/clk_enabled_list > ${opmlogpath}clk_enabled_list.txt
    chown system:system ${opmlogpath}clk_enabled_list.txt
    chmod 777 -R ${opmlogpath}clk_enabled_list.txt
  fi
}


function startSsLogPower() {
    traceTransferState "startSsLogPower"
    powermonitorCustomLogDir=${DATA_DEBUGGING_PATH}/powermonitor_custom_log
    
    if [ ! -d "${powermonitorCustomLogDir}" ];then
        mkdir -p ${powermonitorCustomLogDir}
    fi
    ssLogOutputPath=${powermonitorCustomLogDir}/sslog.txt

    while [ -d "$powermonitorCustomLogDir" ]
    do
       ss -ntp -o state established >> ${ssLogOutputPath}
       sleep 15s #Sleep 15 seconds
    done
    traceTransferState "startSsLogPower_End"
}

function tranferPowerRelated() {
  traceTransferState "tranferPowerRelated"
  powerExtraLogDir="/data/oplus/psw/powermonitor_backup/extra_log";
  powermonitorCustomLogDir=${DATA_DEBUGGING_PATH}/powermonitor_custom_log
  if [ ! -d "${powerExtraLogDir}" ];then
    mkdir -p ${powerExtraLogDir}
  fi
  
  chown system:system ${powerExtraLogDir}
  chmod 777 -R ${powerExtraLogDir}/

  #collect bluetooth log
  buletoothLogSaveDir="${powerExtraLogDir}/buletooth_log";
  if [ ! -d "${buletoothLogSaveDir}" ];then
    mkdir -p ${buletoothLogSaveDir}
  fi

  tar cvzf ${buletoothLogSaveDir}/buletooth_log.tar.gz /data/misc/bluetooth/
  traceTransferState "get bluetooth log"

  #collect sslog
  sslogSourcPath=${powermonitorCustomLogDir}/sslog.txt
  if [ -f "${sslogSourcPath}" ];then
    cp ${sslogSourcPath} ${powerExtraLogDir}/sslog.txt
    traceTransferState "get sslog"
  fi

  chown system:system ${powerExtraLogDir}
  chmod 777 -R ${powerExtraLogDir}/
  
  #clear file
  rm ${sslogSourcPath}
  traceTransferState "tranferPowerRelated_end"
}

#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get Sysinfo at O
function psforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  ps -A -T > ${opmlogpath}psO.txt
  chown system:system ${opmlogpath}psO.txt
}
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2019/08/21, Add for OplusPowerMonitor get qrtr at Qcom
function qrtrlookupforopm() {
    echo "qrtrlookup begin"
    opmlogpath=`getprop sys.opm.logpath`
    if [ -d "/d/ipc_logging" ]; then
        echo ${opmlogpath}
        /vendor/bin/qrtr-lookup > ${opmlogpath}/qrtr-lookup_info.txt
        chown system:system ${opmlogpath}/qrtr-lookup_info.txt
    fi
    echo "qrtrlookup end"
}

function cpufreqforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/devices/system/cpu/*/cpufreq/scaling_cur_freq > ${opmlogpath}cpufreq.txt
  chown system:system ${opmlogpath}cpufreq.txt
}

function logcatMainCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  temp_android_dir=${DATA_DEBUGGING_PATH}/powermonitor_temp/android
  mkdir -p ${temp_android_dir}
  logcat -d -f ${temp_android_dir}/logcat.txt -r 4096 -n 1 -v threadtime
  cp ${temp_android_dir}/* ${opmlogpath}
  chown system:system ${opmlogpath}logcat*
  rm -rf ${DATA_DEBUGGING_PATH}/powermonitor_temp/android
}

function logcatEventCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b events -d > ${opmlogpath}events.txt
  chown system:system ${opmlogpath}events.txt
}

function logcatRadioCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b radio -d > ${opmlogpath}radio.txt
  chown system:system ${opmlogpath}radio.txt
}

function catchBinderInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/kernel/debug/binder/state > ${opmlogpath}binderinfo.txt
  chown system:system ${opmlogpath}binderinfo.txt
}

function catchBattertFccForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/class/power_supply/battery/batt_fcc > ${opmlogpath}fcc.txt
  chown system:system ${opmlogpath}fcc.txt
}

function catchTopInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  opmfilename=`getprop sys.opm.logpath.filename`
  top -H -n 3 > ${opmlogpath}${opmfilename}top.txt
  chown system:system ${opmlogpath}${opmfilename}top.txt
}

function dumpsysHansHistoryForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys activity hans history > ${opmlogpath}hans.txt
  chown system:system ${opmlogpath}hans.txt
  dumpsys activity service com.oplus.battery deepsleepRcd > ${opmlogpath}deepsleepRcd.txt
  chown system:system ${opmlogpath}deepsleepRcd.txt
}

function dumpsysSurfaceFlingerForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysSensorserviceForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysBatterystatsForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats > ${opmlogpath}batterystats.txt
  chown system:system ${opmlogpath}batterystats.txt
}

function dumpsysBatterystatsOplusCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats --oplusCheckin > ${opmlogpath}batterystats_oplusCheckin.txt
  chown system:system ${opmlogpath}batterystats_oplusCheckin.txt
}

function dumpsysBatterystatsCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats -c > ${opmlogpath}batterystats_checkin.txt
  chown system:system ${opmlogpath}batterystats_checkin.txt
}

function dumpsysMediaForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys media.audio_flinger > ${opmlogpath}audio_flinger.txt
  dumpsys media.audio_policy > ${opmlogpath}audio_policy.txt
  dumpsys audio > ${opmlogpath}audio.txt

  chown system:system ${opmlogpath}audio_flinger.txt
  chown system:system ${opmlogpath}audio_policy.txt
  chown system:system ${opmlogpath}audio.txt
}

function getPropForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  getprop > ${opmlogpath}prop.txt
  chown system:system ${opmlogpath}prop.txt
}

function logcusMainForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/bin/logcat -f ${opmlogpath}/android.txt -r 10240 -n 5 -v threadtime *:V
}

function logcusEventForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/bin/logcat -b events -f ${opmlogpath}/event.txt -r 10240 -n 5 -v threadtime *:V
}

function logcusRadioForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/bin/logcat -b radio -f ${opmlogpath}/radio.txt -r 10240 -n 5 -v threadtime *:V
}

function logcusKernelForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${opmlogpath}/kernel.txt | awk 'NR%400==0'
}

function logcusTCPForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    tcpdump -i any -p -s 0 -W 1 -C 50 -w ${opmlogpath}/tcpdump.pcap
}

function customDiaglogForOpm() {
    echo "customdiaglog opm begin"
    opmlogpath=`getprop sys.opm.logpath`
    mv ${DATA_DEBUGGING_PATH}/diag_logs ${opmlogpath}
    chmod 777 -R ${opmlogpath}
    restorecon -RF ${opmlogpath}
    echo "customdiaglog opm end"
}

#================================== POWER =========================

#================================== PERFORMANCE =========================
function dmaprocsforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/dma_buf/dmaprocs > ${opmlogpath}dmaprocs.txt
  cat /proc/osvelte/dma_buf/bufinfo >> ${opmlogpath}dmaprocs.txt
  cat /proc/osvelte/dma_buf/procinfo >> ${opmlogpath}dmaprocs.txt
  chown system:system ${opmlogpath}dmaprocs.txt
}
function slabinfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/slabinfo > ${opmlogpath}slabinfo.txt
  cat /sys/kernel/debug/page_owner > ${opmlogpath}pageowner.txt
  chown system:system ${opmlogpath}slabinfo.txt
  chown system:system ${opmlogpath}pageowner.txt
}
function svelteforhealth(){
    sveltetracer=`getprop sys.opm.svelte_tracer`
    svelteops=`getprop sys.opm.svelte_ops`
    svelteargs=`getprop sys.opm.svelte_args`
    opmlogpath=`getprop sys.opm.logpath`

    if [ "${sveltetracer}" == "malloc" ]; then
        if [ "${svelteops}" == "enable" ]; then
            osvelte malloc-debug -e ${svelteargs}
        elif [ "${svelteops}" == "dump" ]; then
            osvelte malloc-debug -d ${svelteargs} > ${opmlogpath}malloc_${svelteargs}_svelte.txt
            sleep 12
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "vmalloc" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/vmallocinfo > ${svelteargs}
            sleep 12
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "slab" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/slabinfo > ${svelteargs}
            sleep 5
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "kernelstack" ]; then
        if [ "${svelteops}" == "dump" ]; then
            ps -A -T > ${svelteargs}
            sleep 5
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "ion" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/osvelte/dma_buf/bufinfo > ${svelteargs}
            cat /proc/osvelte/dma_buf/procinfo >> ${svelteargs}
            sleep 5
            chown system:system ${opmlogpath}*svelte.txt
        fi
    fi
}
function meminfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/meminfo > ${opmlogpath}meminfo.txt
  chown system:system ${opmlogpath}meminfo.txt
}

#================================== PERFORMANCE =========================

#================================== NETWORK =========================
function tcpdumpcache(){
    tcpdmpenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${tcpdmpenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
        tcpdump -i any -p -s 0 -W 2 -C 10 -w ${CACHE_PATH}/netlog/tcpdump_boot -Z root
    fi
}

function tcpDumpLog(){
    #panicenable=`getprop persist.sys.assert.panic`
    DATA_LOG_TCPDUMPLOG_PATH=`getprop sys.oplus.logkit.netlog`
    #LiuHaipeng@NETWORK.DATA, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    traceTransferState "tcpDumpLog tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount} tcpdumpPacketSize=${tcpdumpPacketSize} DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_TCPDUMPLOG_PATH}"
    if [ "${tmpTcpdump}" != "" ]; then
        #ifndef OPLUS_FEATURE_TCPDUMP
        #DuYuanhua@NETWORK.DATA.2959182, keep root priviledge temporarily for rutils-remove action
        #tcpdump -i any -p -s 0 -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump -Z root
        #else
        #LiuHaipeng@NETWORK.DATA, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
        tcpdump -i any -p -s ${tcpdumpPacketSize} -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump
        #endif
    fi
}
#================================== NETWORK =========================

#================================== FINGERPRINT =========================
function fingerprintcache(){
    platform=`getprop ro.board.platform`
    echo "platform ${platform}"
    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/log > ${CACHE_PATH}/fingerprint/fingerprint_boot.txt
        if [ -f /proc/tzdbg/log ]
        then
            cat /proc/tzdbg/log > ${CACHE_PATH}/fingerprint/fingerprint_boot.txt
        fi
    fi
}

function fplogcache(){
    platform=`getprop ro.board.platform`

    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/qsee_log > ${CACHE_PATH}/fingerprint/qsee_boot.txt
        if [ -f /proc/tzdbg/qsee_log ]
        then
            cat /proc/tzdbg/qsee_log > ${CACHE_PATH}/fingerprint/qsee_boot.txt
        fi
    fi
}

function fingerprintLog(){
    countfp=1
    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

    echo "fingerprint state = ${state}; logEncrState = ${logEncrState}"
    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        FP_LOG_PATH=`getprop sys.oplus.logkit.fingerprintlog`
        echo "fingerprint in loop"
        while true
        do
            cat /sys/kernel/debug/tzdbg/log > ${FP_LOG_PATH}/fingerprint_log${countfp}.txt
            if [ -f /proc/tzdbg/log ]
            then
                cat /proc/tzdbg/log > ${FP_LOG_PATH}/fingerprint_log${countfp}.txt
            fi
            if [ ! -s ${FP_LOG_PATH}/fingerprint_log${countfp}.txt ];then
                rm ${FP_LOG_PATH}/fingerprint_log${countfp}.txt;
            fi
            ((countfp++))
            sleep 1
        done
    fi
}

function fingerprintQseeLog(){
    countqsee=1
    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

    echo "fingerprint state = ${state}; logEncrState = ${logEncrState}"
    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        FP_LOG_PATH=`getprop sys.oplus.logkit.fingerprintlog`
        echo "fingerprint qsee in loop"
        while true
        do
            cat /sys/kernel/debug/tzdbg/qsee_log > ${FP_LOG_PATH}/qsee_log${countqsee}.txt
            if [ -f /proc/tzdbg/qsee_log ]
            then
                cat /proc/tzdbg/qsee_log > ${FP_LOG_PATH}/qsee_log${countqsee}.txt
            fi
            if [ ! -s ${FP_LOG_PATH}/qsee_log${countqsee}.txt ];then
                rm ${FP_LOG_PATH}/qsee_log${countqsee}.txt;
            fi
            ((countqsee++))
            sleep 1
        done
    fi
}
#================================== FINGERPRINT =========================

#================================== COMMON LOG =========================
function initOplusLog(){
    if [ ! -d /dev/log ];then
        mkdir -p /dev/log
        chmod -R 755 /dev/log
    fi

    traceTransferState "INITOPLUSLOG: start..."

    # TODO less 2G stop logcat, return
    PANICE_NABLE=`getprop persist.sys.assert.panic`
    CAMERA_PANIC_ENABLE=`getprop persist.sys.assert.panic.camera`
    BOOT_MODE=`getprop sys.oplus_boot_mode`
    if [ "${PANICE_NABLE}" = "true" ] || [ x"${CAMERA_PANIC_ENABLE}" = x"true" ]; then
        boot_completed=`getprop sys.boot_completed`
        decrypt_delay=0
        bootCompleteCount=0
        while [ x${boot_completed} != x"1" ];do
            bootCompleteCount=$((bootCompleteCount + 1))
            sleep 1
            decrypt_delay=`expr $decrypt_delay + 1`
            boot_completed=`getprop sys.boot_completed`
            if [ bootCompleteCount -ge 5 ] && [ x"${BOOST_MODE}" = x"ftm_at" ]; then
                break
            fi
        done
        traceTransferState "sleep time: ${bootCompleteCount}"

        echo "start mkdir"
        DATA_LOG_DEBUG_PATH=${DATA_DEBUGGING_PATH}/${CURTIME}
        mkdir -p  ${DATA_LOG_DEBUG_PATH}
        chmod -R 777 ${DATA_LOG_DEBUG_PATH}

        mkdir -p  ${ANR_BINDER_PATH}
        chmod -R 777 ${ANR_BINDER_PATH}
        chown system:system ${ANR_BINDER_PATH}

        decrypt='false'
        if [ x"${decrypt}" != x"true" ]; then
            setprop ctl.stop logcatcache
            setprop ctl.stop radiocache
            setprop ctl.stop eventcache
            setprop ctl.stop kernelcache
            setprop ctl.stop fingerprintcache
            setprop ctl.stop fplogcache
            setprop ctl.stop tcpdumpcache
            traceTransferState "INITOPLUSLOG: mv cache log..."
            mv ${CACHE_PATH}/* ${DATA_LOG_DEBUG_PATH}/
            mv ${DATA_DEBUGGING_PATH}/unboot ${DATA_LOG_DEBUG_PATH}/
        fi

        setprop persist.sys.com.oplus.debug.time ${CURTIME}
        echo ${CURTIME} >> ${DATA_DEBUGGING_PATH}/log_history.txt
        echo ${CURTIME} >> ${DATA_DEBUGGING_PATH}/transfer_list.txt
        traceTransferState "INITOPLUSLOG:start debug time: ${CURTIME}"

        #setprop sys.oplus.collectlog.start true
        startCatchLog
    fi
}

function copyCamDcsLog() {
    timeStamp=`date "+%Y_%m_%d_%H_%M_%S"`
    fieldNum=`cat /proc/sys/kernel/random/uuid`
    otaVersion=`getprop ro.build.version.ota`
    dcsZipName="olog@"${fieldNum:0-12:12}@${otaVersion}@${timeStamp}".zip"
    dcsLogPath="/data/persist_log/DCS/de/camera"
    if [ ! -d "${dcsLogPath}" ]; then
        mkdir ${dcsLogPath}
        chown system:system ${dcsLogPath}
        chmod 777 ${dcsLogPath}
    fi
    if [ -e "/data/persist_log/backup/explorer_log_abnormal_log" ]; then
        mv -f /data/persist_log/backup/explorer_log_abnormal_log ${dcsLogPath}/${dcsZipName}
        chmod 0777 ${dcsLogPath}/${dcsZipName}
        chown system:system ${dcsLogPath}/${dcsZipName}
    fi
}

function disableCameraOfflineProp(){
    PROP_DISABLE_OFFLINE=`getprop persist.sys.engineering.pre.disableoffline`
    PROP_OFFLINE=`getprop persist.sys.log.offline`
    if [ x"${PROP_OFFLINE}" == x"true" ] && [ x"${PROP_DISABLE_OFFLINE}" != x"false" ]; then
        setprop persist.sys.log.offline false
        setprop persist.sys.engineering.pre.disableoffline false
    fi
}

function startCatchLog(){
    traceTransferState "start catch log"
    handle_m_commonLog

    # TODO only for camera tmp plan on android R
    disableCameraOfflineProp

    LOG_TYPE=`getprop persist.sys.debuglog.config`
    handle_command_${LOG_TYPE}
}

function handle_m_commonLog(){
    traceTransferState "startCollectCommonLog..."
    DATA_LOG_APPS_PATH=${DATA_LOG_DEBUG_PATH}/apps
    DATA_LOG_KERNEL_PATH=${DATA_LOG_DEBUG_PATH}/kernel
    ASSERT_PATH=${DATA_LOG_DEBUG_PATH}/asserttip

    if [[ ! -d ${DATA_LOG_APPS_PATH} ]]; then
        mkdir -p ${DATA_LOG_APPS_PATH}
    fi
    if [[ ! -d ${DATA_LOG_KERNEL_PATH} ]]; then
        mkdir -p ${DATA_LOG_KERNEL_PATH}
    fi
    if [[ ! -d ${ASSERT_PATH} ]]; then
        mkdir -p ${ASSERT_PATH}
    fi
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}

    setprop sys.oplus.logkit.appslog ${DATA_LOG_APPS_PATH}
    setprop sys.oplus.logkit.kernellog ${DATA_LOG_KERNEL_PATH}
    # TODO
    setprop sys.oplus.logkit.assertlog ${ASSERT_PATH}

    PANIC_ENABLE=`getprop persist.sys.assert.panic`
    PANIC_CAMERA_ENABLE=`getprop persist.sys.assert.panic.camera`
    if [ "${PANIC_ENABLE}" = "true" ] || [ x"${PANIC_CAMERA_ENABLE}" = x"true" ]; then
        # 1, set log buffer
        logdsize=`getprop persist.logd.size`
        if [ "${logdsize}" = "" ]; then
            traceTransferState "set buffer to 5M" "i"
            /system/bin/logcat -G 5M
        fi

        # 2, start
        traceTransferState "start logcat android events radio kernel"
        setprop ctl.start logcatsdcard
        setprop ctl.start logcatradio
        setprop ctl.start logcatevent
        setprop ctl.start logcatkernel
    fi
}
function handle_m_tcpdump(){
    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    if [[ ! -d ${DATA_LOG_TCPDUMPLOG_PATH} ]]; then
        mkdir -p ${DATA_LOG_TCPDUMPLOG_PATH}
    fi
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}

    setprop ctl.restart tcpdumplog
}

function handle_m_qmi(){
    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    if [[ ! -d ${QMI_PATH} ]]; then
        mkdir -p ${QMI_PATH}
    fi
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    setprop ctl.start qmilogon
}

function handle_command_call(){
    handle_m_tcpdump

    setprop ctl.start logcatSsLog
}
function handle_command_media(){
    # TODO
}
function handle_command_bluetooth(){

}
function handle_command_gps(){
    #ifndef OPLUS_GPS_LOG
    #ShiMinghao@CONNECTIVITY.GPS, 2021/02/09, Enable tcpdump when capturing GPS Log for network locationing
    handle_m_tcpdump
    #endif /* OPLUS_GPS_LOG */
}
function handle_command_network(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog
}
function handle_command_wifi(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog
}
function handle_command_junk(){

}
function handle_command_stability(){

}
function handle_command_heat(){
    handle_m_tcpdump

    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    mkdir -p  ${QMI_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    start qmilogon
    start logcatSsLog
}
function handle_command_power(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog
}
function handle_command_charge(){
    # Add for catching Charging log

}
function handle_command_thirdpart(){
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}
function handle_command_camera(){
    # Add for catching Camera log
}
function handle_command_sensor(){

    DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_LOG_DEBUG_PATH}/fingerprint
    mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    setprop sys.oplus.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    setprop ctl.start fingerprintlog
    setprop ctl.start fplogqess
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}
function handle_command_touch(){

}
function handle_command_fingerprint(){

    DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_LOG_DEBUG_PATH}/fingerprint
    mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    setprop sys.oplus.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    setprop ctl.start fingerprintlog
    setprop ctl.start fplogqess
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}
function handle_command_other(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog

    DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_LOG_DEBUG_PATH}/fingerprint
    mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    setprop sys.oplus.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    setprop ctl.start fingerprintlog
    setprop ctl.start fplogqess
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}

function dumpsysInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    dumpsys > ${SDCARD_LOG_TRIGGER_PATH}/dumpsys_all_${CURTIME}.txt;
}
function dumpStateInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    dumpstate > ${SDCARD_LOG_TRIGGER_PATH}/dumpstate_${CURTIME}.txt
}
function topInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    top -n 1 > ${SDCARD_LOG_TRIGGER_PATH}/top_${CURTIME}.txt;
}
function psInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    ps > ${SDCARD_LOG_TRIGGER_PATH}/ps_${CURTIME}.txt;
}

function serviceListInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    service list > ${SDCARD_LOG_TRIGGER_PATH}/service_list_${CURTIME}.txt;
}

function dumpStorageInfo() {
    STORAGE_PATH=${SDCARD_LOG_TRIGGER_PATH}/storage
    if [ ! -d ${STORAGE_PATH} ];then
        mkdir -p ${STORAGE_PATH}
    fi

    mount > ${STORAGE_PATH}/mount.txt
    dumpsys devicestoragemonitor > ${STORAGE_PATH}/dumpsys_devicestoragemonitor.txt
    dumpsys mount > ${STORAGE_PATH}/dumpsys_mount.txt
    dumpsys diskstats > ${STORAGE_PATH}/dumpsys_diskstats.txt
    du -H /data > ${STORAGE_PATH}/diskUsage.txt
}

#Hongchao.Li@ANDROID.DEBUG, 2021/11/2, Add for copy wxlog
function copyWXlog() {
  currentDateWXlog=$(date "+%Y%m%d")
  LOG_TYPE=$(getprop persist.sys.debuglog.config)
  if [ "${LOG_TYPE}" != "thirdpart" ]; then
    return
  fi
  stoptime=$(getprop sys.oplus.log.stoptime)
  newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"
  SUB_XLOG_DIR="/storage/emulated/999/Android/data/com.tencent.mm/MicroMsg/xlog"

  mkdir -p ${newpath}/wxlog

  #wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/xlog
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for i in $ALL_FILE; do
      echo "now we have Xlog file $i"
      #echo  $i >> ${newpath}/xlog/.xlog.txt
      cp $i ${newpath}/wxlog/xlog/
    done
  fi

  setprop sys.tranfer.finished cp:xlog

  #wxlog/crash
  mkdir -p ${newpath}/wxlog/crash
  if [ -d "${CRASH_DIR}" ]; then
    ALL_FILE=$(find ${CRASH_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for i in $ALL_FILE; do
      cp $i ${newpath}/wxlog/crash/
    done
  fi

  #sub_wxlog/xlog
  if [ -d "${SUB_XLOG_DIR}" ]; then
    mkdir -p ${newpath}/sub_wxlog/xlog
    ALL_FILE=$(find ${SUB_XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for i in $ALL_FILE; do
      echo "now we have Xlog file $i"
      #echo  $i >> ${newpath}/sub_wxlog/.xlog.txt
      cp $i ${newpath}/sub_wxlog/xlog/
    done
  fi

  setprop sys.tranfer.finished cp:sub_wxlog
}

#Hongchao.Li@ANDROID.DEBUG, 2021/11/2, Add for copy qlog
function copyQlog() {
  currentDateQlog=$(date "+%y.%m.%d")
  LOG_TYPE=$(getprop persist.sys.debuglog.config)
  if [ "${LOG_TYPE}" != "thirdpart" ]; then
    return
  fi
  stoptime=$(getprop sys.oplus.log.stoptime)
  newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"

  QLOG_DIR="/sdcard/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq/"
  SUB_QLOG_DIR="/storage/emulated/999/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq"

  mkdir -p ${newpath}/qlog

  #qlog
  if [ -d "${QLOG_DIR}" ]; then
    Q_FILE=$(find ${QLOG_DIR} | grep -E ${currentDateQlog} | xargs ls -t)
    for i in $Q_FILE; do
      echo "now we have Qlog file $i"
      cp $i ${newpath}/qlog
    done
  fi

  setprop sys.tranfer.finished cp:qlog

  #sub_qlog
  if [ -d "${SUB_QLOG_DIR}" ]; then
    mkdir -p ${newpath}/sub_qlog
    Q_FILE=$(find ${SUB_QLOG_DIR} | grep -E ${currentDateQlog} | xargs ls -t)
    for i in $Q_FILE; do
      echo "now we have Qlog file $i"
      cp $i ${newpath}/sub_qlog
    done
  fi

  setprop sys.tranfer.finished cp:sub_qlog
}

function transferSystrace(){
    SYSTRACE_PATH=/data/local/traces
    checkNumberSizeAndMove "${SYSTRACE_PATH}" "${newpath}/systrace"
}

# service user set to system,group sdcard_rw
function transferUser(){
    stoptime=`getprop sys.oplus.log.stoptime`
    userpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"

    DATA_USER_LOG=/data/system/users/0
    TARGET_DATA_USER_LOG=${userpath}/user_0

    checkNumberSizeAndCopy "${DATA_USER_LOG}" "${TARGET_DATA_USER_LOG}"
}

function transferScreenshots(){
    MAX_NUM=5
    is_release=`getprop ro.build.release_type`
    if [ x"${is_release}" != x"true" ]; then
        #Zhiming.chen@ANDROID.DEBUG.BugID 2724830, 2019/12/17,The log tool captures child user screenshots
        ALL_USER=`ls -t /data/media/`
        for m in $ALL_USER;
        do
            IDX=0
            screen_shot="/data/media/${m}/Pictures/Screenshots/"
            if [ -d "${screen_shot}" ]; then
                mkdir -p ${newpath}/Screenshots/$m
                touch ${newpath}/Screenshots/${m}/.nomedia
                ALL_FILE=`ls -t ${screen_shot}`
                for index in ${ALL_FILE};
                do
                    let IDX=${IDX}+1;
                    if [ "$IDX" -lt ${MAX_NUM} ] ; then
                       cp $screen_shot/${index} ${newpath}/Screenshots/${m}/
                       traceTransferState "${IDX}: ${index} done"
                    fi
                done
                traceTransferState "copy /${m} screenshots done"
            fi
        done
    fi
}

function transferSystemAppLog(){
    #TraceLog
    TRACELOG=/sdcard/Documents/TraceLog
    checkSmallSizeAndCopy "${TRACELOG}" "os/TraceLog"

    #OVMS
    OVMS_LOG=/sdcard/Documents/OVMS
    checkSmallSizeAndCopy "${OVMS_LOG}" "os/OVMS"

    #Pictorial
    PICTORIAL_LOG=/sdcard/Android/data/com.heytap.pictorial/files/xlog
    checkSmallSizeAndCopy "${PICTORIAL_LOG}" "os/Pictorial"

    #Camera
    CAMERA_LOG=/sdcard/DCIM/Camera/spdebug
    checkSmallSizeAndCopy "${CAMERA_LOG}" "os/Camera"

    #Browser
    BROWSER_LOG=/sdcard/Android/data/com.heytap.browser/files/xlog
    checkSmallSizeAndCopy "${BROWSER_LOG}" "os/com.heytap.browser"

    #OBRAIN
    OBRAIN_LOG=/data/misc/midas/xlog
    checkSmallSizeAndCopy "${OBRAIN_LOG}" "os/com.oplus.obrain"

    #common path
    cp /sdcard/Documents/*/.dog/* ${newpath}/os/
    traceTransferState "transfer log:copy system app done"
}

function checkSmallSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    traceTransferState "CHECKSMALLSIZEANDCOPY:from ${LOG_SOURCE_PATH}"
    # 10M
    LIMIT_SIZE="10240"

    if [ -d "${LOG_SOURCE_PATH}" ]; then
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        if [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then  #log size less then 10M
            mkdir -p ${newpath}/${LOG_TARGET_PATH}
            cp -rf ${LOG_SOURCE_PATH}/* ${newpath}/${LOG_TARGET_PATH}
            traceTransferState "CHECKSMALLSIZEANDCOPY:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKSMALLSIZEANDCOPY:${LOG_SOURCE_PATH} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        fi
    fi
}

function checkNumberSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LIMIT_SIZE="$3"
    LIMIT_NUM=500
    if [[ "${LIMIT_SIZE}" == "" ]]; then
        #500*1024KB
        LIMIT_SIZE="512000"
    fi
    traceTransferState "CHECKNUMBERSIZEANDCOPY:FROM ${LOG_SOURCE_PATH}"

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CHECKNUMBERSIZEANDCOPY:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]] && [[ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" "e"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function checkNumberSizeAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKNUMBERSIZEANDMOVE:FROM ${LOG_SOURCE_PATH}"
    LIMIT_NUM=500
    #500*1024KB
    LIMIT_SIZE="512000"

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CHECKNUMBERSIZEANDMOVE:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]] && [[ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" "e"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function checkAgingAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKAGINGANDMOVE:FROM ${LOG_SOURCE_PATH}"
    LIMIT_NUM=500

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        traceTransferState "CHECKAGINGANDMOVE:NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKAGINGANDMOVE:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKAGINGANDMOVE:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function transferThirdApp() {
    #Chunbo.Gao@ANDROID.DEBUG.NA, 2019/6/21, Add for pubgmhd.ig
    app_pubgmhd_dir="/sdcard/Android/data/com.tencent.tmgp.pubgmhd/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Logs"
    if [ -d ${app_pubgmhd_dir} ]; then
        mkdir -p ${newpath}/os/TClogs/pubgmhd
        echo "copy pubgmhd..."
        cp -rf ${app_pubgmhd_dir} ${newpath}/os/TClogs/pubgmhd
    fi

    #Yi.Jiang@ANDROID.DEBUG.NA, 2022/1/10 ,Add for kugou qqlive yx yy,wework ,tmgp.cf
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [ "${LOG_TYPE}" != "thirdpart" ]; then
       return
    fi

    traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy thirdapp start"
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"

    app_kugou_dir="/sdcard/kugou/log"
    if [ -d ${app_kugou_dir} ]; then
        traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_kugou_dir success " + "${?}"
        mkdir -p ${newpath}/ThirdAppLogs/kugou
        traceTransferState "copy kogou..."
        checkSmallSizeAndCopy "${app_kugou_dir}" "ThirdAppLogs/kugou"
    fi

    app_qqlive_dir="/sdcard/Android/data/com.tencent.qqlive/files/log"
    if [ -d ${app_qqlive_dir} ]; then
        mkdir -p ${newpath}/ThirdAppLogs/qqlive
        traceTransferState "copy qqlive..."
        checkSmallSizeAndCopy "${app_qqlive_dir}" "ThirdAppLogs/qqlive"
    else
        traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_qqlive_dir fail " + " ${?}"
    fi

    app_yx_dir="/sdcard/Android/data/com.yx"
    if [ -d ${app_yx_dir} ]; then
        mkdir -p ${newpath}/ThirdAppLogs/yx
        traceTransferState "copy yx..."
        checkSmallSizeAndCopy "${app_yx_dir}" "ThirdAppLogs/yx"
    else
         traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_yx_dir fail " + "${?}"
    fi

    app_yymobile_dir="/sdcard/Android/data/com.duowan.mobile/files/yymobile/logs"
    if [ -d ${app_yymobile_dir} ]; then
        mkdir -p ${newpath}/ThirdAppLogs/yymobile
        traceTransferState "copy yymobile..."
        checkSmallSizeAndCopy "${app_yymobile_dir}" "ThirdAppLogs/yymobile"
    else
        traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_yymobile_dir fail " + "${?}"
    fi

    app_wework_dir="/sdcard/Android/data/com.tencent.wework/files/src_clog"
    if [ -d ${app_wework_dir} ]; then
        mkdir -p ${newpath}/ThirdAppLogs/wework
        cp -rf ${app_wework_dir} ${newpath}/ThirdAppLogs/wework
        traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_wework_dir result " + "${?}"
    else
        traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_wework_dir fail " + "${?}"
    fi

    app_wework_dir1="/sdcard/Android/data/com.tencent.wework/files/src_log"
    if [ -d ${app_wework_dir1} ]; then
         if [ -d ${newpath}/ThirdAppLogs/wework ];then
            mkdir -p ${newpath}/ThirdAppLogs/wework
         fi
         cp -rf ${app_wework_dir1} ${newpath}/ThirdAppLogs/wework
         traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_wework_dir1 result " + "${?}"
    else
         traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy app_wework_dir1 fail " + "${?}"
    fi

    app_tmgpcf_dir="/sdcard/Android/data/com.tencent.tmgp.cf/cache/Cache/Log/"
    if [ -d ${app_tmgpcf_dir} ]; then
        mkdir -p ${newpath}/ThirdAppLogs/tmgpcf
        traceTransferState "copy tmgp cf..."
        checkSmallSizeAndCopy "${app_tmgpcf_dir}" "ThirdAppLogs/tmgpcf"
    fi

    traceTransferState "${CURTIME_FORMAT} THIRDAPP:copy thirdapp done"
}

function transferPower(){
    # Add for thermalrec log
    dumpsys batterystats --thermalrec
    thermalrec_dir="/data/system/thermal/dcs"
    thermalstats_file="/data/system/thermalstats.bin"
    if [ -f ${thermalstats_file} ] || [ -d ${thermalrec_dir} ]; then
        mkdir -p ${newpath}/power/thermalrec/
        chmod 770 ${thermalstats_file}
        cp -rf ${thermalstats_file} ${newpath}/power/thermalrec/

        echo "copy Thermalrec..."
        chmod 770 /data/system/thermal/ -R
        cp -rf ${thermalrec_dir}/* ${newpath}/power/thermalrec/
    fi

    #Add for powermonitor log
    POWERMONITOR_DIR="/data/oplus/psw/powermonitor"
    chmod 770 ${POWERMONITOR_DIR} -R
    checkNumberSizeAndCopy "${POWERMONITOR_DIR}" "${newpath}/power/powermonitor"

    POWERMONITOR_BACKUP_LOG=/data/oplus/psw/powermonitor_backup/
    chmod 770 ${POWERMONITOR_BACKUP_LOG} -R
    checkNumberSizeAndCopy "${POWERMONITOR_BACKUP_LOG}" "${newpath}/power/powermonitor_backup"
}

function transferTcpdumpLog(){

    if [ -d  ${DATA_DEBUGGING_PATH} ]; then
        ALL_TCPDUMP_DIR=`ls ${DATA_DEBUGGING_PATH} | grep netlog`
        for TCPDUMP_DIR in ${ALL_TCPDUMP_DIR};do
            # TODO
            echo ${TCPDUMP_DIR}
        done
    fi
}

function transferDebuggingLog(){
    chmod -R 777 ${DATA_DEBUGGING_PATH}
    LOG_CONFIG_FILE="${DATA_OPLUS_LOG_PATH}/config/transferDebuggingLog_ls.log"
    # filter SI_stop/
    traceTransferState "TRANSFERDEBUGGINGLOG start "
    if [ -d  ${DATA_DEBUGGING_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_DEBUGGING_PATH} | grep -v SI_stop`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DEBUGGING_PATH}/${SUB_DIR} ] || [ -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ]; then
                mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} ${newpath}
                traceTransferState "TRANSFERDEBUGGINGLOG:mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} done"
                ls -l ${newpath} >>${LOG_CONFIG_FILE}
            fi
        done
    fi
    traceTransferState "TRANSFERDEBUGGINGLOG done "
}

function transferDataPersistLog(){
    TARGET_DATA_OPLUS_LOG=${newpath}/assistlog

    chmod 777 ${DATA_OPLUS_LOG_PATH}/ -R
    #tar -czvf ${newpath}/LOG.dat.gz -C ${DATA_OPLUS_LOG_PATH} .
    #tar -czvf ${TARGET_DATA_OPLUS_LOG}/LOG.tar.gz ${DATA_OPLUS_LOG_PATH}

    # filter DCS
    if [ -d  ${DATA_OPLUS_LOG_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_OPLUS_LOG_PATH} | grep -v DCS | grep -v data_vendor | grep -v TMP | grep -v hprofdump`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/${SUB_DIR}"
            fi
        done
    fi

    transferDataDCS
    transferDataTMP
    transferDataHprof
}

function transferDataDCS(){
    TARGET_DATA_DCS_LOG=${newpath}/assistlog/DCS

    DATA_DCS_LOG=${DATA_OPLUS_LOG_PATH}/DCS/de
    if [ -d  ${DATA_DCS_LOG} ]; then
        ALL_SUB_DIR=`ls ${DATA_DCS_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DCS_LOG}/${SUB_DIR} ] || [ -f ${DATA_DCS_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_DCS_LOG}/${SUB_DIR}" "${TARGET_DATA_DCS_LOG}/${SUB_DIR}"
            fi
        done
    fi

    DATA_DCS_OTRTA_LOG=${DATA_OPLUS_LOG_PATH}/backup
    if [ -d  ${DATA_DCS_LOG} ]; then
        ALL_SUB_DIR=`ls ${DATA_DCS_OTRTA_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DCS_OTRTA_LOG}/${SUB_DIR} ] || [ -f ${DATA_DCS_OTRTA_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_DCS_OTRTA_LOG}/${SUB_DIR}" "${TARGET_DATA_DCS_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

function transferDataTMP(){
    DATA_TMP_LOG=${DATA_OPLUS_LOG_PATH}/TMP
    TARGET_DATA_TMP_LOG=${newpath}/assistlog

    if [[ -d ${DATA_TMP_LOG} ]]; then
        ALL_SUB_DIR=`ls ${DATA_TMP_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [[ -d ${DATA_TMP_LOG}/${SUB_DIR} ]] || [[ -f ${DATA_TMP_LOG}/${SUB_DIR} ]]; then
                checkNumberSizeAndMove "${DATA_TMP_LOG}/${SUB_DIR}" "${TARGET_DATA_TMP_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

function transferDataHprof(){
    DATA_HPROF_LOG=${DATA_OPLUS_LOG_PATH}
    TARGET_DATA_HPROF_LOG=${newpath}/assistlog

    if [[ -d ${DATA_HPROF_LOG} ]]; then
        ALL_SUB_DIR=`ls ${DATA_HPROF_LOG} | grep hprofdump`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [[ -d ${DATA_HPROF_LOG}/${SUB_DIR} ]] || [[ -f ${DATA_HPROF_LOG}/${SUB_DIR} ]]; then
                checkAgingAndMove "${DATA_HPROF_LOG}/${SUB_DIR}" "${TARGET_DATA_HPROF_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

function transferDataVendor(){
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    DATA_VENDOR_LOG=${DATA_OPLUS_LOG_PATH}/data_vendor
    TARGET_DATA_VENDOR_LOG=${newpath}/data_vendor

    if [ -d ${DATA_VENDOR_LOG} ]; then
        chmod 777 ${DATA_VENDOR_LOG} -R
        ALL_SUB_DIR=`ls ${DATA_VENDOR_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_VENDOR_LOG}/${SUB_DIR} ] || [ -f ${DATA_VENDOR_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndMove "${DATA_VENDOR_LOG}/${SUB_DIR}" "${TARGET_DATA_VENDOR_LOG}/${SUB_DIR}"
            fi
        done
    fi
    chmod 777 ${TARGET_DATA_VENDOR_LOG} -R
}

function transferBluetoothLog() {
    checkNumberSizeAndCopy "/data/misc/bluetooth/logs" "${newpath}/btsnoop_hci"
    #Laixin@CONNECTIVITY.BT.Basic.Log.70745, modify for auto capture hci log
    checkNumberSizeAndCopy "/data/misc/bluetooth/cached_hci" "${newpath}/btsnoop_hci"
}

function transfer_m_commonlog() {
    traceTransferState "start transfer_commonlog"

    #init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/commonlog

    chmod -R 777 ${DATA_DEBUGGING_PATH}
    # filter SI_stop/
    if [[ -d ${DATA_DEBUGGING_PATH} ]]; then
        ALL_SUB_DIR=`ls ${DATA_DEBUGGING_PATH} | grep -v SI_stop | grep -v diag_logs`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [[ -d ${DATA_DEBUGGING_PATH}/${SUB_DIR} ]] || [[ -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ]]; then
                mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} ${MODULE_TARGET_PATH}
                traceTransferState "mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} done" "i"
            fi
        done
    fi

    # errorinfo: anr/tombstone/dropbox/recovery
    transfer_m_errorinfo
    # screenshots
    transfer_m_screenshots
}
function transfer_m_assistlog() {
    traceTransferState "start transfer_assistlog"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/assistlog

    newpath=${TARGET_PATH}
    transferDataPersistLog
}
function transfer_m_errorinfo() {
    traceTransferState "start transfer_commonlog"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/errorinfo

    # anr
    chmod 640 /data/anr -R
    checkNumberSizeAndCopy "/data/anr" "${MODULE_TARGET_PATH}/anr"
    # tombstone
    checkNumberSizeAndCopy "/data/tombstones" "${MODULE_TARGET_PATH}/tombstones"
    # dropbox
    # TODO Invalid function
    checkNumberSizeAndCopy "/data/system/dropbox" "${MODULE_TARGET_PATH}/dropbox"
    # recovery
    setprop ctl.start transfer_recovery
}
function transfer_m_recovery() {
    stoptime=`getprop sys.oplus.log.stoptime`
    TARGET_PATH="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    MODULE_TARGET_PATH=${TARGET_PATH}/errorinfo

    checkNumberSizeAndCopy "/cache/recovery" "${MODULE_TARGET_PATH}/recovery"
}
function transfer_m_screenshots(){
    traceTransferState "start transfer_screenshots"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/screenshots

    newpath=${TARGET_PATH}
    transferScreenshots
}

function transfer_m_qxdm() {
    traceTransferState "start transfer_qxdm"

    # qxdm
    MODULE_TARGET_PATH=${TARGET_PATH}/qxdm
    checkNumberSizeAndMove ${DATA_DEBUGGING_PATH}/diag_logs "${MODULE_TARGET_PATH}"
}

function transfer_call() {
    traceTransferState "start transfer_call"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/call

    # qxdm
    transfer_m_qxdm
}
function transfer_media() {
    traceTransferState "start transfer_media"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/media

    # media
    chmod 777 /data/persist_log/TMP/pcm_dump -R
    checkNumberSizeAndCopy "/data/persist_log/TMP/pcm_dump" "${MODULE_TARGET_PATH}/pcm_dump"

    # qxdm
    transfer_m_qxdm
}
function transfer_bluetooth() {
    traceTransferState "start transfer_bluetooth"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/bluetooth

    # bluetooth
    checkNumberSizeAndCopy "/data/misc/bluetooth/logs" "${MODULE_TARGET_PATH}"
    #Laixin@CONNECTIVITY.BT.Basic.Log.70745, modify for auto capture hci log
    checkNumberSizeAndCopy "/data/misc/bluetooth/cached_hci" "${MODULE_TARGET_PATH}"

    # qxdm
    transfer_m_qxdm
}
function transfer_gps() {
    traceTransferState "start transfer_gps"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/gps

    # gps

    # qxdm
    transfer_m_qxdm
}
function transfer_network() {
    traceTransferState "start transfer_network"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/network

    # network

    # qxdm
    transfer_m_qxdm
}
function transfer_wifi() {
    traceTransferState "start transfer_wifi"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/wifi

    # wifi

    # qxdm
    transfer_m_qxdm
}
function transfer_junk() {
    traceTransferState "start transfer_junk"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/junk

    # junk

    # qxdm
    transfer_m_qxdm
}
function transfer_stability() {
    traceTransferState "start transfer_stability"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/stability

    # stability

    # qxdm
    transfer_m_qxdm
}
function transfer_heat() {
    traceTransferState "start transfer_heat"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/heat

    # heat

    # qxdm
    transfer_m_qxdm
}
function transfer_power() {
    traceTransferState "start transfer_power"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/power

    # power

    # qxdm
    transfer_m_qxdm
}
function transfer_charge() {
    traceTransferState "start transfer_charge"\

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/charge

    # charge

    # qxdm
    transfer_m_qxdm
}
function transfer_thirdpart() {
    traceTransferState "start transfer_thirdpart"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/thirdpart

    # thirdpart

    # qxdm
    transfer_m_qxdm
}
function transfer_camera() {
    traceTransferState "start transfer_camera"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/camera

    # camera

    # qxdm
    transfer_m_qxdm
}
function transfer_sensor() {
    traceTransferState "start transfer_sensor"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/sensor

    # sensor

    # qxdm
    transfer_m_qxdm
}
function transfer_touch() {
    traceTransferState "start transfer_touch"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/touch

    # touch

    # qxdm
    transfer_m_qxdm
}
function transfer_fingerprint() {
    traceTransferState "start transfer_fingerprint"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/fingerprint

    # fingerprint

    # qxdm
    transfer_m_qxdm
}
function transfer_other() {
    traceTransferState "start transfer_other"

    # init module path
    MODULE_TARGET_PATH=${TARGET_PATH}/other

    # other

    # qxdm
    transfer_m_qxdm
}

function transfer2SDCard(){
    stoptime=`getprop sys.oplus.log.stoptime`
    traceTransferState "TRANSFER2SDCARD:start...."
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    mkdirInSpecificPermission ${newpath} 2770
    traceTransferState "TRANSFER2SDCARD:from ${DATA_DEBUGGING_PATH} to ${newpath}"

    #Yujie.Long@ANDROID.DEBUG.NA, 2020/02/21, Add for save recovery log
    setprop ctl.start mvrecoverylog

    #transferBugreportLog
    setprop ctl.start transfer_bugreport

    transferDebuggingLog

    # bluetooth log
    transferBluetoothLog

    #user
    setprop ctl.start transferUser

    #copy thermalrec and powermonitor log
    transferPower

    #copy third-app log
    transferThirdApp
    #setprop sys.tranfer.finished cp:xxx_dir

    mv ${SDCARD_LOG_TRIGGER_PATH} ${newpath}/

    mkdir -p ${newpath}/tombstones/
    cp /data/tombstones/tombstone* ${newpath}/tombstones/

    #screenshots
    transferScreenshots

    #systrace
    transferSystrace

    #Rui.Liu@ANDROID.DEBUG, 2020/09/17, Add for copy wxlog and qlog
    copyWXlog
    copyQlog

    #os app
    transferSystemAppLog

    #mv wm
    transferWm

    transferDataPersistLog
}

function mkdirInSpecificPermission() {
    MKDIR_PATH=$1
    MKDIR_PERMISSION=$2
    if [ ! -d ${MKDIR_PATH} ]; then
        mkdir -p ${MKDIR_PATH}
    fi
    chmod ${MKDIR_PERMISSION} ${MKDIR_PATH} -R
}

function initTargetPath() {
    stoptime=`getprop sys.oplus.log.stoptime`
    TARGET_PATH="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    mkdir -p ${TARGET_PATH}
    traceTransferState "target_path: ${TARGET_PATH}"
}

function transfer_log() {
    traceTransferState "TRANSFER_LOG:start...."

    setprop ctl.start dump_system

    crossTypes=(media bluetooth)
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    LOG_CROSS_TYPE=`getprop persist.sys.debuglog.config_cross`
    traceTransferState "transfer_${LOG_TYPE} / transfer_${LOG_CROSS_TYPE}"

#    if [[ "${LOG_CROSS_TYPE}" != "" ]] && [[ "${LOG_TYPE}" != null ]] && [[ "${LOG_CROSS_TYPE}" != null ]] && [[ "${LOG_TYPE}" != "${LOG_CROSS_TYPE}" ]]; then
#        if [[ "${crossTypes[@]}" == *"${LOG_TYPE}"* ]] && [[ "${crossTypes[@]}" == *"${LOG_CROSS_TYPE}"* ]]; then
#            traceTransferState "TRANSFER_LOG: handle cross log catch."
#        fi
#    fi
#    if [[ "${crossTypes[@]}" != *"${LOG_TYPE}"* ]] || [[ "${crossTypes[@]}" != *"${LOG_CROSS_TYPE}"* ]]; then
    if [[ "${LOG_CROSS_TYPE}" != "" ]] && [[ "${LOG_TYPE}" != null ]] && [[ "${LOG_CROSS_TYPE}" != null ]] && [[ "${LOG_TYPE}" != "${LOG_CROSS_TYPE}" ]]; then
        if [[ "${crossTypes[@]}" == *"${LOG_TYPE}"* ]] && [[ "${crossTypes[@]}" == *"${LOG_CROSS_TYPE}"* ]]; then
            # init target path
            initTargetPath
            # commonlog
            transfer_m_commonlog

            transfer_${LOG_TYPE}
            transfer_${LOG_CROSS_TYPE}

            # assist log
            transfer_m_assistlog

            setprop persist.sys.debuglog.config_cross ""
        fi
    else
        transfer2SDCard
    fi

    # check ctl.start services status
    checkStartServicesDone

    setprop sys.tranfer.finished 1

    chmodFromBasePath

    #Zhangxueqiang@ANDROID.UPDATABILITY, 2020/11/24, add for save update_engine log
    mv ${SDCARD_LOG_BASE_PATH}/recovery_log/ ${newpath}/
    mv ${SDCARD_LOG_BASE_PATH}/bugreports/ ${newpath}/

    traceTransferState "TRANSFER_LOG:done...."
    mv ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log ${newpath}/
}

function checkStartServicesDone(){
    traceTransferState "check ctl.start services done"
    checkServicesList=(dump_system mvrecoverylog transfer_bugreport transferUser transfer_recovery)
    allSerivcesDoneFlag=1
    timeCount=0
    while [ ${allSerivcesDoneFlag} -eq 1 ] && [ timeCount -le 30 ]
    do
        allSerivcesDoneFlag=0
        for i in "${!checkServicesList[@]}"
        do
            serviceStatus=`getprop init.svc.${checkServicesList[$i]}`
            traceTransferState "${checkServicesList[$i]} state:${serviceStatus}"
            if [[ "${serviceStatus}" == "running" ]];then
                allSerivcesDoneFlag=1
            else
                unset checkServicesList[i]
            fi
        done
        echo "${CURTIME_FORMAT} ${LOGTAG}:count=$timeCount" >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        timeCount=$((timeCount + 1))
        sleep 1
    done
}

function chmodFromBasePath() {
    traceTransferState "chmodFromBasePath"
    chmod 2770 ${BASE_PATH} -R
    SDCARDFS_ENABLED=`getprop external_storage.sdcardfs.enabled 1`
    traceTransferState "TRANSFER_LOG:SDCARDFS_ENABLED is ${SDCARDFS_ENABLED}"
    if [ "${SDCARDFS_ENABLED}" == "0" ]; then
        chown system:ext_data_rw ${SDCARD_LOG_BASE_PATH} -R
    fi
}

function transferLog() {
    LOG_CONFIG_FILE="${DATA_OPLUS_LOG_PATH}/config/log_config.log"

    if [ -f "${LOG_CONFIG_FILE}" ]; then
        setprop sys.oplus.log.stoptime ${CURTIME}
        stoptime=`getprop sys.oplus.log.stoptime`
        LOG_PATH="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
        mkdir -p ${LOG_PATH}
        echo "${CURTIME_FORMAT} transfer log: ${LOG_PATH}, start..."

        cat ${LOG_CONFIG_FILE} | while read item_config
        do
            if [ "" != "${item_config}" ];then
                echo "${CURTIME_FORMAT} transfer log config: ${item_config}"
                OPERATION=`echo ${item_config} | awk '{print $1}'`
                SOURCE_PATH=`echo ${item_config} | awk '{print $2}'`
                if [ -d ${SOURCE_PATH} ];then
                    #if [ ! -d ${LOG_PATH}/${TARGET_PATH} ];then
                    #    mkdir ${LOG_PATH}/${TARGET_PATH}
                    #fi

                    TEMP_SIZE=`du -s ${SOURCE_PATH} | awk '{print $1}'`
                    if [ "" != "${OPERATION}" ] && [ x"${OPERATION}" = x"mv" ];then
                        ${OPERATION} ${SOURCE_PATH} ${LOG_PATH}/
                    else
                        checkNumberSizeAndCopy ${SOURCE_PATH} ${LOG_PATH}/
                    fi
                    #${OPERATION} -rf ${SOURCE_PATH} ${LOG_PATH}/${TARGET_PATH}
                    #echo "${CURTIME_FORMAT} transfer log path: cp ${SOURCE_PATH} to ${TARGET_PATH} done, size ${TEMP_SIZE}"
                    traceTransferState "transfer log path: ${OPERATION} ${SOURCE_PATH} done, size ${TEMP_SIZE}"
                else
                    traceTransferState "transfer log path: ${SOURCE_PATH}, No such file or directory"
                fi
            fi
        done
    else
        echo "${CURTIME_FORMAT} transfer log: ${LOG_CONFIG_FILE}, not exits"
    fi
}

function initLogSizeAndNums() {
    FreeSize=`df /data | grep -v Mounted | awk '{print $4}'`
    GSIZE=`echo | awk '{printf("%d",2*1024*1024)}'`
    traceTransferState "data FreeSize:${FreeSize} and GSIZE:${GSIZE}"
    tmpTcpdump=`getprop persist.sys.log.tcpdump`
    if [ "${tmpTcpdump}" != "" ]; then
        tmpTcpdumpSize=`set -f;array=(${tmpTcpdump//|/ });echo "${array[0]}"`
        tmpTcpdumpCount=`set -f;array=(${tmpTcpdump//|/ });echo "${array[1]}"`
        tcpdumpSize=`echo ${tmpTcpdumpSize} | awk '{printf("%d",$1*1024)}'`
        tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
        ##tcpdump use MB in the order
        tcpdumpSize=${tmpTcpdumpSize}
        if [ ${tcpdumpCount} -ge ${tmpTcpdumpCount} ]; then
            tcpdumpCount=${tmpTcpdumpCount}
        fi
    fi

    #LiuHaipeng@NETWORK.DATA.2959182, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    #YangQing@CONNECTIVITY.WIFI.DCS.4219844, only limit tcpdump total size to 300M for other log, not limit packet size.
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    tcpdumpPacketSize=0
    #ZhuYan@Network.ARCH.4305581, customize tcpdumpPacketSize
    tcpdump_pktsize=`getprop sys.oplus.data.tcpdump_pktsize`
    if [ "${tcpdump_pktsize}" != "" ] && [ ${tcpdump_pktsize} -ge 0 ] && [ ${tcpdump_pktsize} -le 1500 ]; then
        tcpdumpPacketSize=${tcpdump_pktsize}
        traceTransferState "tcpDumpLog tcpdumpPacketSize=${tcpdumpPacketSize}"
    fi
    if [ "${LOG_TYPE}" != "call" ] && [ "${LOG_TYPE}" != "network" ] && [ "${LOG_TYPE}" != "wifi" ]; then
        tcpdumpSizeTotal=300
        tcpdumpCount=`echo ${tcpdumpSizeTotal} ${tcpdumpSize} 1 | awk '{printf("%d",$1/$2)}'`
    fi
}

# 51200 * 20
function logcatMain() {
    #get the config size main
    LOG_ANDROID_CONFIG=`getprop persist.sys.log.main`
    if [ "${LOG_ANDROID_CONFIG}" != "" ]; then
        TMP_ANDROID_SIZE=`set -f;array=(${LOG_ANDROID_CONFIG//|/ });echo "${array[0]}"`
        ANDROID_SIZE=`echo ${TMP_ANDROID_SIZE} | awk '{printf("%d",$1*1024)}'`
        ANDROID_MAXMUM=`set -f;array=(${LOG_ANDROID_CONFIG//|/ });echo "${array[1]}"`
    fi

    DATA_LOG_APPS_PATH=`getprop sys.oplus.logkit.appslog`

    traceTransferState "android info: ${ANDROID_SIZE}*${ANDROID_MAXMUM}" "i"
    /system/bin/logcat -b main -b system -b crash -f ${DATA_LOG_APPS_PATH}/android.txt -r${ANDROID_SIZE} -n ${ANDROID_MAXMUM}  -v threadtime -A
}

# 20480 * 5
function logcatRadio() {
    #get the config size radio
    LOG_RADIO_CONFIG=`getprop persist.sys.log.radio`
    if [ "${LOG_RADIO_CONFIG}" != "" ]; then
        TMP_RADIO_SIZE=`set -f;array=(${LOG_RADIO_CONFIG//|/ });echo "${array[0]}"`
        RADIO_SIZE=`echo ${TMP_RADIO_SIZE} | awk '{printf("%d",$1*1024)}'`
        RADIO_MAXMUM=`set -f;array=(${LOG_RADIO_CONFIG//|/ });echo "${array[1]}"`
    fi

    DATA_LOG_APPS_PATH=`getprop sys.oplus.logkit.appslog`
    traceTransferState "radio info: ${RADIO_SIZE}*${RADIO_MAXMUM}" "i"

    /system/bin/logcat -b radio -f ${DATA_LOG_APPS_PATH}/radio.txt -r ${RADIO_SIZE} -n ${RADIO_MAXMUM} -v threadtime -A
}

# 20480 * 2
function logcatEvent() {
    #get the config size event
    LOG_EVENTS_CONFIG=`getprop persist.sys.log.event`
    if [ "${LOG_EVENTS_CONFIG}" != "" ]; then
        TMP_EVENTS_SIZE=`set -f;array=(${LOG_EVENTS_CONFIG//|/ });echo "${array[0]}"`
        EVENTS_SIZE=`echo ${TMP_EVENTS_SIZE} | awk '{printf("%d",$1*1024)}'`
        EVENTS_MAXMUM=`set -f;array=(${LOG_EVENTS_CONFIG//|/ });echo "${array[1]}"`
    fi

    DATA_LOG_APPS_PATH=`getprop sys.oplus.logkit.appslog`
    traceTransferState "event info: ${EVENTS_SIZE}*${EVENTS_MAXMUM}" "i"

    /system/bin/logcat -b events -f ${DATA_LOG_APPS_PATH}/events.txt -r ${EVENTS_SIZE} -n ${EVENTS_MAXMUM} -v threadtime -A
}

# 51200 * 10
function logcatKernel() {
    #get the config size kernel
    LOG_KERNEL_CONFIG=`getprop persist.sys.log.kernel`
    if [ "${LOG_KERNEL_CONFIG}" != "" ]; then
        TMP_KERNEL_SIZE=`set -f;array=(${LOG_KERNEL_CONFIG//|/ });echo "${array[0]}"`
        KERNEL_SIZE=`echo ${TMP_KERNEL_SIZE} | awk '{printf("%d",$1*1024)}'`
        KERNEL_MAXMUM=`set -f;array=(${LOG_KERNEL_CONFIG//|/ });echo "${array[1]}"`
    fi

    DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
    traceTransferState "kernel info: ${KERNEL_SIZE}*${KERNEL_MAXMUM}" "i"

    RELEASE_TYPE=`getprop ro.build.release_type`
    if [ x"${RELEASE_TYPE}" != x"true" ]; then
        /system/bin/logcat -b kernel -f ${DATA_LOG_KERNEL_PATH}/kernel.txt -r ${KERNEL_SIZE} -n ${KERNEL_MAXMUM} -v threadtime -A
    else
        /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${DATA_LOG_KERNEL_PATH}/kernel.txt | awk 'NR%400==0'
    fi
}

#ifdef OPLUS_DEBUG_SSLOG_CATCH
#ZhangWankang@NETWORK.POWER 2020/04/02,add for catch ss log
function logcatSsLog(){
    echo "logcatSsLog start"
    outputPath="${DATA_DEBUGGING_PATH}/sslog"
    if [ ! -d "${outputPath}" ]; then
        mkdir -p ${outputPath}
    fi
    while [ -d "$outputPath" ]
    do
        ss -ntp -o state established >> ${outputPath}/sslog.txt
        sleep 15s #Sleep 15 seconds
    done
}
#endif

function transferTombstone() {
    srcpath=`getprop sys.tombstone.file`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/tombstone/tomb_${CURTIME}
}

function transferAnr() {
    srcpath=`getprop sys.anr.srcfile`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    destfile=`getprop sys.anr.destfile`

    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/anr/${destfile}
}

#ifdef OPLUS_BUG_STABILITY
#Qing.Wu@ANDROID.STABILITY.2278668, 2019/09/03, Add for capture binder info
function binderinfocapture() {
    alreadycaped=`getprop sys.debug.binderinfocapture`
    if [ "$alreadycaped" == "1" ] ;then
        return
    fi
    if [ ! -d ${SDCARD_LOG_BASE_PATH}/binder_info/ ];then
    mkdir -p ${SDCARD_LOG_BASE_PATH}/binder_info/
    fi

    LOGTIME=`date +%F-%H-%M-%S`
    BINDER_DIR=${SDCARD_LOG_BASE_PATH}/binder_info/binder_${LOGTIME}
    echo ${BINDER_DIR}
    mkdir -p ${BINDER_DIR}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${BINDER_DIR}/state
        cat /dev/binderfs/binder_logs/stats > ${BINDER_DIR}/stats
        cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_DIR}/transaction_log
        cat /dev/binderfs/binder_logs/transactions > ${BINDER_DIR}/transactions
    else
        cat /d/binder/state > ${BINDER_DIR}/state
        cat /d/binder/stats > ${BINDER_DIR}/stats
        cat /d/binder/transaction_log > ${BINDER_DIR}/transaction_log
        cat /d/binder/transactions > ${BINDER_DIR}/transactions
    fi
    ps -A -T > ${BINDER_DIR}/ps.txt

    kill -3 `pidof system_server`
    kill -3 `pidof com.android.phone`
    debuggerd -b `pidof netd` > "/data/anr/debuggerd_netd.txt"
    sleep 10
    cp -r /data/anr/*  ${BINDER_DIR}/
#package log folder to upload if logkit not enable
    logon=`getprop persist.sys.assert.panic`
    if [ ${logon} == "false" ];then
        current=`date "+%Y-%m-%d %H:%M:%S"`
        timeStamp=`date -d "$current" +%s`
        uuid=`cat /proc/sys/kernel/random/uuid`
        #uuid 0df1ed41-e0d6-40e2-8473-cdf7ccbd0d98
        otaversion=`getprop ro.build.version.ota`
        logzipname="${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/qp_deadsystem@"${uuid:0-12:12}@${otaversion}@${timeStamp}".tar.gz"
        tar -czf ${logzipname} ${BINDER_DIR}
        chown system:system ${logzipname}
    fi
    setprop sys.debug.binderinfocapture 1
}
#endif /* OPLUS_BUG_STABILITY */

#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue
function receiverinfocapture() {
    alreadycaped=`getprop sys.debug.receiverinfocapture`
    if [ "$alreadycaped" == "1" ] ;then
        return
    fi

    uuid=`cat /proc/sys/kernel/random/uuid`
    version=`getprop ro.build.version.ota`
    logtime=`date +%F-%H-%M-%S`
    logpath="${DATA_OPLUS_LOG_PATH}/DCS/de/stability_monitor"
    if [ ! -d "${logpath}" ]; then
        mkdir ${logpath}
        chown system:system ${logpath}
        chmod 777 ${logpath}
    fi
    filename="${logpath}/stability_receiversinfo@${uuid}@${version}@${logtime}.txt"
    dumpsys -t 60 activity broadcasts > ${filename}
    chown system:system ${filename}
    chmod 0666 ${filename}
    setprop sys.debug.receiverinfocapture 1
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/09/21.add for fix debug system_server register too many receivers issue
function binderthreadfullcapture() {
    capturetimestamp=`getprop sys.debug.receiverinfocapture.timestamp`
    current=`date "+%Y-%m-%d %H:%M:%S"`
    timestamp=`date -d "$current" +%s`
    let interval=$timestamp-$capturetimestamp
    if [ $interval -lt 10 ] ; then
        return
    fi

    capturefinish=`getprop sys.capturebinderthreadinfo.finished`
    if [ "$capturefinish" == "0" ] ;then
        return
    fi
    setprop sys.capturebinderthreadinfo.finished 0

    if [ ! -d ${SDCARD_LOG_BASE_PATH}/binderthread_info/ ];then
    mkdir -p ${SDCARD_LOG_BASE_PATH}/binderthread_info/
    fi
    LOGTIME=`date +%F-%H-%M-%S`
    BINDER_DIR=${SDCARD_LOG_BASE_PATH}/binderthread_info/binderthread_${LOGTIME}
    echo ${BINDER_DIR}
    mkdir -p ${BINDER_DIR}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${BINDER_DIR}/state
        cat /dev/binderfs/binder_logs/stats > ${BINDER_DIR}/stats
        cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_DIR}/transaction_log
        cat /dev/binderfs/binder_logs/transactions > ${BINDER_DIR}/transactions
    else
        cat /d/binder/state > ${BINDER_DIR}/state
        cat /d/binder/stats > ${BINDER_DIR}/stats
        cat /d/binder/transaction_log > ${BINDER_DIR}/transaction_log
        cat /d/binder/transactions > ${BINDER_DIR}/transactions
    fi
    ps -A -T > ${BINDER_DIR}/ps.txt

    kill -3 `pidof system_server`
    kill -3 `pidof com.android.phone`
    debuggerd -b `pidof netd` > "/data/anr/debuggerd_netd.txt"
    sleep 10
    cp -r /data/anr/*  ${BINDER_DIR}/
#package log folder to upload if logkit not enable
    logon=`getprop persist.sys.assert.panic`
    if [ ${logon} == "false" ];then
        current=`date "+%Y-%m-%d %H:%M:%S"`
        timeStamp=`date -d "$current" +%s`
        uuid=`cat /proc/sys/kernel/random/uuid`
        #uuid 0df1ed41-e0d6-40e2-8473-cdf7ccbd0d98
        otaversion=`getprop ro.build.version.ota`
        logzipname="${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/qp_binderinfo@"${uuid:0-12:12}@${otaversion}@${timeStamp}".tar.gz"
        tar -czf ${logzipname} ${BINDER_DIR}
        chown system:system ${logzipname}
    fi

    capturecount=`getprop debug.binderthreadfull.count`
    let capturecount=$capturecount+1
    setprop debug.binderthreadfull.count $capturecount

    current=`date "+%Y-%m-%d %H:%M:%S"`
    timeStamp=`date -d "$current" +%s`
    setprop sys.debug.receiverinfocapture.timestamp $timeStamp

    setprop sys.capturebinderthreadinfo.finished 1
}
#endif /*OPLUS_BUG_STABILITY*/

#Chunbo.Gao@ANDROID.DEBUG.2514795, 2019/11/12, Add for copy binder_info
function copybinderinfo() {
    CURTIME=`date +%F-%H-%M-%S`
    echo ${CURTIME}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${ANR_BINDER_PATH}/binder_info_${CURTIME}.txt
    else
        cat /sys/kernel/debug/binder/state > ${ANR_BINDER_PATH}/binder_info_${CURTIME}.txt
    fi
}

#Wuchao.Huang@ROM.Framework.EAP, 2019/11/19, Add for copy binder_info
function copyEapBinderInfo() {
    destBinderInfoPath=`getprop sys.eap.binderinfo.path`
    echo ${destBinderInfoPath}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${destBinderInfoPath}
    else
        cat /sys/kernel/debug/binder/state > ${destBinderInfoPath}
    fi
}

# add for ftm mode
function logcatftm(){
    FTM_CACHE_PATH=/cache/ftm_admin
    FTM_RESERVE_PATH=/mnt/vendor/oplusreserve/ftm_admin
    if [[ -d ${FTM_CACHE_PATH} ]]; then
        /system/bin/logcat -f ${FTM_CACHE_PATH}/apps/android_log_ftm.txt -r1024 -n 6 -v threadtime *:V
    else
        mkdir -p ${FTM_RESERVE_PATH}/apps/
        /system/bin/logcat -f ${FTM_RESERVE_PATH}/apps/android_log_ftm.txt -r1024 -n 6 -v threadtime *:V
    fi
}
function klogdftm(){
    FTM_CACHE_PATH=/cache/ftm_admin
    FTM_RESERVE_PATH=/mnt/vendor/oplusreserve/ftm_admin
    if [[ -d ${FTM_CACHE_PATH} ]]; then
        /system/system_ext/xbin/klogd -f ${FTM_CACHE_PATH}/kernel/kernel_log_ftm.txt -n -x -l 8
    else
        mkdir -p ${FTM_RESERVE_PATH}/kernel/
        /system/system_ext/xbin/klogd -f  ${FTM_RESERVE_PATH}/kernel/kernel_log_ftm.txt -n -x -l 8
    fi
}

# add for Sensor.logger
function resetlogpath(){
    setprop sys.oplus.logkit.appslog ""
    setprop sys.oplus.logkit.kernellog ""
    setprop sys.oplus.logkit.netlog ""
    setprop sys.oplus.logkit.assertlog ""
    setprop sys.oplus.logkit.anrlog ""
    setprop sys.oplus.logkit.tombstonelog ""
    setprop sys.oplus.logkit.fingerprintlog ""
    # Add for stopping catching fingerprint and face log
    dumpsys fingerprint log all 0
    dumpsys face log all 0
}

function gettpinfo() {
    tplogflag=`getprop persist.sys.oplusdebug.tpcatcher`
    # tplogflag=511
    # echo "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        echo "tplogflag == error"
    else

        echo "tplogflag == $tplogflag"
        # tplogflag=`echo $tplogflag | $XKIT awk '{print lshift($0, 1)}'`
        tpstate=0
        # tpstate=`echo $tplogflag | $XKIT awk '{print and($1, 1)}'`
        tpstate=$(($tplogflag & 1))
        echo "switch tpstate = $tpstate"
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off"
        else
            echo "switch tpstate on"
            DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
            kernellogpath=${DATA_LOG_KERNEL_PATH}/tp_debug_info
            subpath=$kernellogpath/${CURTIME}.txt
            mkdir -p $kernellogpath
            # mFlagMainRegister = 1 << 1
            # subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
            subflag=$((1 << 1))
            echo "1 << 1 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
                echo /proc/touchpanel/debug_info/main_register  >> $subpath
                cat /proc/touchpanel/debug_info/main_register  >> $subpath
            fi
            # mFlagSelfDelta = 1 << 2;
            # subflag=`echo | $XKIT awk '{print lshift(1, 2)}'`
            subflag=$((1 << 2))
            echo " 1<<2 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 2 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 2 $tpstate"
                echo /proc/touchpanel/debug_info/self_delta  >> $subpath
                cat /proc/touchpanel/debug_info/self_delta  >> $subpath
            fi
            # mFlagDetal = 1 << 3;
            # subflag=`echo | $XKIT awk '{print lshift(1, 3)}'`
              subflag=$((1 << 3))
            echo "1 << 3 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 3 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 3 $tpstate"
                echo /proc/touchpanel/debug_info/delta  >> $subpath
                cat /proc/touchpanel/debug_info/delta  >> $subpath
            fi
            # mFlatSelfRaw = 1 << 4;
            # subflag=`echo | $XKIT awk '{print lshift(1, 4)}'`
            subflag=$((1 << 4))
            echo "1 << 4 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 4 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 4 $tpstate"
                echo /proc/touchpanel/debug_info/self_raw  >> $subpath
                cat /proc/touchpanel/debug_info/self_raw  >> $subpath
            fi
            # mFlagBaseLine = 1 << 5;
            # subflag=`echo | $XKIT awk '{print lshift(1, 5)}'`
            subflag=$((1 << 5))
            echo "1 << 5 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 5 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 5 $tpstate"
                echo /proc/touchpanel/debug_info/baseline  >> $subpath
                cat /proc/touchpanel/debug_info/baseline  >> $subpath
            fi
            # mFlagDataLimit = 1 << 6;
            # subflag=`echo | $XKIT awk '{print lshift(1, 6)}'`
            subflag=$((1 << 6))
            echo "1 << 6 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 6 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 6 $tpstate"
                echo /proc/touchpanel/debug_info/data_limit  >> $subpath
                cat /proc/touchpanel/debug_info/data_limit  >> $subpath
            fi
            # mFlagReserve = 1 << 7;
            #subflag=`echo | $XKIT awk '{print lshift(1, 7)}'`
            subflag=$((1 << 7))
            echo "1 << 7 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 7 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 7 $tpstate"
                echo /proc/touchpanel/debug_info/reserve  >> $subpath
                cat /proc/touchpanel/debug_info/reserve  >> $subpath
            fi
            # mFlagTpinfo = 1 << 8;
            # subflag=`echo | $XKIT awk '{print lshift(1, 8)}'`
            subflag=$((1 << 8))
            echo "1 << 8 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & $tpstate))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 8 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 8 $tpstate"
            fi
            #cp  health_monitor
            if [ -f "/proc/touchpanel/debug_info/health_monitor" ]
            then
                echo /proc/touchpanel/debug_info/health_monitor  >> $subpath
                cat /proc/touchpanel/debug_info/health_monitor  >> $subpath
            else
                echo "/proc/touchpanel/debug_info/health_monitor is not exist"
            fi
            echo $tplogflag " end else"

            is_folder_empty=`ls /proc/touchpanel1/debug_info/*`
            if [ "$is_folder_empty" = "" ];then
                echo "/proc/touchpanel1/debug_info is empty"
            else
                echo "/proc/touchpanel1/debug_info is exited"
                echo "switch tpstate on"
                DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
                kernellogpath=${DATA_LOG_KERNEL_PATH}/tp_debug_info1
                subpath=$kernellogpath/${CURTIME}.txt
                mkdir -p $kernellogpath
                # mFlagMainRegister = 1 << 1
                # subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
                subflag=$((1 << 1))
                echo "1 << 1 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
                    echo /proc/touchpanel1/debug_info/main_register  >> $subpath
                    cat /proc/touchpanel1/debug_info/main_register  >> $subpath
                fi
                # mFlagSelfDelta = 1 << 2;
                # subflag=`echo | $XKIT awk '{print lshift(1, 2)}'`
                subflag=$((1 << 2))
                echo " 1<<2 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 2 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 2 $tpstate"
                    echo /proc/touchpanel1/debug_info/self_delta  >> $subpath
                    cat /proc/touchpanel1/debug_info/self_delta  >> $subpath
                fi
                # mFlagDetal = 1 << 3;
                # subflag=`echo | $XKIT awk '{print lshift(1, 3)}'`
                subflag=$((1 << 3))
                echo "1 << 3 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 3 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 3 $tpstate"
                    echo /proc/touchpanel1/debug_info/delta  >> $subpath
                    cat /proc/touchpanel1/debug_info/delta  >> $subpath
                fi
                # mFlatSelfRaw = 1 << 4;
                # subflag=`echo | $XKIT awk '{print lshift(1, 4)}'`
                subflag=$((1 << 4))
                echo "1 << 4 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 4 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 4 $tpstate"
                    echo /proc/touchpanel1/debug_info/self_raw  >> $subpath
                    cat /proc/touchpanel1/debug_info/self_raw  >> $subpath
                fi
                # mFlagBaseLine = 1 << 5;
                # subflag=`echo | $XKIT awk '{print lshift(1, 5)}'`
                subflag=$((1 << 5))
                echo "1 << 5 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 5 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 5 $tpstate"
                    echo /proc/touchpanel1/debug_info/baseline  >> $subpath
                    cat /proc/touchpanel1/debug_info/baseline  >> $subpath
                fi
                # mFlagDataLimit = 1 << 6;
                # subflag=`echo | $XKIT awk '{print lshift(1, 6)}'`
                subflag=$((1 << 6))
                echo "1 << 6 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 6 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 6 $tpstate"
                    echo /proc/touchpanel1/debug_info/data_limit  >> $subpath
                    cat /proc/touchpanel1/debug_info/data_limit  >> $subpath
                fi
                # mFlagReserve = 1 << 7;
                # subflag=`echo | $XKIT awk '{print lshift(1, 7)}'`
                subflag=$((1 << 7))
                echo "1 << 7 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 7 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 7 $tpstate"
                    echo /proc/touchpanel1/debug_info/reserve  >> $subpath
                    cat /proc/touchpanel1/debug_info/reserve  >> $subpath
                fi
                # mFlagTpinfo = 1 << 8;
                # subflag=`echo | $XKIT awk '{print lshift(1, 8)}'`
                subflag=$((1 << 8))
                echo "1 << 8 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 8 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 8 $tpstate"
                fi
                #cp  health_monitor
                if [ -f "/proc/touchpanel1/debug_info/health_monitor" ]
                then
                    echo /proc/touchpanel1/debug_info/health_monitor  >> $subpath
                    cat /proc/touchpanel1/debug_info/health_monitor  >> $subpath
                else
                    echo "/proc/touchpanel1/debug_info/health_monitor is not exist"
                fi
                echo $tplogflag " end else"
            fi
            #cp test cvs file
            LOG_TPTEST_PATH=/sdcard/TpTestReport
            if [ -d "${LOG_TPTEST_PATH}" ]; then
                traceTransferState "INITOPLUSLOG:TpTestReport copy..."
                cp -rf /sdcard/TpTestReport   ${DATA_LOG_KERNEL_PATH}/
            fi
        fi
    fi
}

function getSystemStatus() {
    traceTransferState "dumpSystem:start...."
    boot_completed=`getprop sys.boot_completed`
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    if [[ x${boot_completed} == x"1" ]]; then
        outputPath="${newpath}/SI_stop"

        traceTransferState "dumpSystem:${outputPath}"
        if [ ! -d ${outputPath} ]; then
            mkdir -p ${outputPath}
        fi
        rm -f ${outputPath}/finish_system
        dumpsys -t 15 meminfo > ${outputPath}/dumpsys_mem.txt &

        setprop sys.tranfer.finished mv:meminfo

        traceTransferState "dumpSystem:ps,top"
        ps -T -A > ${outputPath}/ps.txt
        top -n 1 -s 10 > ${outputPath}/top.txt
        cat /proc/meminfo > ${outputPath}/proc_meminfo.txt
        cat /proc/interrupts > ${outputPath}/interrupts.txt
        cat /sys/kernel/debug/wakeup_sources > ${outputPath}/wakeup_sources.log
        traceTransferState "dumpSystem:getprop"
        getprop > ${outputPath}/prop.txt
        traceTransferState "dumpSystem:df"
        df > ${outputPath}/df.txt
        traceTransferState "dumpSystem:mount"
        mount > ${outputPath}/mount.txt
        traceTransferState "dumpSystem:cat"
        cat data/system/packages.xml  > ${outputPath}/packages.txt
        cat data/system/appops.xml  > ${outputPath}/appops.xml
        traceTransferState "dumpSystem:dumpsys appops"
        dumpsys appops > ${outputPath}/dumpsys_appops.xml
        cat /proc/zoneinfo > ${outputPath}/zoneinfo.txt
        cat /proc/slabinfo > ${outputPath}/slabinfo.txt
        cp -rf /sys/kernel/debug/ion ${outputPath}/
        cp -rf /sys/kernel/debug/dma_buf ${outputPath}/
        logcat -S > ${outputPath}/logStatistics_${CURTIME}.txt

        cat /proc/osvelte/dma_buf/bufinfo > ${SYSTEM_STATUS_PATH}/dma_buf_bufinfo.txt
        cat /proc/osvelte/dma_buf/procinfo > ${SYSTEM_STATUS_PATH}/dma_buf_procinfo.txt

        traceTransferState "dumpSystem:dumpsys notification"
        dumpsys notification > ${outputPath}/dumpsys_notification.xml
        cat /data/system/notification_policy.xml > ${outputPath}/notification_policy.xml
        traceTransferState "dumpSystem:notification done"

        traceTransferState "dumpSystem:user"
        dumpsys user > ${outputPath}/dumpsys_user.txt
        dumpsys power > ${outputPath}/dumpsys_power.txt
        dumpsys cpuinfo > ${outputPath}/dumpsys_cpuinfo.txt
        dumpsys alarm > ${outputPath}/dumpsys_alarm.txt
        dumpsys batterystats > ${outputPath}/dumpsys_batterystats.txt
        dumpsys batterystats -c > ${outputPath}/dumpsys_battersystats_for_bh.txt
        dumpsys activity exit-info > ${outputPath}/dumpsys_exit_info.txt
        dumpsys location > ${outputPath}/dumpsys_location.txt
        dumpsys nfc > ${outputPath}/dumpsys_nfc.txt
        dumpsys secure_element > ${outputPath}/dumpsys_secure_element.txt
        traceTransferState "dumpSystem:package"
        dumpsys package --da > ${outputPath}/dumpsys_package.txt
        traceTransferState "dumpSystem:dropbox"
        dumpsys dropbox --print > ${outputPath}/dumpsys_dropbox_all.txt
        #philip.huang@NETWORK.CFG, 2021/08/04, Add for dumpsys CarrierConfig info [OCR.1717966.1.OM.ALL]
        dumpsys carrier_config > ${outputPath}/dumpsys_carrier_config.txt

        traceTransferState "dumpSystem:settings"
        dumpsys settings --no-config --all-history > ${outputPath}/dumpsys_settings_no_config_all_history.txt
        traceTransferState "dumpSystem:settings done"

        #yong8.huang@ANDROID.AMS, 2020/12/30, Add for dumpsys activity info
        dumpsys activity processes > ${outputPath}/dumpsys_processes.txt
        dumpsys activity broadcasts > ${outputPath}/dumpsys_broadcasts.txt
        dumpsys activity providers > ${outputPath}/dumpsys_providers.txt
        dumpsys activity services > ${outputPath}/dumpsys_services.txt

        #Hun.Xu@ANDROID.SENSOR,2021/07/16, Add for dumpsys sensorservice info
        dumpsys sensorservice > ${outputPath}/dumpsys_sensorservice.txt

        #Qianyou.Chen@Android.MULTIUSER, 2021/12/13, Add for dumpsys accessibility services
        dumpsys accessibility > ${outputPath}/dumpsys_accessibility.txt
        #Qianyou.Chen@Android.MULTIUSER, 2021/12/13, Add for dumpsys device/profile owner
        dumpsys device_policy > ${outputPath}/dumpsys_devicepolicy.txt

        ##kevin.li@ROM.Framework, 2019/11/5, add for hans freeze manager(for protection)
        hans_enable=`getprop persist.sys.enable.hans`
        if [ "$hans_enable" == "true" ]; then
            dumpsys activity hans history > ${outputPath}/dumpsys_hans_history.txt
        fi
        #kevin.li@ROM.Framework, 2019/12/2, add for hans cts property
        hans_enable=`getprop persist.vendor.enable.hans`
        if [ "$hans_enable" == "true" ]; then
            dumpsys activity hans history > ${outputPath}/dumpsys_hans_history.txt
        fi

        #chao.zhu@ROM.Framework, 2020/04/17, add for preload
        preload_enable=`getprop persist.vendor.enable.preload`
        if [ "$preload_enable" == "true" ]; then
            dumpsys activity preload > ${outputPath}/dumpsys_preload.txt
        fi

        #qingxin.guo@ROM.Framework, 2022/04/25, add for cpulimit
        cpulimit_enable=`getprop persist.vendor.enable.cpulimit`
        if [ "$cpulimit_enable" == "true" ]; then
            dumpsys activity cpulimit history > ${outputPath}/dumpsys_cpulimit_history.txt
        fi

        #liqiang3@ANROID.RESCONTROL, 2021/12/14, add for jobscheduler
        dumpsys jobscheduler > ${outputPath}/dumpsys_jobscheduler.txt

        #kevin.li@ANDROID.RESCONTROL, 2021/10/18, add for Osense
        dumpsys osensemanager log > ${outputPath}/dumpsys_osense_log.txt

        #CaiLiuzhuang@MULTIMEDIA.AUDIODRIVER.FEATURE, 2021/01/18, Add for dump media log
        dumpMedia

        wait
        getMemoryMap;

        touch ${outputPath}/finish_system
        traceTransferState "dumpSystem:done...."
    fi
}

#Zhiming.chen@ANDROID.DEBUG 2724830, 2020/01/04,
function getMemoryMap() {
    traceTransferState " dumpSystem:memory map start...."
    LI=0
    LMI=4
    LMM=0
    MEMORY=921600
    PROCESS_MEMORY=819200
    RESIDUE_MEMORY=`cat proc/meminfo | grep MemAvailable | tr -cd "[0-9]"`
    if [ $RESIDUE_MEMORY -lt $MEMORY ] ; then
        while read -r line
        do
            if [ $LI -gt $LMM -a $LI -lt $LMI ] ; then
                let LI=$LI+1;
                echo $line
                PROMEM=`echo $line | grep -o '.*K' | tr -cd "[0-9]"`
                echo $PROMEM
                PID=`echo $line | grep -o '(.*)' | tr -cd "[0-9]"`
                echo $PID
                if [ $PROMEM -gt $PROCESS_MEMORY ] ; then
                    cat proc/$PID/smaps > ${outputPath}/pid$PID-smaps.txt
                    dumpsys meminfo $PID > ${outputPath}/pid$PID-dumpsysmen.txt
                fi
                if [ $LI -eq $LMI ] ; then
                    break
                fi
            fi
            if [ "$line"x = "Total PSS by process:"x ] ; then
                echo $line
                let LI=$LI+1;
            fi
        done < ${outputPath}/dumpsys_mem.txt
    fi
    traceTransferState "dumpSystem:memory map done...."
}

#CaiLiuzhuang@MULTIMEDIA.AUDIODRIVER.FEATURE, 2021/01/18, Add for dump media log
function dumpMedia() {
    mediaTypes=(media bluetooth thirdpart)
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    if [[ "${mediaTypes[@]}" != *"${LOG_TYPE}"* ]]; then
        return
    fi
    mediaPath="${outputPath}/media"
    mkdir -p ${mediaPath}
    traceTransferState "dumpMedia:start...."
    dumpsys media.audio_flinger > ${mediaPath}/audio_flinger.txt
    dumpsys media.audio_policy > ${mediaPath}/audio_policy.txt
    dumpsys media.metrics > ${mediaPath}/media_metrics.txt
    dumpsys media_session > ${mediaPath}/media_session.txt
    dumpsys media_router > ${mediaPath}/media_router.txt
    dumpsys audio > ${mediaPath}/audioservice.txt
    dumpsys media.player > ${mediaPath}/media_player.txt
    pid_audioserver=`pgrep -f audioserver`
    debuggerd -b ${pid_audioserver} > ${mediaPath}/audioserver.txt
    pid_audiohal=`pgrep -f audio.service`
    debuggerd -b ${pid_audiohal} > ${mediaPath}/audiohal.txt
    atlasservice=`pgrep -f atlasservice`
    debuggerd -b ${atlasservice} > ${mediaPath}/atlasservice.txt
    system_server=`pgrep -f system_server`
    debuggerd -j ${system_server} > ${mediaPath}/system_server.txt
    multimedia=`pgrep -f persist.multimedia`
    debuggerd -j ${multimedia} > ${mediaPath}/multimedia.txt
    traceTransferState "dumpMedia:done...."
}

#Chunbo.Gao@ANDROID.DEBUG 2020/6/18, Add for ...
function delcustomlog() {
    echo "delcustomlog begin"
    rm -rf ${DATA_DEBUGGING_PATH}/customer
    echo "delcustomlog end"
}

function customdmesg() {
    echo "customdmesg begin"
    chmod 777 -R ${DATA_DEBUGGING_PATH}/
    echo "customdmesg end"
}

function customdiaglog() {
    echo "customdiaglog begin"
    chmod 777 -R ${DATA_DEBUGGING_PATH}/customer
    restorecon -RF ${DATA_DEBUGGING_PATH}/customer
    echo "customdiaglog end"
}

function cameraloginit() {
    logdsize=`getprop persist.logd.size`
    echo "get logdsize ${logdsize}"
    if [ "${logdsize}" = "" ]
    then
        echo "camere init set log size 16M"
         setprop persist.logd.size 16777216
    fi
}
#================================== COMMON LOG =========================

#ifdef OPLUS_BUG_DEBUG
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
function dumpWm() {
    panicstate=`getprop persist.sys.assert.panic`
    dumpenable=`getprop debug.screencapdump.enable`
    if [ "$panicstate" == "true" ] && [ "$dumpenable" == "true" ]
    then
        if [ ! -d ${DATA_DEBUGGING_PATH}/wm/ ];then
        mkdir -p ${DATA_DEBUGGING_PATH}/wm/
        fi

        LOGTIME=`date +%F-%H-%M-%S`
        DIR=${DATA_DEBUGGING_PATH}/wm/${LOGTIME}
        mkdir -p ${DIR}
        dumpsys window -a > ${DIR}/windows.txt
        dumpsys activity a > ${DIR}/activities.txt
        dumpsys activity -v top > ${DIR}/top_activity.txt
        dumpsys SurfaceFlinger > ${DIR}/sf.txt
        dumpsys input > ${DIR}/input.txt
        ps -A > ${DIR}/ps.txt
        mv -f ${DATA_DEBUGGING_PATH}/wm_log.pb ${DIR}/wm_log.pb
        getLogStatistics
    fi
}
function transferWm() {
    mkdir -p ${newpath}/wm
    mv -f ${DATA_DEBUGGING_PATH}/wm/* ${newpath}/wm
}
#endif /* OPLUS_BUG_DEBUG */

function getLogStatistics() {
    LOG_STATISTICS_PATH=${DATA_DEBUGGING_PATH}/logStatistics
    if [ ! -d ${LOG_STATISTICS_PATH} ]; then
        mkdir -p ${LOG_STATISTICS_PATH}
    fi
    logcat -S > ${DATA_DEBUGGING_PATH}/logStatistics/logStatistics_${CURTIME}.txt
}

function inittpdebug(){
    panicstate=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    tplogflag=`getprop persist.sys.oplusdebug.tpcatcher`
    if [ "$tplogflag" != "" ]
    then
        echo "inittpdebug not empty panicstate = $panicstate tplogflag = $tplogflag"
        if [ "$panicstate" == "true" ] || [ x"${camerapanic}" = x"true" ]
        then
            # tplogflag=`echo $tplogflag , | $XKIT awk '{print or($1, 1)}'`
            tplogflag=$(($tplogflag | 1))
        else
            # tplogflag=`echo $tplogflag , | $XKIT awk '{print and($1, 510)}'`
            tplogflag=$(($tplogflag & 1))
        fi
        setprop persist.sys.oplusdebug.tpcatcher $tplogflag
    fi
}
function settplevel(){
    tplevel=`getprop persist.sys.oplusdebug.tplevel`
    if [ "$tplevel" == "0" ]
    then
        echo 0 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "1" ]
    then
        echo 1 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "2" ]
    then
        echo 2 > /proc/touchpanel/debug_level
    fi
}

function qmilogon() {
    echo "qmilogon begin"
    qmilog_switch=`getprop persist.sys.qmilog.switch`
    echo ${qmilog_switch}
    if [ "$qmilog_switch" == "true" ]; then
        setprop ctl.start adspglink
        setprop ctl.start modemglink
        setprop ctl.start cdspglink
        setprop ctl.start modemqrtr
        setprop ctl.start sensorqrtr
        setprop ctl.start npuqrtr
        setprop ctl.start slpiqrtr
        setprop ctl.start slpiglink
    fi
    echo "qmilogon end"
}
function qmilogoff() {
    echo "qmilogoff begin"
    qmilog_switch=`getprop persist.sys.qmilog.switch`
    echo ${qmilog_switch}
    if [ "$qmilog_switch" == "true" ]; then
        setprop ctl.stop adspglink
        setprop ctl.stop modemglink
        setprop ctl.stop cdspglink
        setprop ctl.stop modemqrtr
        setprop ctl.stop sensorqrtr
        setprop ctl.stop npuqrtr
        setprop ctl.stop slpiqrtr
        setprop ctl.stop slpiglink
    fi
    echo "qmilogoff end"
}
function adspglink() {
    echo "adspglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/adsp/log_cont > ${path}/adsp_glink.log
        cat /d/ipc_logging/diag/log_cont > ${path}/diag_ipc_glink.log &
    fi
}
function modemglink() {
    echo "modemglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/modem/log_cont > ${path}/modem_glink.log
    fi
}
function cdspglink() {
    echo "cdspglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/cdsp/log_cont > ${path}/cdsp_glink.log
    fi
}
function modemqrtr() {
    echo "modemqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_0/log_cont > ${path}/modem_qrtr.log
    fi
}
function sensorqrtr() {
    echo "sensorqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_5/log_cont > ${path}/sensor_qrtr.log
    fi
}
function npuqrtr() {
    echo "NPUqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_10/log_cont > ${path}/NPU_qrtr.log
    fi
}
function slpiqrtr() {
    echo "slpiqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_9/log_cont > ${path}/slpi_qrtr.log
    fi
}
function slpiglink() {
    echo "slpiglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/slpi/log_cont > ${path}/slpi_glink.log
    fi
}

#================================== STABILITY =========================
function dumpon(){
    platform=`getprop ro.board.platform`

    echo full > /sys/kernel/dload/dload_mode
    echo 0 > /sys/kernel/dload/emmc_dload

    dump_log_dir_v1="/sys/bus/msm_subsys/devices"
    dump_log_dir_v2="/sys/class/remoteproc"
    dump_sm8450_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca6490"
    #lixiong@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2022/08/11, add for sm8550
    dump_sm8550_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca-converged"

    #XiaSong@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2022/2/11, add for SM7450S wlan minidump
    dump_sm7450_wlan_log_dir="/sys/devices/platform/soc/8a00000.remoteproc-wpss/remoteproc/remoteproc3"

    modem_crash_not_reboot_to_dump=`getprop persist.sys.modem.crash.noreboot`
    adsp_crash_not_reboot_to_dump=`getprop persist.sys.adsp.crash.noreboot`
    wlan_crash_not_reboot_to_dump=`getprop persist.sys.wlan.crash.noreboot`
    cdsp_crash_not_reboot_to_dump=`getprop persist.sys.cdsp.crash.noreboot`
    slpi_crash_not_reboot_to_dump=`getprop persist.sys.slpi.crash.noreboot`
    ap_crash_only=`getprop persist.sys.ap.crash.only`

    if [ -d ${dump_log_dir_v1} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v1}`
        for i in $ALL_FILE;
        do
            echo ${i}
            if [ -d ${dump_log_dir_v1}/${i} ]; then
                echo ${dump_log_dir_v1}/${i}/restart_level
                chmod 0666 ${dump_log_dir_v1}/${i}/restart_level
                subsys_name=`cat /sys/bus/msm_subsys/devices/${i}/name`
                if [ "${ap_crash_only}" = "true" ] ; then
                    echo related > ${dump_log_dir_v1}/${i}/restart_level
                else
                    if [ "${subsys_name}" = "modem" ] && [ "${modem_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "adsp" ] && [ "${adsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "wlan" ] && [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "cdsp" ] && [ "${cdsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "slpi" ] && [ "${slpi_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    else
                        echo system > ${dump_log_dir_v1}/${i}/restart_level
                    fi
                fi
            fi
        done
    fi

    if [ -d ${dump_log_dir_v2} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v2}`
        for i in $ALL_FILE;
        do
            echo "${dump_log_dir_v2}/${i}"
            if [ -d ${dump_log_dir_v2}/${i} ]; then
                subsys_name=`cat ${dump_log_dir_v2}/${i}/name`
                if [ "${ap_crash_only}" = "true" ] ; then
                    setprop persist.vendor.ssr.restart_level ALL_ENABLE
                    echo enabled > ${dump_log_dir_v2}/${i}/coredump
                    echo enabled > ${dump_log_dir_v2}/${i}/recovery
                else
                    if [ "${subsys_name}" = "4080000.remoteproc-mss" ] && [ "${modem_crash_not_reboot_to_dump}" = "true" ] ; then
                        setprop persist.vendor.ssr.restart_level ALL_ENABLE
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    elif [ "${subsys_name}" = "3000000.remoteproc-adsp" ] && [ "${adsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    elif [ "${subsys_name}" = "32300000.remoteproc-cdsp" ] && [ "${cdsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    elif [ "${subsys_name}" = "2400000.remoteproc-slpi" ] && [ "${slpi_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    else
                        setprop persist.vendor.ssr.restart_level ALL_DISABLE
                        echo disabled > ${dump_log_dir_v2}/${i}/coredump
                        echo disabled > ${dump_log_dir_v2}/${i}/recovery
                    fi
                fi
            fi
        done
    fi

    if [ -d ${dump_sm8450_wlan_log_dir} ]; then
        echo 0 > ${dump_sm8450_wlan_log_dir}/recovery
    fi

    #lixiong@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2022/08/11, add for sm8550
    if [ -d ${dump_sm8550_wlan_log_dir} ]; then
        echo 0 > ${dump_sm8550_wlan_log_dir}/recovery
    fi

    #XiaSong@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2022/2/11, add for SM7450S wlan minidump
    if [ -d ${dump_sm7450_wlan_log_dir} ]; then
        echo "disabled" > ${dump_sm7450_wlan_log_dir}/coredump
        echo "disabled" > ${dump_sm7450_wlan_log_dir}/recovery
    fi
}

function dumpoff(){
    platform=`getprop ro.board.platform`


    echo mini > /sys/kernel/dload/dload_mode
    echo 1 > /sys/kernel/dload/emmc_dload

#Chunbo.Gao@ANDROID.DEBUG.1974273, 2019/4/22, Add for dumpoff
    dump_log_dir_v1="/sys/bus/msm_subsys/devices"
    dump_log_dir_v2="/sys/class/remoteproc"
    dump_sm8450_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca6490"
    #lixiong@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2022/08/11, add for sm8550
    dump_sm8550_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca-converged"

    #XiaSong@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2022/2/11, add for SM7450S wlan minidump
    dump_sm7450_wlan_log_dir="/sys/devices/platform/soc/8a00000.remoteproc-wpss/remoteproc/remoteproc3"

    if [ -d ${dump_log_dir_v1} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v1}`
        for i in $ALL_FILE;
        do
            echo ${i}
            if [ -d ${dump_log_dir_v1}/${i} ]; then
               echo ${dump_log_dir_v1}/${i}/restart_level
               echo related > ${dump_log_dir_v1}/${i}/restart_level
            fi
        done
    fi

    if [ -d ${dump_log_dir_v2} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v2}`
        for i in $ALL_FILE;
        do
            echo "${dump_log_dir_v2}/${i}"
            if [ -d ${dump_log_dir_v2}/${i} ]; then
               setprop persist.vendor.ssr.restart_level ALL_ENABLE
               echo enabled > ${dump_log_dir_v2}/${i}/coredump
               echo enabled > ${dump_log_dir_v2}/${i}/recovery
            fi
        done
    fi

    if [ -d ${dump_sm8450_wlan_log_dir} ]; then
        echo 1 > ${dump_sm8450_wlan_log_dir}/recovery
    fi

    #lixiong@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2022/08/11, add for sm8550
    if [ -d ${dump_sm8550_wlan_log_dir} ]; then
        echo 1 > ${dump_sm8550_wlan_log_dir}/recovery
    fi

    #XiaSong@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2022/2/11, add for SM7450S wlan minidump
    if [ -d ${dump_sm7450_wlan_log_dir} ]; then
        echo "enabled" > ${dump_sm7450_wlan_log_dir}/coredump
        echo "enabled" > ${dump_sm7450_wlan_log_dir}/recovery
    fi
}

#Qi.Zhang@TECH.BSP.Stability 2019/09/20, Add for uefi log
function LogcatUefi(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ];then
        mkdir -p  ${CACHE_PATH}/uefi
        /system/system_ext/bin/extractCurrentUefiLog
    fi
}

function DumpEnvironment(){
    rm  -rf /cache/environment
    umask 000
    mkdir -p /cache/environment
    chmod 777 /data/misc/gpu/gpusnapshot/*
    ls -l /data/misc/gpu/gpusnapshot/ > /cache/environment/snapshotlist.txt
    cp -rf /data/misc/gpu/gpusnapshot/* /cache/environment/
    chmod 777 /cache/environment/dump*
    rm -rf /data/misc/gpu/gpusnapshot/*
    #ps -A > /cache/environment/ps.txt &
    ps -AT > /cache/environment/ps_thread.txt &
    mount > /cache/environment/mount.txt &
    futexwait_log="${DATA_OPLUS_LOG_PATH}/futexwait_log"
    if [ -d  ${futexwait_log} ];
    then
        all_logs=`ls ${futexwait_log}`
        for i in ${all_logs};do
            echo ${i}
            cp /data/system/dropbox/futexwait_log/${i}  /cache/environment/futexwait_log_${i}
        done
        chmod 777 /cache/environment/futexwait_log*
    fi
    getprop > /cache/environment/prop.txt &
    dumpsys SurfaceFlinger --dispsync > /cache/environment/sf_dispsync.txt &
    dumpsys SurfaceFlinger > /cache/environment/sf.txt &
    /system/bin/dmesg > /cache/environment/dmesg.txt &
    /system/bin/logcat -d -v threadtime > /cache/environment/android.txt &
    /system/bin/logcat -b radio -d -v threadtime > /cache/environment/radio.txt &
    /system/bin/logcat -b events -d -v threadtime > /cache/environment/events.txt &
    i=`pidof system_server`
    ls /proc/$i/fd -al > /cache/environment/system_server_fd.txt &
    ps -A -T | grep $i > /cache/environment/system_server_thread.txt &
    cp -rf /data/system/packages.xml /cache/environment/packages.xml
    chmod +r /cache/environment/packages.xml
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > /cache/environment/binder_info.txt &
    else
        cat /sys/kernel/debug/binder/state > /cache/environment/binder_info.txt &
    fi
    cat /proc/meminfo > /cache/environment/proc_meminfo.txt &
    cat /d/ion/heaps/system > /cache/environment/iom_system_heaps.txt &
    #Yufeng.liu@Plf.AD.Performance, 2020/06/10, Add for ion memory leak
    cat /d/dma_buf/bufinfo > /cache/environment/dma_bufinfo.txt &
    cat /d/dma_buf/dmaprocs > /cache/environment/dma_dmaprocs.txt &
    df -k > /cache/environment/df.txt &
    ls -l /data/anr > /cache/environment/anr_ls.txt &
    du -h -a /data/system/dropbox > /cache/environment/dropbox_du.txt &
    watchdogfile=`getprop persist.sys.oplus.watchdogtrace`
    #Chunbo.Gao@ANDROID.DEBUG.BugID, 2019/4/23, Add for ...
    cp -rf ${DATA_DEBUGGING_PATH}/sf/backtrace/* /cache/environment/
    chmod 777 cache/environment/*
    if [ x"$watchdogfile" != x"0" ] && [ x"$watchdogfile" != x"" ]
    then
        chmod 666 $watchdogfile
        cp -rf $watchdogfile /cache/environment/
        setprop persist.sys.oplus.watchdogtrace 0
    fi
    wait
    setprop sys.dumpenvironment.finished 1
    umask 077
}

function packupminidump() {

    timestamp=`getprop sys.oplus.minidump.ts`
    echo time ${timestamp}
    uuid=`getprop sys.oplus.minidumpuuid`
    otaversion=`getprop ro.build.version.ota`
    minidumppath="${DATA_OPLUS_LOG_PATH}/DCS/de/minidump"
    #tag@hash@ota@datatime
    packupname=${minidumppath}/SYSTEM_LAST_KMSG@${uuid}@${otaversion}@${timestamp}
    echo name ${packupname}
    #read device info begin
    #"/proc/oplusVersion/serialID",
    #"/proc/devinfo/ddr",
    #"/proc/devinfo/emmc",
    #"proc/devinfo/emmc_version"};
    model=`getprop ro.product.model`
    version=`getprop ro.build.version.ota`
    echo "model:${model}" > ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "version:${version}" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/serialID" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/serialID >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "\n/proc/devinfo/ddr" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ddr >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/ocp" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/ocp >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cp /data/system/packages.xml ${DATA_OPLUS_LOG_PATH}/DCS/minidump/packages.xml
    echo "tar -czvf ${packupname} -C ${DATA_OPLUS_LOG_PATH}/DCS/minidump ." >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    tar -czvf ${packupname}.dat.gz.tmp -C ${DATA_OPLUS_LOG_PATH}/DCS/minidump .
    echo "chown system:system ${packupname}*" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    chown system:system ${packupname}*
    echo "mv ${packupname}.dat.gz.tmp ${packupname}.dat.gz" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    mv ${packupname}.dat.gz.tmp ${packupname}.dat.gz
    chown system:system ${packupname}*
    echo "-rf ${DATA_OPLUS_LOG_PATH}/DCS/minidump"
    rm -rf ${DATA_OPLUS_LOG_PATH}/DCS/minidump
    #setprop sys.oplus.phoenix.handle_error ERROR_REBOOT_FROM_KE_SUCCESS
    setprop sys.backup.minidump.tag "SYSTEM_LAST_KMSG"
    setprop ctl.start backup_minidumplog
}

function olcpackupminidump() {

    echo time ${timestamp}
    model=`getprop ro.product.model`
    version=`getprop ro.build.version.ota`
    echo "model:${model}" > ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "version:${version}" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/serialID" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/serialID >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "\n/proc/devinfo/ddr" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ddr >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/ocp" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/ocp >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "chown system:system ${DATA_OPLUS_LOG_PATH}/DCS/minidump/*" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    chown system:system ${DATA_OPLUS_LOG_PATH}/DCS/minidump/*
    setprop sys.backup.minidump.tag "SYSTEM_LAST_KMSG"
}

#Fangfang.Hui@TECH.AD.Stability, 2019/08/13, Add for the quality feedback dcs config
function backupMinidump() {
    tag=`getprop sys.backup.minidump.tag`
    if [ x"$tag" = x"" ]; then
        echo "backup.minidump.tag is null, do nothing"
        return
    fi
    minidumppath="${DATA_OPLUS_LOG_PATH}/DCS/de/minidump"
    miniDumpFile=$minidumppath/$(ls -t ${minidumppath} | head -1)
    if [ x"$miniDumpFile" = x"" ]; then
        echo "minidump.file is null, do nothing"
        return
    fi
    result=$(echo $miniDumpFile | grep "${tag}")
    if [ x"$result" = x"" ]; then
        echo "tag mismatch, do not backup"
        return
    else
        try_copy_minidump_to_oplusreserve $miniDumpFile
        setprop sys.backup.minidump.tag ""
    fi
}

function try_copy_minidump_to_oplusreserve() {
    OPLUSRESERVE_MINIDUMP_BACKUP_PATH="${DATA_OPLUS_LOG_PATH}/oplusreserve/media/log/minidumpbackup"
    OPLUSRESERVE2_MOUNT_POINT="/mnt/vendor/oplusreserve"

    if [ ! -d ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} ]; then
        mkdir ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    fi

    NewLogPath=$1
    if [ ! -f $NewLogPath ] ;then
        echo "Can not access ${NewLogPath}, the file may not exists "
        return
    fi
    TmpLogSize=$(du -sk ${NewLogPath} | sed 's/[[:space:]]/,/g' | cut -d "," -f1)
    curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
    echo "curBakCount = ${curBakCount}, TmpLogSize = ${TmpLogSize}, NewLogPath = ${NewLogPath}"
    while [ ${curBakCount} -gt 2 ]   #can only save 2 backup minidump logs at most
    do
        rm -rf ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
        curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        echo "delete one file curBakCount = $curBakCount"
    done
    FreeSize=$(df -ak | grep "${OPLUSRESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
    TotalSize=$(df -ak | grep "${OPLUSRESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f2)
    ReserveSize=`expr $TotalSize / 5`
    NeedSize=`expr $TmpLogSize + $ReserveSize`
    echo "NeedSize = ${NeedSize}, ReserveSize = ${ReserveSize}, FreeSize = ${FreeSize}"
    while [ ${FreeSize} -le ${NeedSize} ]
    do
        curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        if [ $curBakCount -gt 1 ]; then #leave at most on log file
            rm -rf ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
            echo "${OPLUSRESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, delete one de minidump"
            FreeSize=$(df -k | grep "${OPLUSRESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
            continue
        fi
        echo "${OPLUSRESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, nothing to delete"
        return 0
    done
    #space is enough, now copy
    cp $NewLogPath $OPLUSRESERVE_MINIDUMP_BACKUP_PATH
    chmod -R 0771 ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    chown -R system ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    chgrp -R system ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
}

#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
function perf_record() {
    check_interval=`getprop persist.sys.oppo.perfinteval`
    if [ x"${check_interval}" = x"" ]; then
        check_interval=60
    fi
    perf_record_path=${DATA_DEBUGGING_PATH}/perf_record_logs
    while [ true ];do
        if [ ! -d ${perf_record_path} ];then
            mkdir -p ${perf_record_path}
        fi

        echo "\ndate->" `date` >> ${perf_record_path}/cpu.txt
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq >> ${perf_record_path}/cpu.txt

        echo "\ndate->" `date` >> ${perf_record_path}/mem.txt
        cat /proc/meminfo >> ${perf_record_path}/mem.txt

        echo "\ndate->" `date` >> ${perf_record_path}/buddyinfo.txt
        cat /proc/buddyinfo >> ${perf_record_path}/buddyinfo.txt

        echo "\ndate->" `date` >> ${perf_record_path}/top.txt
        top -n 1 >> ${perf_record_path}/top.txt

        topneocount=0
        if [ $topneocount -le 10 ]; then
            topneo=`top -n 1 | grep neo | awk '{print $9}' | head -n 1 | awk -F . '{print $1}'`;
            if [ $topneo -gt 90 ]; then
                neopid=`ps -A | grep neo | awk '{print $2}'`;
                echo "\ndate->" `date` >> ${perf_record_path}/neo_debuggerd.txt
                debuggerd $neopid >> ${perf_record_path}/neo_debuggerd.txt;
                let topneocount+=1
            fi
        fi

        sleep "$check_interval"
    done
}

#Jianping.Zheng@PSW.Android..Stability.Crash, 2017/06/20, Add for collect futexwait block log
function collect_futexwait_log() {
    collect_path=${DATA_OPLUS_LOG_PATH}/futexwait_log
    if [ ! -d ${collect_path} ]
    then
        mkdir -p ${collect_path}
        chmod 700 ${collect_path}
        chown system:system ${collect_path}
    fi

    #time
    echo `date` > ${collect_path}/futexwait.time.txt

    #ps -t info
    ps -A -T > $collect_path/ps.txt

    #D status to dmesg
    echo w > /proc/sysrq-trigger

    #systemserver trace
    system_server_pid=`pidof system_server`
    kill -3 ${system_server_pid}
    sleep 10
    cp /data/anr/traces.txt $collect_path/

    #systemserver native backtrace
    debuggerd -b ${system_server_pid} > $collect_path/systemserver.backtrace.txt
}

#Fuchun.Liao@BSP.CHG.Basic 2019/06/09 modify for black/bright check
function create_black_bright_check_file(){
	if [ ! -d "/data/oplus/log/bsp" ]; then
		mkdir -p /data/oplus/log/bsp
		chmod -R 777 /data/oplus/log/bsp
		chown -R system:system /data/oplus/log/bsp
	fi

	if [ ! -f "/data/oplus/log/bsp/blackscreen_count.txt" ]; then
		touch /data/oplus/log/bsp/blackscreen_count.txt
		echo 0 > /data/oplus/log/bsp/blackscreen_count.txt
	fi
	chmod 0664 /data/oplus/log/bsp/blackscreen_count.txt

	if [ ! -f "/data/oplus/log/bsp/blackscreen_happened.txt" ]; then
		touch /data/oplus/log/bsp/blackscreen_happened.txt
		echo 0 > /data/oplus/log/bsp/blackscreen_happened.txt
	fi
	chmod 0664 /data/oplus/log/bsp/blackscreen_happened.txt

	if [ ! -f "/data/oplus/log/bsp/brightscreen_count.txt" ]; then
		touch /data/oplus/log/bsp/brightscreen_count.txt
		echo 0 > /data/oplus/log/bsp/brightscreen_count.txt
	fi
	chmod 0664 /data/oplus/log/bsp/brightscreen_count.txt

	if [ ! -f "/data/oplus/log/bsp/brightscreen_happened.txt" ]; then
		touch /data/oplus/log/bsp/brightscreen_happened.txt
		echo 0 > /data/oplus/log/bsp/brightscreen_happened.txt
	fi
	chmod 0664 /data/oplus/log/bsp/brightscreen_happened.txt
}
#================================== STABILITY =========================

#Fei.Mo@PSW.BSP.Sensor, 2017/09/05 ,Add for power monitor top info
function thermalTop(){
   top -m 3 -n 1 > /data/system/dropbox/thermalmonitor/top
   chown system:system /data/system/dropbox/thermalmonitor/top
}
#end, Add for power monitor top info

function mvrecoverylog() {
    traceTransferState "mvrecoverylog begin"
    rm -rf ${SDCARD_LOG_BASE_PATH}/recovery_log/
    mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log
    state=`getprop ro.build.ab_update`
    if [ "${state}" = "true" ] ;then
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/recovery
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/factory
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/update_engine_log
        setprop sys.oplus.copyrecoverylog 1
    else
        mv /cache/recovery/* ${SDCARD_LOG_BASE_PATH}/recovery_log
    fi
    echo "mvrecoverylog end"
}

function logcusmain() {
    echo "logcusmain begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    rm -rf ${DATA_DEBUGGING_PATH}/customer
    mkdir -p ${path}
    logdsize=`getprop persist.logd.size`
    if [ "${logdsize}" = "" ]; then
        /system/bin/logcat -G 16M
    fi
    /system/bin/logcat  -f ${path}/android.txt -r10240 -n 2 -v threadtime *:V
    echo "logcusmain end"
}

function logcusevent() {
    echo "logcusevent begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b events -f ${path}/event.txt -r10240 -n 2 -v threadtime *:V
    echo "logcusevent end"
}

function logcusradio() {
    echo "logcusradio begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b radio -f ${path}/radio.txt -r10240 -n 2 -v threadtime *:V
    echo "logcusradio end"
}

function logcuskernel() {
    echo "logcuskernel begin"
    path=${DATA_DEBUGGING_PATH}/customer/kernel
    mkdir -p ${path}
    dmesg > ${DATA_DEBUGGING_PATH}/customer/kernel/dmesg.txt
    /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${path}/kinfo0.txt | awk 'NR%400==0'
    echo "logcuskernel end"
}

function logcustcpdump() {
    echo "logcustcpdump begin"
    path=${DATA_DEBUGGING_PATH}/tcpdump
    if [ -d  ${path} ]; then
        rm -rf ${path}
    fi
    mkdir -p ${path}
    chmod 777 ${path} -R
    tcpdump -i any -p -s 0 -W 2 -C 50 -w ${path}/tcpdump.pcap
    echo "logcustcpdump end"
}

function logcuschmod() {
    path=${DATA_DEBUGGING_PATH}/tcpdump
    chown system:system ${path} -R
    chmod 777 ${path} -R
}

function logcusqmistart() {
    echo "logcusqmistart begin"
    echo 0x2 > /sys/module/ipc_router_core/parameters/debug_mask
    #add for SM8150 platform
    if [ -d "/d/ipc_logging" ]; then
        path=${DATA_DEBUGGING_PATH}/customer/ipc_log
        mkdir -p ${path}
        cat /d/ipc_logging/adsp/log > ${path}/adsp_glink.txt
        cat /d/ipc_logging/modem/log > ${path}/modem_glink.txt
        cat /d/ipc_logging/cdsp/log > ${path}/cdsp_glink.txt
        cat /d/ipc_logging/qrtr_0/log > ${path}/modem_qrtr.txt
        cat /d/ipc_logging/qrtr_5/log > ${path}/sensor_qrtr.txt
        cat /d/ipc_logging/qrtr_10/log > ${path}/NPU_qrtr.txt
        /vendor/bin/qrtr-lookup > ${path}/qrtr-lookup_start.txt
    fi
    echo "logcusqmistart end"
}
function logcusqmistop() {
    echo "logcusqmistop begin"
    echo 0x0 > /sys/module/ipc_router_core/parameters/debug_mask
    path=${DATA_DEBUGGING_PATH}/customer/ipc_log
    mkdir -p ${path}
    /vendor/bin/qrtr-lookup > ${path}/qrtr-lookup_stop.txt
    echo "logcusqmistop end"
}

#ifdef OPLUS_FEATURE_WIFI_LOG
#YangQing@OPLUS_FEATURE_WIFI_LOG, 2022/05/13 , add for collect wifi log
function captureTcpdumpLog(){
    COLLECT_LOG_PATH="${DATA_DEBUGGING_PATH}/wifi_log_temp/"
    if [ -d  ${COLLECT_LOG_PATH} ];then
        rm -rf ${COLLECT_LOG_PATH}
    fi
    if [ ! -d  ${COLLECT_LOG_PATH} ];then
        mkdir -p ${COLLECT_LOG_PATH}
        chown system:system ${COLLECT_LOG_PATH}
        chmod -R 777 ${COLLECT_LOG_PATH}
    fi
    tcpdump -i any -p -s 0 -W 4 -C 5 -w ${COLLECT_LOG_PATH}/tcpdump -Z system
}

#endif /* OPLUS_FEATURE_WIFI_LOG */

#Guotian.Wu add for wifi p2p connect fail log
function collectWifiP2pLog() {
    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        sleep 2
        boot_completed=`getprop sys.boot_completed`
    done
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    if [ ! -d  ${wifiP2pLogPath} ];then
        mkdir -p ${wifiP2pLogPath}
    fi

    # collect driver and firmware log
    cnss_pid=`getprop vendor.oplus.wifi.cnss_diag_pid`
    if [[ "w${cnss_pid}" != "w" ]];then
        kill -s SIGUSR1 $cnss_pid
        sleep 2
        mv /data/vendor/wifi/buffered_wlan_logs/* $wifiP2pLogPath
        chmod 666 ${wifiP2pLogPath}/buffered*
    fi

    dmesg > ${wifiP2pLogPath}/dmesg.txt
    /system/bin/logcat -b main -b system -f ${wifiP2pLogPath}/android.txt -r10240 -v threadtime *:V
}

function packWifiP2pFailLog() {
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    DCS_WIFI_LOG_PATH=`getprop oppo.wifip2p.connectfail`
    logReason=`getprop oplus.wifi.p2p.log.reason`
    logFid=`getprop oplus.wifi.p2p.log.fid`
    version=`getprop ro.build.version.ota`

    if [ "w${logReason}" == "w" ];then
        return
    fi

    if [ ! -d ${DCS_WIFI_LOG_PATH} ];then
        mkdir -p ${DCS_WIFI_LOG_PATH}
        chown system:system ${DCS_WIFI_LOG_PATH}
        chmod -R 777 ${DCS_WIFI_LOG_PATH}
    fi

    if [ ! -d  ${wifiP2pLogPath} ];then
        return
    fi

    tar -czvf  ${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz -C ${wifiP2pLogPath} ${wifiP2pLogPath}
    abs_file=${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz

    fileName="wifip2p_connect_fail@${logFid}@${version}@${logReason}.tar.gz"
    mv ${abs_file} ${DCS_WIFI_LOG_PATH}/${fileName}
    chown system:system ${DCS_WIFI_LOG_PATH}/${fileName}
    setprop sys.oplus.wifi.p2p.log.stop 0
    rm -rf ${wifiP2pLogPath}
}

#Xiao.Liang@PSW.CN.WiFi.Basic.Log.1072015, 2018/10/22, Add for collecting wifi driver log
function setiwprivpkt0() {
    iwpriv wlan0 pktlog 0
}

function setiwprivpkt1() {
    iwpriv wlan0 pktlog 1
}

function setiwprivpkt4() {
    iwpriv wlan0 pktlog 4
}

#Zaogen.Hong@PSW.CN.WiFi.Connect,2020/03/03, Add for trigger wifi dump by engineerMode
function wifi_minidump() {
    iwpriv wlan0 setUnitTestCmd 19 1 4
}

#Xiao.Liang@PSW.CN.WiFi.Basic.SoftAP.1610391, 2018/10/30, Modify for reading client devices name from /data/misc/dhcp/dnsmasq.leases
function changedhcpfolderpermissions(){
    state=`getprop oppo.wifi.softap.readleases`
    if [ "${state}" = "true" ] ;then
        chmod -R 0775 /data/misc/dhcp/
    else
        chmod -R 0770 /data/misc/dhcp/
    fi
}


#ifdef OPLUS_FEATURE_RECOVERY_BOOT
#Shuangquan.du@ANDROID.UPDATABILITY, 2019/07/03, add for generate runtime prop
function generate_runtime_prop() {
    getprop | sed -r 's|\[||g;s|\]||g;s|: |=|' | sed 's|ro.cold_boot_done=true||g' > /cache/runtime.prop
    chown root:root /cache/runtime.prop
    chmod 600 /cache/runtime.prop
    sync
}
#endif /* OPLUS_FEATURE_RECOVERY_BOOT */

#Qilong.Ao@ANDROID.BIOMETRICS, 2020/10/16, Add for adb sync
function oplussync() {
    sync
}
#endif

#add for oidt begin
#PanZhuan@BSP.Tools, 2020/10/21, modify for way of OIDT log collection changed, please contact me for new reqirement in the future
function oidtlogs() {
    # get this prop to remove specified path
    removed_path=`getprop sys.oidt.remove_path`
    if [ "$removed_path" ];then
        traceTransferState "remove path ${removed_path}"
        rm -rf ${removed_path}
        setprop sys.oidt.remove_path ''
        return
    fi

    traceTransferState "oidtlogs start... "
    setprop sys.oidt.log_ready 0

    log_path=`getprop sys.oidt.log_path`
    if [ "$log_path" ];then
        oidt_root=${log_path}
    else
        oidt_root="BASE_PATH/oidt/"
    fi

    mkdir -p ${oidt_root}
    traceTransferState "oidt root: ${oidt_root}"

    log_config_file=`getprop sys.oidt.log_config`
    traceTransferState "log config file: ${log_config_file} "

    if [ "$log_config_file" ];then
        paths=`cat ${log_config_file}`

        for file_path in ${paths};do
            # create parent directory of each path
            dest_path=${oidt_root}${file_path%/*}
            # replace dunplicate character '//' with '/' in directory
            dest_path=${dest_path//\/\//\/}
            mkdir -p ${dest_path}
            traceTransferState "copy ${file_path} "
            cp -rf ${file_path} ${dest_path}
        done

        chmod -R 777 ${oidt_root}

        setprop sys.oidt.log_config ''
    fi

    setprop sys.oidt.log_ready 1
    setprop sys.oidt.log_path ''
    traceTransferState "oidtlogs end "
}
#add for oidt end

#ifdef OPLUS_FEATURE_MEMLEAK_DETECT
#Hailong.Liu@ANDROID.MM, 2020/03/18, add for capture native malloc leak on aging_monkey test
function storeSvelteLog() {
    local dest_dir="/data/oplus/heapdump/svelte/"
    local log_file="${dest_dir}/svelte_log.txt"
    local log_dev="/dev/svelte_log"

    if [ ! -c ${log_dev} ]; then
        /system/bin/logwrapper echo "svelte ${log_dev} does not exist."
        return 1
    fi

    if [ ! -d ${dest_dir} ]; then
        mkdir -p ${dest_dir}
        if [ "$?" -ne "0" ]; then
            /system/bin/logwrapper echo "svelte mkdir failed."
            return 1
        fi
        chmod 0777 ${dest_dir}
    fi

    if [ ! -f ${log_file} ]; then
        echo --------Start `date` >> ${log_file}
        if [ "$?" -ne "0" ]; then
            /system/bin/logwrapper echo "svelte create file failed."
            return 1
        fi
        chmod 0777 ${log_file}
    fi

    /system/bin/logwrapper echo "start store svelte log."
    while true
    do
        echo --------`date` >> ${log_file}
        /system/system_ext/bin/svelte logger >> ${log_file}
    done
}
#endif /* OPLUS_FEATURE_MEMLEAK_DETECT */

function traceTransferState() {
    content=$1

    if [[ -d ${BASE_PATH} ]]; then
        if [[ ! -d ${SDCARD_LOG_BASE_PATH} ]]; then
            mkdir -p ${SDCARD_LOG_BASE_PATH}
            chmod 2770 ${BASE_PATH} -R
            echo "${CURTIME_FORMAT} TRACETRANSFERSTATE:${SDCARD_LOG_BASE_PATH} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        fi

        currentTime=`date "+%Y-%m-%d %H:%M:%S"`
        echo "${currentTime} ${content} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    fi

    LOG_LEVEL=$2
    if [[ "${LOG_LEVEL}" == "" ]]; then
        LOG_LEVEL=d
    fi
    log -p ${LOG_LEVEL} -t Debuglog ${content}
}

function chmodDcsEnPath() {
    DCS_EN_PATH=${DATA_OPLUS_LOG_PATH}/DCS/en
    chmod 777 -R ${DCS_EN_PATH}
}

function transferTest() {
    newpath="${SDCARD_LOG_BASE_PATH}/test@${CURTIME}"
    mkdir -p ${newpath}
    traceTransferState "${newpath}"

}

case "$config" in
    "transfer_log")
        transfer_log
        ;;
    "chmodFromBasePath")
        chmodFromBasePath
        ;;
    "transfer_test")
        transferTest
        ;;
    "psinfo")
        psInfo
        ;;
    "topinfo")
        topInfo
        ;;
    "servicelistinfo")
        serviceListInfo
        ;;
    "dumpsysinfo")
        dumpsysInfo
        ;;
    "dumpstorageinfo")
        dumpStorageInfo
        ;;
    "tranfer_tombstone")
        transferTombstone
        ;;
    "logcache")
        CacheLog
        ;;
    "initopluslog")
        initOplusLog
        ;;
    "copyCamDcsLog")
        copyCamDcsLog
        ;;
    "tranfer_anr")
        transferAnr
        ;;
#Chunbo.Gao@ANDROID.DEBUG.2514795, 2019/11/12, Add for copy binder_info
    "copybinderinfo")
        copybinderinfo
    ;;
#Wuchao.Huang@ROM.Framework.EAP, 2019/11/19, Add for copy binder_info
    "copyEapBinderInfo")
        copyEapBinderInfo
    ;;
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
    "dumpWm")
        dumpWm
    ;;
    "logcatmain")
        logcatMain
        ;;
    "logcatradio")
        logcatRadio
        ;;
    "fingerprintlog")
        fingerprintLog
        ;;
    "fpqess")
        fingerprintQseeLog
        ;;
    "logcatevent")
        logcatEvent
        ;;
    "logcatkernel")
        logcatKernel
        ;;
    #Qi.Zhang@TECH.BSP.Stability 2019/09/20, Add for uefi log
    "logcatuefi")
        LogcatUefi
        ;;
    "tcpdumplog")
        initLogSizeAndNums
        #ifndef OPLUS_FEATURE_TCPDUMP
        #DuYuanhua@NETWORK.DATA.2959182, remove redundant code for rutils-remove action
        #enabletcpdump
        #endif
        tcpDumpLog
        ;;
#ifdef OPLUS_FEATURE_RECOVERY_BOOT
#Shuangquan.du@ANDROID.UPDATABILITY, 2019/07/03, add for generate runtime prop
    "generate_runtime_prop")
        generate_runtime_prop
        ;;
#endif /* OPLUS_FEATURE_RECOVERY_BOOT */
#Qilong.Ao@ANDROID.BIOMETRICS, 2020/10/16, Add for adb sync
    "oplussync")
        oplussync
        ;;
#endif
    "dumpstateinfo")
        dumpStateInfo
        ;;
    "dumpenvironment")
        DumpEnvironment
        ;;
    "initcache")
        initcache
        ;;
    "logcatcache")
        logcatcache
        ;;
    "radiocache")
        radiocache
        ;;
    "eventcache")
        eventcache
        ;;
    "kernelcache")
        kernelcache
        ;;
    "tcpdumpcache")
        tcpdumpcache
        ;;
    "fingerprintcache")
        fingerprintcache
        ;;
    "fplogcache")
        fplogcache
        ;;
    "gettpinfo")
        gettpinfo
    ;;
    "inittpdebug")
        inittpdebug
    ;;
    "settplevel")
        settplevel
    ;;
#Canjie.Zheng@ANDROID.DEBUG,2017/01/21,add for ftm
        "logcatftm")
        logcatftm
    ;;
        "klogdftm")
        klogdftm
    ;;
#Canjie.Zheng@ANDROID.DEBUG,2017/03/09, add for Sensor.logger
    "resetlogpath")
        resetlogpath
    ;;
    "dumpon")
        dumpon
    ;;
    "dumpoff")
        dumpoff
    ;;
    "packupminidump")
        packupminidump
    ;;
    "olcpackupminidump")
        olcpackupminidump
    ;;
#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
        "perf_record")
        perf_record
    ;;
#Fei.Mo@PSW.BSP.Sensor, 2017/09/01 ,Add for power monitor top info
        "thermal_top")
        thermalTop
#end, Add for power monitor top info
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get dmesg at O
        "kernelcacheforopm")
        kernelcacheforopm
    ;;
        "catchClockForOpm")
        catchClockForOpm
    ;;
#Jianfa.Chen@PSW.AD.PowerMonitor,add for powermonitor getting Xlog
        "catchWXlogForOpm")
        catchWXlogForOpm
    ;;
        "catchQQlogForOpm")
        catchQQlogForOpm
    ;;
# Qiurun.Zhou@ANDROID.DEBUG, 2022/6/17, copy wxlog for EAP
        "eapCopyWXlog")
        eapCopyWXlog
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get Sysinfo at O
        "psforopm")
        psforopm
    ;;
        "tranferPowerRelated")
        tranferPowerRelated
    ;;
        "startSsLogPower")
        startSsLogPower
    ;;
        "logcatMainCacheForOpm")
        logcatMainCacheForOpm
    ;;
        "logcatEventCacheForOpm")
        logcatEventCacheForOpm
    ;;
        "logcatRadioCacheForOpm")
        logcatRadioCacheForOpm
    ;;
        "catchBinderInfoForOpm")
        catchBinderInfoForOpm
    ;;
        "catchBattertFccForOpm")
        catchBattertFccForOpm
    ;;
        "catchTopInfoForOpm")
        catchTopInfoForOpm
    ;;
          "dumpsysHansHistoryForOpm")
        dumpsysHansHistoryForOpm
    ;;
        "getPropForOpm")
        getPropForOpm
    ;;
        "dumpsysSurfaceFlingerForOpm")
        dumpsysSurfaceFlingerForOpm
    ;;
        "dumpsysSensorserviceForOpm")
        dumpsysSensorserviceForOpm
    ;;
        "dumpsysBatterystatsForOpm")
        dumpsysBatterystatsForOpm
    ;;
        "dumpsysBatterystatsOplusCheckinForOpm")
        dumpsysBatterystatsOplusCheckinForOpm
    ;;
        "dumpsysBatterystatsCheckinForOpm")
        dumpsysBatterystatsCheckinForOpm
    ;;
        "dumpsysMediaForOpm")
        dumpsysMediaForOpm
    ;;
        "logcusMainForOpm")
        logcusMainForOpm
    ;;
        "logcusEventForOpm")
        logcusEventForOpm
    ;;
        "logcusRadioForOpm")
        logcusRadioForOpm
    ;;
        "logcusKernelForOpm")
        logcusKernelForOpm
    ;;
        "logcusTCPForOpm")
        logcusTCPForOpm
    ;;
        "customDiaglogForOpm")
        customDiaglogForOpm
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2019/08/21, Add for OplusPowerMonitor get qrtr at Qcom
        "qrtrlookupforopm")
        qrtrlookupforopm
    ;;
        "cpufreqforopm")
        cpufreqforopm
    ;;
        "slabinfoforhealth")
        slabinfoforhealth
    ;;
        "svelteforhealth")
        svelteforhealth
    ;;
        "meminfoforhealth")
        meminfoforhealth
    ;;
        "dmaprocsforhealth")
        dmaprocsforhealth
    ;;
#add for customer log
        "delcustomlog")
        delcustomlog
    ;;
        "customdmesg")
        customdmesg
    ;;
        "customdiaglog")
        customdiaglog
    ;;
        "mvrecoverylog")
        mvrecoverylog
    ;;
#ZhuYan@Network.ARCH, 2021/05/18, Add for catche ap log postback
        "logcusmain")
        logcusmain
    ;;
        "logcusevent")
        logcusevent
    ;;
        "logcusradio")
        logcusradio
    ;;
        "logcuskernel")
        logcuskernel
    ;;
        "logcustcpdump")
        logcustcpdump
    ;;
        "logcuschmod")
        logcuschmod
    ;;
#endif
        "transfer_recovery")
        transfer_m_recovery
    ;;
        "logcusqmistart")
        logcusqmistart
    ;;
        "logcusqmistop")
        logcusqmistop
    ;;
#laixin@PSW.CN.WiFi.Basic.Switch.1069763, 2018/09/03, Add for collect wifi switch log
        "collectWifiP2pLog")
        collectWifiP2pLog
    ;;
        "packWifiP2pFailLog")
        packWifiP2pFailLog
    ;;
#Xiao.Liang@PSW.CN.WiFi.Basic.Log.1072015, 2018/10/22, Add for collecting wifi driver log
        "setiwprivpkt0")
        setiwprivpkt0
    ;;
        "setiwprivpkt1")
        setiwprivpkt1
    ;;
        "setiwprivpkt4")
        setiwprivpkt4
    ;;
#Zaogen.Hong@PSW.CN.WiFi.Connect,2020/03/03, Add for trigger wifi dump by engineerMode
        "wifi_minidump")
        wifi_minidump
    ;;

#Xiao.Liang@PSW.CN.WiFi.Basic.SoftAP.1610391, 2018/10/30, Modify for reading client devices name from /data/misc/dhcp/dnsmasq.leases
        "changedhcpfolderpermissions")
        changedhcpfolderpermissions
    ;;
#add for change printk
        "chprintk")
        chprintk
    ;;
#ifdef OPLUS_BUG_STABILITY
#Qing.Wu@ANDROID.STABILITY.2278668, 2019/09/03, Add for capture binder info
    "binderinfocapture")
        binderinfocapture
        ;;
#endif /* OPLUS_BUG_STABILITY */
#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue.
    "receiverinfocapture")
        receiverinfocapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/09/21.add for fix debug system_server register too many receivers issue.
    "binderthreadfullcapture")
        binderthreadfullcapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#//Chunbo.Gao@ANDROID.DEBUG.1968962, 2019/4/23, Add for qmi log
        "qmilogon")
        qmilogon
    ;;
        "qmilogoff")
        qmilogoff
    ;;
        "adspglink")
        adspglink
    ;;
        "modemglink")
        modemglink
    ;;
        "cdspglink")
        cdspglink
    ;;
        "modemqrtr")
        modemqrtr
    ;;
        "sensorqrtr")
        sensorqrtr
    ;;
        "npuqrtr")
        npuqrtr
    ;;
        "slpiqrtr")
        slpiqrtr
    ;;
        "slpiglink")
        slpiglink
    ;;
#ifdef OPLUS_FEATURE_SSLOG_CATCH
#ZhangWankang@NETWORK.POWER 2020/04/02,add for catch ss log
        "logcatSsLog")
        logcatSsLog
    ;;
#endif

#ifdef OPLUS_FEATURE_WIFI_LOG
#YangQing@OPLUS_FEATURE_WIFI_LOG, 2022/05/13 , add for collect wifi log
        "captureTcpdumpLog")
        captureTcpdumpLog
    ;;
#endif /* OPLUS_FEATURE_WIFI_LOG */

    "cameraloginit")
        cameraloginit
    ;;
        "oidtlogs")
        oidtlogs
    ;;
#Yufeng.Liu@Plf.TECH.Performance, 2019/9/3, Add for malloc_debug
        "memdebugregister")
        memdebugregister
    ;;
        "memdebugstart")
        memdebugstart
    ;;
        "memdebugdump")
        memdebugdump
    ;;
        "memdebugremove")
        memdebugremove
    ;;
	"transferUser")
        transferUser
    ;;
	"dump_system")
        getSystemStatus
    ;;
    "transfer_data_vendor")
        transferDataVendor
    ;;
#Fuchun.Liao@BSP.CHG.Basic 2019/06/09 modify for black/bright check
	"create_black_bright_check_file")
        create_black_bright_check_file
    ;;
#ifdef OPLUS_FEATURE_MEMLEAK_DETECT
#Hailong.Liu@ANDROID.MM, 2020/03/18, add for capture native malloc leak on aging_monkey test
    "storeSvelteLog")
        storeSvelteLog
    ;;
#endif /* PLUS_FEATURE_MEMLEAK_DETECT */
    "backup_minidumplog")
        backupMinidump
    ;;
    "chmoddcsenpath")
        chmodDcsEnPath
    ;;
       *)

      ;;
esac

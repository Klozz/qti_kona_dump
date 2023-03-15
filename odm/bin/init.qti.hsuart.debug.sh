#!/vendor/bin/sh
#ifdef OPLUS_FEATURE_BT_EAP_LOG
#Wangguolong@CONNECTIVITY.BT.Basic.Feature.2531788 , 2021/11/10, Add for Open Bluetooth Uart Logs
tracefs=/sys/kernel/tracing
enable_debug()
{
    if [ -d $tracefs ]; then
        mkdir $tracefs/instances/hsuart
        #UART
        echo 100 > $tracefs/instances/hsuart/buffer_size_kb
        echo 1 > $tracefs/instances/hsuart/events/serial/enable
        echo 1 > $tracefs/instances/hsuart/tracing_on
    fi
}

disable_debug()
{
    if [ -d $tracefs/instances/hsuart ]; then
        echo 0 > $tracefs/instances/hsuart/events/serial/enable
        echo 0 > $tracefs/instances/hsuart/tracing_on
    fi
}

if [ "$(getprop persist.vendor.tracing.enabled)" -eq "1" ]; then
    enable_debug
else
    disable_debug
fi

#endif OPLUS_FEATURE_BT_EAP_LOG

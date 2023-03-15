#!/system/bin/sh

platform_id=""
mem_total=""

function configure_kona_parameters() {
    if [ $mem_total -le 8388608 ]; then
        echo 25 > /proc/sys/vm/watermark_scale_factor
    else
        echo 16 > /proc/sys/vm/watermark_scale_factor
    fi
}

function configure_lahaina_parameters() {
    if [ $mem_total -le 8388608 ]; then
        echo 25 > /proc/sys/vm/watermark_scale_factor
    else
        echo 16 > /proc/sys/vm/watermark_scale_factor
    fi
}

function configure_taro_parameters() {
    if [ $mem_total -le 8388608 ]; then
        echo 25 > /proc/sys/vm/watermark_scale_factor
    else
        echo 16 > /proc/sys/vm/watermark_scale_factor
    fi
}

function configure_default_parameters() {
}

function mm_configure() {
    platform_id=`cat /sys/devices/soc0/soc_id`
    mem_total_str=`cat /proc/meminfo | grep MemTotal`
    mem_total=${mem_total_str:16:8}

    if [ -z $mem_total ] || [ -z $platform_id ]
    then
        echo -e "read meminfo failed\n"
        exit -1
    fi

    echo "$platform_id: $mem_total"
    # common configure here
    # disable watermark_boost_factor
    echo 0 > /proc/sys/vm/watermark_boost_factor

    case "$platform_id" in
        "415"|"439"|"456"|"501"|"502"|"475")
            configure_lahaina_parameters
            ;;

        "506")
            #  SM7450
            configure_lahaina_parameters
            ;;

        "457"|"530")
            # SM8450 | SM8475
            configure_taro_parameters
            ;;

        "356")
            # SM8250
            configure_kona_parameters
            ;;
        *)
            echo -e "***WARNING***: Invalid SoC ID\n"
            configure_default_parameters
        ;;
    esac
}

mm_configure

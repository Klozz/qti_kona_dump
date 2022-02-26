#!/vendor/bin/sh
if ! applypatch --check EMMC:/dev/block/bootdevice/by-name/recovery:134217728:ca4a0a0c53632debc0315ccd2f0bbc822e984e0a; then
  applypatch  \
          --patch /vendor/recovery-from-boot.p \
          --source EMMC:/dev/block/bootdevice/by-name/boot:100663296:0fe3ab39a10ee00c9dd7e936a049a314a848504e \
          --target EMMC:/dev/block/bootdevice/by-name/recovery:134217728:ca4a0a0c53632debc0315ccd2f0bbc822e984e0a && \
      log -t recovery "Installing new oppo recovery image: succeeded" && \
      setprop ro.boot.recovery.updated true || \
      log -t recovery "Installing new oppo recovery image: failed" && \
      setprop ro.boot.recovery.updated false
else
  log -t recovery "Recovery image already installed"
  setprop ro.boot.recovery.updated true
fi

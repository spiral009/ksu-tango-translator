#!/system/bin/sh
# Tango Binary Translator - v3.0
# Just works: mounts binfmt_misc, registers tango, loads modules

MODDIR=${0%/*}

# Mount binfmt_misc
if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
    mount -t binfmt_misc none /proc/sys/fs/binfmt_misc 2>/dev/null || true
fi

# Register ARM32 ELF handler
if [ -f /proc/sys/fs/binfmt_misc/register ]; then
    if [ ! -f /proc/sys/fs/binfmt_misc/tango_translator ]; then
        echo ':tango_translator:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfe\xff\xff\xff:/system/bin/tango_translator:POCF' > /proc/sys/fs/binfmt_misc/register 2>/dev/null || true
    fi
    [ -f /proc/sys/fs/binfmt_misc/tango_translator ] && echo 1 > /proc/sys/fs/binfmt_misc/tango_translator 2>/dev/null || true
fi

# Load kernel modules
insmod /vendor_dlkm/tango32.ko 2>/dev/null || modprobe tango32 2>/dev/null || true
insmod /vendor_dlkm/ntsync.ko 2>/dev/null || modprobe ntsync 2>/dev/null || true

# All done - ARM32 binaries now run transparently

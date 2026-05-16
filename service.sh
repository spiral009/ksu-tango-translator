#!/system/bin/sh
# Tango Binary Translator KernelSU Module
# Handles on-demand loading/unloading of tango32 and ntsync

MODDIR=${0%/*}
CONFIG_DIR="/data/adb/tango-modules"
DISABLE_FILE="$CONFIG_DIR/disabled.conf"

# Create config directory
mkdir -p "$CONFIG_DIR"
touch "$DISABLE_FILE"

# Unload disabled modules (they were loaded by modules.load at boot)
unload_disabled() {
    if [ -f "$DISABLE_FILE" ]; then
        while IFS= read -r module || [ -n "$module" ]; do
            [ -z "$module" ] && continue
            module_name="${module%.ko}"
            
            # Check if module is loaded
            if lsmod 2>/dev/null | grep -q "^${module_name} "; then
                rmmod "$module_name" 2>/dev/null && \
                    echo "[tango] Unloaded $module_name (disabled by user)"
            fi
        done < "$DISABLE_FILE"
    fi
}

# Register binfmt_misc for ARM32 ELF (only if tango32 is loaded)
setup_binfmt() {
    if [ -d /proc/sys/fs/binfmt_misc ] && [ -e /dev/tango32 ]; then
        if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
            mount -t binfmt_misc none /proc/sys/fs/binfmt_misc 2>/dev/null
        fi
        
        if [ -f /proc/sys/fs/binfmt_misc/register ] && \
           [ ! -f /proc/sys/fs/binfmt_misc/tango32 ]; then
            echo ':tango32:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfe\xff\xff\xff:/system/bin/tango_translator:' \
                > /proc/sys/fs/binfmt_misc/register 2>/dev/null && \
                echo "[tango] Registered binfmt_misc for ARM32 ELF"
        fi
    fi
}

# Main setup
case "$1" in
    post-fs-data)
        # Unload modules the user has disabled
        unload_disabled
        # Setup binfmt if tango32 is loaded
        setup_binfmt
        ;;
esac

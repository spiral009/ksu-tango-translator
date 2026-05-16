#!/system/bin/sh
# Tango Binary Translator KernelSU Module
# Handles on-demand loading/unloading of tango32 and ntsync
# Manages binfmt_misc registration for ARM32 ELF execution

MODDIR=${0%/*}
CONFIG_DIR="/data/adb/tango-modules"
DISABLE_FILE="$CONFIG_DIR/disabled.conf"

# binfmt_misc entry name and registration string
BINFMT_ENTRY="tango_translator"
BINFMT_REG=":tango_translator:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfe\xff\xff\xff:/system/bin/tango_translator:POCF"

# Create config directory
mkdir -p "$CONFIG_DIR"
[ -f "$DISABLE_FILE" ] || touch "$DISABLE_FILE"

# Mount binfmt_misc if not mounted
mount_binfmt_misc() {
    if [ -d /proc/sys/fs/binfmt_misc ]; then
        if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
            mount -t binfmt_misc none /proc/sys/fs/binfmt_misc 2>/dev/null || true
        fi
    fi
}

# Check if our binfmt entry exists
check_binfmt_registered() {
    [ -f /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY ]
}

# Register binfmt_misc for ARM32 ELF
register_binfmt() {
    mount_binfmt_misc
    
    if [ -f /proc/sys/fs/binfmt_misc/register ]; then
        # Check if already registered with correct interpreter
        if [ -f /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY ]; then
            local current_interp=$(grep "interpreter" /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY 2>/dev/null | awk '{print $2}')
            if [ "$current_interp" != "/system/bin/tango_translator" ]; then
                # Wrong interpreter, remove and re-register
                echo "[tango] Updating binfmt_misc entry to use /system/bin/tango_translator"
                echo -1 > /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY 2>/dev/null || true
                sleep 0.1
                printf '%b' "$BINFMT_REG" > /proc/sys/fs/binfmt_misc/register 2>/dev/null || \
                    echo "$BINFMT_REG" > /proc/sys/fs/binfmt_misc/register 2>/dev/null || true
            fi
        else
            # Not registered, register now
            printf '%b' "$BINFMT_REG" > /proc/sys/fs/binfmt_misc/register 2>/dev/null || \
                echo "$BINFMT_REG" > /proc/sys/fs/binfmt_misc/register 2>/dev/null || true
        fi
        
        # Enable the entry
        if [ -f /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY ]; then
            echo 1 > /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY 2>/dev/null || true
        fi
    fi
}

# Unregister binfmt_misc
unregister_binfmt() {
    if [ -f /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY ]; then
        # Disable first
        echo 0 > /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY 2>/dev/null || true
        sleep 0.1
        # Then remove
        echo -1 > /proc/sys/fs/binfmt_misc/$BINFMT_ENTRY 2>/dev/null || true
    fi
}

# Check if tango32 is loaded
check_tango32() {
    [ -e /dev/tango32 ] || lsmod 2>/dev/null | grep -q "^tango32 "
}

# Kill processes using a device node
kill_device_users() {
    local dev="$1"
    local pids=$(lsof "$dev" 2>/dev/null | grep -v "^COMMAND" | awk '{print $2}' | sort -u)
    if [ -n "$pids" ]; then
        echo "[tango] Killing processes using $dev: $pids"
        for pid in $pids; do
            if [ "$pid" != "1" ] && [ "$pid" != "$$" ]; then
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
        sleep 1
        for pid in $pids; do
            if [ "$pid" != "1" ] && [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    fi
}

# Unload disabled modules (they were loaded by modules.load at boot)
unload_disabled() {
    if [ -f "$DISABLE_FILE" ]; then
        while IFS= read -r module || [ -n "$module" ]; do
            [ -z "$module" ] && continue
            module_name="${module%.ko}"
            
            if lsmod 2>/dev/null | grep -q "^${module_name} "; then
                # Kill processes and cleanup based on module type
                case "$module_name" in
                    tango32)
                        [ -e /dev/tango32 ] && kill_device_users /dev/tango32
                        unregister_binfmt
                        ;;
                    ntsync)
                        [ -e /dev/ntsync ] && kill_device_users /dev/ntsync
                        ;;
                esac
                
                # Unload module
                rmmod "$module_name" 2>/dev/null || rmmod -f "$module_name" 2>/dev/null || true
                echo "[tango] Unloaded $module_name (disabled by user)"
            fi
        done < "$DISABLE_FILE"
    fi
}

# Main setup
case "$1" in
    post-fs-data)
        # Unload modules the user has disabled at previous boot
        unload_disabled
        
        # Register binfmt if tango32 is loaded and not disabled
        if check_tango32 && ! grep -q "^tango32$" "$DISABLE_FILE" 2>/dev/null; then
            register_binfmt
        fi
        ;;
esac

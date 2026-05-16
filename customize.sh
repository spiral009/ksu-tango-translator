#!/system/bin/sh
# Tango Binary Translator - KernelSU Module Install Script

ui_print "Installing Tango Binary Translator..."
ui_print "Version: v2.1.1"
ui_print ""

# Check architecture
ARCH=$(getprop ro.product.cpu.abi)
if [ "$ARCH" != "arm64-v8a" ]; then
    ui_print "WARNING: This module is designed for ARM64 devices"
    ui_print "Current arch: $ARCH"
fi

# Create persistent config directory
mkdir -p /data/adb/tango-modules
[ -f /data/adb/tango-modules/disabled.conf ] || touch /data/adb/tango-modules/disabled.conf

# Check if kernel modules are available
for mod in tango32 ntsync; do
    if [ -f "/vendor_dlkm/${mod}.ko" ] || [ -f "/vendor/lib/modules/${mod}.ko" ]; then
        ui_print "Found ${mod}.ko"
    else
        ui_print "WARNING: ${mod}.ko not found in vendor partitions"
    fi
done

# Set permissions
chmod 755 $MODDIR/system/bin/tango
chmod 755 $MODDIR/system/bin/module-toggle
chmod 755 $MODDIR/system/bin/tango_translator
chmod 755 $MODDIR/system/bin/tango-pretranslate

ui_print ""
ui_print "Installation complete!"
ui_print ""
ui_print "Both tango32 and ntsync auto-load at boot by default."
ui_print "Use the KernelSU Manager WebUI to toggle them on/off."
ui_print ""
ui_print "CLI Usage:"
ui_print "  tango <arm32-binary> [args...]"
ui_print ""
ui_print "ARM32 binaries can also be run directly when enabled."

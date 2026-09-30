#!/system/bin/sh
# cnmbn - bind-mount China carrier MBN config onto /vendor (Pixel 4 / coral)
# Payload lives in <module>/files/mcfg_sw ; we copy the stock dir aside,
# overlay our files, fix SELinux label, then bind-mount over the real path.

DST="/vendor/rfs/msm/mpss/readonly/vendor/mbn/mcfg_sw"
STAGE="/data/adb/cnmbn_stage"
MODDIR="${0%/*}"

SRC=""
for d in "$MODDIR" "$MODDIR/files" \
         "/data/adb/modules/cnmbn" "/data/adb/modules/cnmbn/files" \
         "/data/adb/modules/meta-overlayfs/mnt/cnmbn" "/data/adb/modules/meta-overlayfs/mnt/cnmbn/files" \
         "/data/adb/modules_update/cnmbn" "/data/adb/modules_update/cnmbn/files" ; do
    if [ -d "$d/mcfg_sw/generic/mi9t" ]; then
        SRC="$d/mcfg_sw"
        break
    fi
done

log -t cnmbn "MODDIR=$MODDIR"
log -t cnmbn "SRC=$SRC"

if [ -z "$SRC" ]; then
    log -t cnmbn "ERROR: payload not found"
    exit 1
fi

if [ ! -d "$DST" ]; then
    log -t cnmbn "ERROR: DST not present"
    exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE" || { log -t cnmbn "ERROR: mkdir stage failed"; exit 1; }

cp -a "$DST/." "$STAGE/" 2>/dev/null
cp -a "$SRC/." "$STAGE/" 2>/dev/null

chcon -R u:object_r:vendor_file:s0 "$STAGE" 2>/dev/null

mount --bind "$STAGE" "$DST"

if mountpoint -q "$DST" 2>/dev/null; then
    log -t cnmbn "bind OK"
else
    log -t cnmbn "bind FAILED"
fi

exit 0

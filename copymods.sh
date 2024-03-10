#!/bin/sh

#TMP=$(pwd)/_tmp
#rm -rf $TMP
#mkdir -p $TMP
TMP="./"

KVER="$(uname -r)"
MOD_DIR=/lib/modules/$KVER/kernel
FIRM_DIR=/lib/firmware

(

    find $MOD_DIR/fs/{ext2,ext4,btrfs,jfs,reiserfs,xfs,nfs,cifs,fat,isofs,nls} -type f -name "*.ko"

    find $MOD_DIR/drivers/{mmc,nvme,scsi,md,hid,pcmcia,firewire,virtio,hv,crypto} -type f -name "*.ko"

    find $MOD_DIR/drivers/block -type f \( -name "loop.ko" -o -name "virtio*.ko" \)

    find $MOD_DIR/drivers/usb/{host,storage} -type f -name "*.ko"

    find $MOD_DIR/drivers/net/{ethernet,fddi,hippi,hyperv,usb,vmxnet3} -type f -name "*.ko"
    find $MOD_DIR/drivers/net -type f -name "virtio*.ko"

    find $MOD_DIR/drivers/char/hw_random -type f -name "*.ko"
    find $MOD_DIR/drivers/char -type f -name "virtio*.ko"

    find $MOD_DIR/drivers/input/{keyboard,mouse,serio} -type f -name "*.ko"
    find $MOD_DIR/drivers/input -type f -name "evdev*.ko"

    find $MOD_DIR/drivers/{gpu,video} -type f -name "*.ko"
    find $MOD_DIR/drivers/staging/vboxvideo -type f -name "*.ko"

    find $MOD_DIR/crypto -type f -name "*.ko"

) | sort -u \
| while read m ; do
    modprobe --show-depends $(basename $m .ko)
done | sort -u \
| cut -f2- -d '/' \
| grep -v builtin \
| while read f ; do
    mkdir -p $TMP/$(dirname /$f)
    cat /$f | xz -c9 > $TMP/$f.xz
    touch -r /$f $TMP/$f.xz
    modinfo $(basename /$f .ko) \
    | grep "^firmware:" \
    | tr -d ' ' | cut -f2 -d ':'
done | sort -u \
| while read f ; do
    if [ -f $FIRM_DIR/$f ] ; then
	d=$(dirname $FIRM_DIR/$f)
	mkdir -p $TMP/$d
	cp -a $FIRM_DIR/$f $TMP/$d
    fi
done
cp -a /lib/modules/$KVER/modules.{builtin,order} $TMP/lib/modules/$KVER
depmod -a -b $TMP

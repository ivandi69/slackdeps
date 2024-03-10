#!/bin/bash

LANG=C
LC_ALL=C

CWD=$(pwd)
TMP=$CWD/_tmp

SLACK_DIR="/home/slackware64-current"

INITRD="$SLACK_DIR/isolinux/initrd.img"
[ -r $INITRD ] || exit 1

rm -rf $TMP/initrd
mkdir -p $TMP/initrd
cd $TMP/initrd || exit 1

xzcat $INITRD | cpio -idm

#exit

# BEGIN
#cp -a $CWD/tags/* ./tag

for f in $CWD/installer/setup/* $CWD/minimal.template ; do
    cp -af $f ./usr/lib/setup
done

for f in $CWD/installer/rc.d/* ; do
    cp -af $f ./etc/rc.d
done

[ -f $CWD/Punattended ] && cat $CWD/Punattended > ./tmp/Punattended

if [ -x $CWD/copymods.sh ] ; then
    rm -rf ./lib/{modules,firmware}
    $CWD/copymods.sh
fi
# END

#exit

find . | cpio -o -H newc | xz --check=crc32 -9c > $SLACK_DIR/isolinux/initrd.img
cd - > /dev/null

KVER=$(uname -r)
cp -af /boot/vmlinuz-generic-$KVER $SLACK_DIR/kernels/huge.s/bzImage
cp -af /boot/config-generic-$KVER.x64 $SLACK_DIR/kernels/huge.s/config
cp -af /boot/System.map-generic-$KVER $SLACK_DIR/kernels/huge.s/System.map
gzip -9f $SLACK_DIR/kernels/huge.s/System.map

ln -f $SLACK_DIR/isolinux/initrd.img $SLACK_DIR/EFI/BOOT
ln -f $SLACK_DIR/kernels/huge.s/bzImage $SLACK_DIR/EFI/BOOT/huge.s

rm -rf $TMP

#!/bin/bash

SLACK_DIR=/home/slackware64-current

_mkiso(){
    xorriso -as mkisofs \
	-iso-level 3 \
        -full-iso9660-filenames \
	-R -J -A "Slackware64 DVD $(date +%F)" \
        -hide-rr-moved \
	-v -d -N \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -eltorito-alt-boot \
        -e isolinux/efiboot.img \
        -no-emul-boot -isohybrid-gpt-basdat \
        -volid "SLACKWARE_64_DVD" \
        ${EXCLUDE} \
        -output $ISO_OUT \
        -graft-points \
	$SLACK_DIR

    md5sum $ISO_OUT > $ISO_OUT.md5
}

ISO_OUT=slackware64-netinstall-dvd.iso
EXCLUDE="-m $SLACK_DIR/patches -m $SLACK_DIR/extra -m $SLACK_DIR/slackware64"
_mkiso

#ISO_OUT=slackware64-install-dvd.iso
#EXCLUDE="-m $SLACK_DIR/patches"
#_mkiso


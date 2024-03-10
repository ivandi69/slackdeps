#!/bin/bash

REPO_ROOT="/home/slackware64-current"
DOWNLOAD_URL="/mnt/cdrom"

mkdir -p $REPO_ROOT

RSYNC="rsync -axv --delete"

EXCLUDE=""
EXCLUDE="$EXCLUDE --exclude PACKAGES.TXT"
EXCLUDE="$EXCLUDE --exclude patches/source/"

for f in GPG-KEY CHECKSUMS.md5 CHECKSUMS.md5.asc FILELIST.TXT ChangeLog.txt ; do
    $RSYNC $DOWNLOAD_URL/$f $REPO_ROOT
done

$RSYNC $EXCLUDE $DOWNLOAD_URL/slackware64 $REPO_ROOT
$RSYNC $EXCLUDE $DOWNLOAD_URL/patches $REPO_ROOT

mkdir -p $REPO_ROOT/extra
for f in CHECKSUMS.md5 CHECKSUMS.md5.asc FILE_LIST MANIFEST.bz2 ; do
    $RSYNC $DOWNLOAD_URL/extra/$f $REPO_ROOT/extra
done
$RSYNC $EXCLUDE $DOWNLOAD_URL/extra/tigervnc $REPO_ROOT/extra
$RSYNC $EXCLUDE $DOWNLOAD_URL/extra/fltk $REPO_ROOT/extra

$RSYNC $EXCLUDE $DOWNLOAD_URL/EFI $REPO_ROOT
$RSYNC $EXCLUDE $DOWNLOAD_URL/isolinux $REPO_ROOT
$RSYNC $EXCLUDE $DOWNLOAD_URL/kernels $REPO_ROOT

#!/bin/bash

CWD=$(pwd)

REPO_ROOT="/home/slackware64-current"
META_DIR="$CWD/meta"
META_MANUAL="$CWD/meta_manual"
SLACKDEPS=$CWD/slackdeps.sh

mkdir -p $META_DIR $META_MANUAL

_PACKAGES(){
    for pkg in $(find ./$PKG_DIR -type f -name "*.txz" | sort -u) ; do
        pdir=$(dirname $pkg)
        pname=$(basename $pkg .txz)
        pbase=$(echo $pname | rev | cut -f4- -d - | rev)

        SIZE=$( expr `xz --robot --list $pkg | tail -1 | awk '{print $4}'` / 1024 )
        USIZE=$( expr `xz --robot --list $pkg | tail -1 | awk '{print $5}'` / 1024 )

        if [ -n "$META_DIR" ] ; then
            PDEPS=$META_DIR/$pbase
            PMDEPS=$META_MANUAL/$pbase-required
            PODEPS=$META_MANUAL/$pbase-required-overwrite
            PSUGG=$META_MANUAL/$pbase-suggests
            PCONF=$META_MANUAL/$pbase-conflicts
            PDESC=$pdir/$pname.txt
        else
            PDEPS=$pdir/slack-required
            PMDEPS=$pdir/slack-required-manual
            PODEPS=$pdir/slack-required-overwrite
            PSUGG=$pdir/slack-suggests
            PCONF=$pdir/slack-conflicts
            PDESC=$pdir/slack-desc
        fi

	cat << EOF >&2
Processing $pname
EOF

        echo "PACKAGE NAME:  $(basename $pkg)"
        echo "PACKAGE LOCATION:  $pdir"
        echo "PACKAGE SIZE (compressed):  $SIZE K"
        echo "PACKAGE SIZE (uncompressed):  $USIZE K"

        if [ -x $SLACKDEPS ]; then
            PD=""
            PS=""
            PC=""
            if [ $pkg -nt $PDEPS ] ; then
        	if [ -r $PODEPS ] ; then
        	    cat $PODEPS > $PDEPS
        	else
            	    $SLACKDEPS $pname > $PDEPS
            	fi
            	if [ -r $PMDEPS ] ; then
                    cat $PDEPS $PMDEPS | sort -u | grep -v "^$" > $PDEPS.$$
                    mv $PDEPS.$$ $PDEPS
                fi
                touch -r $pkg $PDEPS
            fi
            if [ -r $PDEPS ] ; then
                for i in $(<$PDEPS) ; do
                    grep -qw $i $PSUGG 2>/dev/null && continue
                    grep -qw $i $PCONF 2>/dev/null && continue
                    PD="$PD,$i"
                done
                PD=$(echo "$PD" | cut -b2-)
            fi
            if [ -r $PSUGG ] ; then
                for i in $(<$PSUGG) ; do
                    PS="$PS,$i"
                done
                PS=$(echo "$PS" | cut -b2-)
            fi
            if [ -r $PCONF ] ; then
                for i in $(<$PCONF) ; do
                    PC="$PC,$i"
                done
                PC=$(echo "$PC" | cut -b2-)
            fi
            echo "PACKAGE REQUIRED:  $PD"
            echo "PACKAGE CONFLICTS:  $PC"
            echo "PACKAGE SUGGESTS:  $PS"
        fi

        echo "PACKAGE DESCRIPTION:"
        if [ -r $PDESC ] ; then
            cat $PDESC | grep "^$pbase:"
        else
            tar --to-stdout -xf $pkg install/slack-desc | grep "^$pbase:"
        fi
        echo ""
    done
}

trap exit 1 2 3 9 15

cd $REPO_ROOT || exit 1

PKG_DIR=slackware64
_PACKAGES > ./$PKG_DIR/PACKAGES.TXT
cp -a ./$PKG_DIR/PACKAGES.TXT .
#( cd ./$PKG_DIR ; find . -type f -name "*.txz" | sort -u | xargs -r md5sum ) > ./$PKG_DIR/CHECKSUMS.md5

PKG_DIR=patches
_PACKAGES > ./$PKG_DIR/PACKAGES.TXT
#( cd ./$PKG_DIR ; find . -type f -name "*.txz" | sort -u | xargs -r md5sum ) > ./$PKG_DIR/CHECKSUMS.md5

PKG_DIR=extra
_PACKAGES > ./$PKG_DIR/PACKAGES.TXT
#( cd ./$PKG_DIR ; find . -type f -name "*.txz" | sort -u | xargs -r md5sum ) > ./$PKG_DIR/CHECKSUMS.md5

#find . -type f -name "*.txz" | sort -u | xargs md5sum > CHECKSUMS.md5

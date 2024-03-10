#!/bin/bash

LANG=C
LC_ALL=C

CWD=$(pwd)

TMP=/tmp/$(basename $0).$$
LIBS=$TMP/LIBS
FILES=$TMP/FILES
DEPS=$TMP/DEPS

ADM=/var/lib/pkgtools
[ -d $ADM ] || ADM=/var/log
[ -d $ADM ] || exit 1

DEPENDENCIES=$CWD/pkg_dependencies
MISSING=$CWD/pkg_missing

PKG=""

_clean(){
    rm -rf $TMP
}

_die(){
    _clean
    exit $1
}

_list_files_pkg(){
    local f nf

    cat $ADM/packages/$(basename $PKG) | \
        sed -n "/^\.\//,/^$/p" | \
        grep "^bin/\|^sbin/\|^lib/\|^lib64/\|^usr/bin/\|^usr/sbin\|^usr/lib/\|^usr/lib64\|^usr/libexec/" | \
        grep -v "/$" | \
        sed 's/^bin\/bash4/bin\/bash/g' | \
        awk '{print "/"$1}' \
            > $FILES-$$

    for f in $(<$FILES-$$) ; do
        if [ -f $f ] ; then
            echo $f
        else
            nf=${f%.new}
            [ -f $nf ] && echo $nf
        fi
    done \
        > $FILES
}

_list_files(){
    _list_files_pkg
}

_list_libs_ldd(){
    local exe

    for exe in $(<$FILES) ; do
        ldd $exe 2>/dev/null
    done \
        > $LIBS-$$

    cat $LIBS-$$ | \
        awk '/ => \// {print $3}' | \
        xargs -r readlink -e | \
        cut -b2- | \
        sort -u \
             > $LIBS

    cat $LIBS-$$ | \
        awk '/ => not found/ {print $1}' | \
        sort -u \
             > $LIBS-MISSING
}

_list_libs_readelf(){
    local exe lib l

    for exe in $(<$FILES) ; do
        readelf -d $exe 2>/dev/null
    done \
        > $LIBS-$$

    for lib in $(cat $LIBS-$$ | \
			grep "NEEDED" | grep "Shared library" | \
			cut -f2 -d '[' | cut -f1 -d ']' | \
			sort -u) ; do
        l=$(find \
                /lib{,64} \
                /usr/lib{,64} \
                /usr/lib{,64}/perl?/* \
                /usr/lib{,64}/perl?/*/* \
                /usr/lib{,64}/perl?/*/*/* \
                -maxdepth 1 \
                -name $lib -print -quit \
                2>/dev/null)
        if [ -n "$l" ] ; then
            readlink -e $l | \
                sort -u | \
                cut -b2- \
                    >> $LIBS
        else
            echo $lib \
                 >> $LIBS-MISSING
        fi
    done
}

_list_libs(){
    if [ -n "$(type -p readelf)" ] ; then
        _list_libs_readelf
    elif [ -n "$(type -p ldd)" ] ; then
        _list_libs_ldd
    else
        echo "Can't find both readelf and ldd."
        _die 1
    fi
}

_depends_on(){
    local lib

    for lib in $(<$LIBS) ;  do
        grep -q "/$lib$" $FILES && continue
        (
            cd $ADM/packages
            grep -l $lib * || \
                grep -l "/$(basename $lib)$" *
        ) | \
            rev | cut -f4- -d '-' | rev | \
            grep -v "aaa_elflibs" | \
            grep -v "glibc" | \
            tr \\n \| | rev | cut -b2- | rev
    done | \
        sort -u \
             > $DEPS

    if [ -n "$(<$LIBS-MISSING)" ]; then
        for lib in $(<$LIBS-MISSING) ; do
            grep -q "/$lib" $FILES && continue
            echo $lib
        done | \
            sort -u \
                 > $DEPS-MISSING
    fi
}

_find_deps(){
    PKG=$1

    rm -rf $TMP
    mkdir -p $TMP
    mkdir -p $DEPENDENCIES $MISSING
    rm -f $DEPENDENCIES/${1}*
    rm -f $MISSING/${1}*

    touch $FILES $LIBS $DEPS $LIBS-MISSING $DEPS-MISSING 

    echo -n "Processing $PKG:"
    _list_files
    echo -n "."
    _list_libs
    echo -n "."
    _depends_on
    echo -n "."
    PKG=$(echo $PKG | rev | cut -f4- -d '-' | rev)
    [ -n "$(<$DEPS)" ] && cat $DEPS > $DEPENDENCIES/$PKG
    [ -n "$(<$DEPS-MISSING)" ] && cat $DEPS-MISSING > $MISSING/$PKG
    echo "DONE"
}

trap _die 1 2 3 9 15


if [ -n "$1" ] ; then
    for p in $( ls -1 $ADM/packages/${1}* | xargs -r -n 1 basename ) ; do
        _find_deps $p
    done
else
    PKGS=$( ls -1 $ADM/packages | \
		  grep -v "\-noarch\-" | \
		  grep -v "^glibc\-" | \
		  grep -v "^aaa_elflibs\-" | \
		  grep -v "^kernel\-" )
    if [ -n "$(type -p parallel)" ] ; then
        echo $PKGS | tr \  \\n | parallel --will-cite sh $0
    elif [ -n "$(type -p xargs)" ] ; then
        echo $PKGS | tr \  \\n | xargs -r -n 1 -P $(nproc) sh $0
    else
        for p in $PKGS ; do
            sh $0 $p
        done
    fi
fi

_clean

#!/bin/bash

CWD=$(pwd)

DEPENDENCIES=DEPENDENCIES

_filter(){
    grep -v "\-solibs$"
}

if [ -d $CWD/meta ] ; then
    DEPSDIR=$CWD/meta
elif [ -d $CWD/pkg_dependencies ] ; then
    DEPSDIR=$CWD/pkg_dependencies
else
    exit 1
fi

(
    for f in *.meta ; do
	cat $f
	echo
    done

    ls -1 $DEPSDIR \
	| while read pkg ; do
	cat $DEPSDIR/$pkg | tr \| \\n \
	    | _filter \
	    | while read dep ; do
	    echo "$pkg:$dep"
	done
	echo
    done
) | cat -s > $DEPENDENCIES

#!/bin/bash
#
# slackdeps - a script that finds Slackware package dependencies.
#
# Written by ivandi
# The _parse_python function is copied from depfinder (parsepython)
# depfinder is written by George Vlahavas from SalixOS
#
# Licensed under the GPL v3

LANG=C
LC_ALL=C

CWD=$(pwd)

TMP=/tmp/$(basename $0).$$
LIBS=$TMP/LIBS
FILES=$TMP/FILES
PYMODS=$TMP/PYMODS
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
    exit
}

_list_files_pkg(){
    local f nf
    
    for f in $(cat $ADM/packages/$(basename $PKG) | \
                      sed -n "/^\.\//,/^$/p" | \
                      grep -v "/$" | \
                      sed 's/^bin\/bash4/bin\/bash/g' | \
                      awk '{print "/"$1}' \
              ) ; do
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

_list_elf_files(){
    local f

    for f in $(cat $FILES | \
                      grep "^/bin/\|^/sbin/\|^/lib64/\|^/lib/\|^/usr/bin/\|^/usr/sbin/\|^/usr/lib64/\|^/usr/lib/\|^/usr/libexec/" \
              ) ; do
        file $f | grep -qi ".*ELF.*LSB.*dynamically linked" && echo $f
    done \
        > $FILES-ELFFILES
}

_list_libs_ldd(){
    local exe

    for exe in $(<$FILES-ELFFILES) ; do
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

    for exe in $(<$FILES-ELFFILES) ; do
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
    if [ -x /usr/bin/readelf ]; then
        _list_libs_readelf
    elif [ -x /usr/bin/ldd ]; then
        _list_libs_ldd
    fi
}

_depends_on_libs(){
    local lib
    
    if [ -n "$(<$LIBS)" ]; then
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
                 > $DEPS-LIBS
    fi

    if [ -n "$(<$LIBS-MISSING)" ]; then
        for lib in $(<$LIBS-MISSING) ; do
            grep -q "/$lib" $FILES && continue
            echo $lib
        done | \
            sort -u | \
            awk '{print "solib:" $1}' \
                > $DEPS-LIBS-MISSING
    fi
}

_parse_python(){
    # Copied from George Vlahavas's depfinder
    sed "s/;/\n/g" | \
        sed -e :a -e '/\\$/N; s/\\\n//; ta' | \
        sed "s/[ \t]\+/ /g" | \
        grep "^ *import \|^ *from .* import " | \
        sed "s/#/@COMMENT@/" | \
        sed "s/\(.*\)@COMMENT@.*/\1/" | \
        sed "s/.*__import__('\(.*\)').*/import \1/" | \
        sed "s/from \(.*\) import .*/\1/" | \
        sed "s/^ *import \(.*\)/\1/" | \
        sed "s/\(.*\) as .*/\1/"  | \
        sed "s/^[ \t]*//;s/[ \t]*$//" | \
        sed "/ [^,]\+ /d" | \
        sed "s/,/\n/g" | \
        sed "s/^[ \t]*//" | \
        sed "s/\./@MODULESEPARATOR@/" | \
        sed "s/\(.*\)@MODULESEPARATOR@.*/\1/" 
}

_list_python_files(){
    local f

    grep "\.py$" $FILES > $FILES-PYTHONFILES
    for f in $(cat $FILES | \
                      grep -v "\.py$" | \
                      grep -v "/__pycache__/" | \
                      grep -v "\.pyc$\|\.pyo$\|\.so$" | \
                      grep "^/usr/lib64/python\|^/usr/lib/python\|^/usr/bin/\|^/usr/sbin/\|^/usr/libexec/\|^/usr/share/" \
              ) ; do
        file $f | grep -qi "python" && echo $f
    done \
        >> $FILES-PYTHONFILES
}

_list_python_mods(){
    local f

    if [ -n "$(<$FILES-PYTHONFILES)" ]; then

        for f in $(<$FILES-PYTHONFILES) ; do
            cat $f | _parse_python
        done | \
            sort -u | \
            grep -v "^$" \
                 > $PYMODS
    fi
}

_depends_on_python(){
    local f d fnd PYTHON PYTHONS

    [ -x /usr/bin/python ] && PYTHONS="python"
    [ -x /usr/bin/python3 ] && PYTHONS="$PYTHONS python3"

    if [ -n "$(<$PYMODS)" ]; then
        for PYTHON in $PYTHONS ; do
            $PYTHON -c "import sys; print(sys.builtin_module_names)"
        done | \
            sed "s/'\|,\|(\|)//g" | \
            sed "s/ /\n/g" | \
            grep -v "^$" | \
            sort -u \
                 > $PYMODS-BUILTIN

        for PYTHON in $PYTHONS ; do
            for d in $($PYTHON -c "import sys; print(sys.path)" | \
                              sed "s/'\|,\|\[\|\]//g" | \
                              sed "s/ /\n/g" | \
                              grep -v "^$"\
                      ) ; do
                [ -d $d ] || continue
                echo $d
            done
        done | \
            sort -u \
                 > $PYMODS-PYTHONDIRS

        for f in $(<$PYMODS) ; do
            grep -qw $f $PYMODS-BUILTIN && continue
            grep -q "/$f\.py$\|/$f/__init__\.py$\|/$f\.so$" $FILES && continue
            fnd=0
            for d in $(<$PYMODS-PYTHONDIRS) ; do
                if [ -f $d/$f.py ]; then
                    echo "$d/$f.py"
                    fnd=1
                    break
                fi
                if [ -f $d/$f/__init__.py ]; then
                    echo "$d/$f/__init__.py"
                    fnd=1
                    break
                fi
                if [ -f $d/$f.so ]; then
                    echo "$d/$f.so"
                    fnd=1
                    break
                fi
            done
            [ $fnd -eq 0 ] && echo $f >> $PYMODS-MISSING
        done | \
            sort -u | \
            cut -b2- \
                > $PYMODS-FOUND

        if [ -n "$(<$PYMODS-FOUND)" ]; then
            for f in $(<$PYMODS-FOUND) ; do
                (
                    cd $ADM/packages
                    grep -l $f * || \
                        grep -l "/$(basename $f)$" *
                ) | \
                    rev | cut -f4- -d '-' | rev | \
                    tr \\n \| | rev | cut -b2- | rev
            done | \
                sort -u \
                     > $DEPS-PYMODS
        fi

        if  [ -n "$(<$PYMODS-MISSING)" ]; then
            cat $PYMODS-MISSING | \
                sort -u | \
                awk '{print "pymod:" $1}' \
                    > $DEPS-PYMODS-MISSING
        fi

    fi
}       

_find_deps(){
    PKG=$1

    rm -rf $TMP
    mkdir -p $TMP
    mkdir -p $DEPENDENCIES $MISSING
    rm -f $DEPENDENCIES/${1}*
    rm -f $MISSING/${1}*

    touch \
        $FILES $FILES-ELFFILES $FILES-PYTHONFILES \
        $LIBS $LIBS-MISSING \
        $PYMODS $PYMODS-FOUND $PYMODS-MISSING \
        $DEPS-LIBS $DEPS-LIBS-MISSING $DEPS-PYMODS $DEPS-PYMODS-MISSING \
        $DEPS $DEPS-MISSING

    echo -n "Processing $PKG:"

    _list_files
    echo -n "."

    if [ -x /usr/bin/ldd -o -x /usr/bin/readelf ]; then
        (
            _list_elf_files
            echo -n "."
            _list_libs
            echo -n "."
            _depends_on_libs
            echo -n "."
        )&
    fi

    if [ -x /usr/bin/python ]; then
        (
            _list_python_files
            echo -n "."
            _list_python_mods
            echo -n "."
            _depends_on_python
            echo -n "."
        )&
    fi
    
    wait

    cat $DEPS-LIBS $DEPS-PYMODS > $DEPS
    cat $DEPS-LIBS-MISSING $DEPS-PYMODS-MISSING > $DEPS-MISSING
    
    [ -n "$(<$DEPS)" ] && cat $DEPS | sort -u > $DEPENDENCIES/$PKG
    [ -n "$(<$DEPS-MISSING)" ] && cat $DEPS-MISSING | sort -u > $MISSING/$PKG
    
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

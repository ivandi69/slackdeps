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

TMP=/tmp/$(basename $0).$$
LIBS=$TMP/LIBS
FILES=$TMP/FILES
PYMODS=$TMP/PYMODS
DEPS=$TMP/DEPS

ADM=/var/lib/pkgtools
[ -d $ADM ] || ADM=/var/log
[ -d $ADM ] || exit 1

PKG=""
PKG_DIR=""

_clean(){
    rm -rf $TMP
}

_die(){
    _clean
    exit
}

_pbase(){
    rev | cut -f4- -d '-' | rev
}

_parch(){
    rev | cut -f2 -d '-' | rev
}

_system_path_only(){
    grep "^/bin/\|^/sbin/\|^/lib64/\|^/lib/\|^/usr/bin/\|^/usr/sbin/\|^/usr/lib64/\|^/usr/lib/\|^/usr/libexec/"
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

_list_files_dir(){
    ( cd $PKG_DIR ; find . -type f ) | \
	cut -b2- | sort -u \
			> $FILES
}

_list_files(){
    if [ -n "$PKG_DIR" ] ; then
        _list_files_dir
    else
        _list_files_pkg
    fi
}

_list_elf_files(){
    local f

    for f in $(cat $FILES | _system_path_only) ; do
        file $PKG_DIR/$f | grep -qi ".*ELF.*LSB.*dynamically linked" && echo $f
    done \
        > $FILES-ELFFILES
}

_list_libs_ldd(){
    local exe

    for exe in $(<$FILES-ELFFILES) ; do
        ldd $PKG_DIR/$exe 2>/dev/null
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
        readelf -d $PKG_DIR/$exe 2>/dev/null
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
                _pbase | \
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
        file $PKG_DIR/$f | grep -qi "python" && echo $f
    done \
        >> $FILES-PYTHONFILES
}

_list_python_mods(){
    local f

    if [ -n "$(<$FILES-PYTHONFILES)" ]; then

        for f in $(<$FILES-PYTHONFILES) ; do
            cat $PKG_DIR/$f | _parse_python
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
                    _pbase | \
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

_depends_on_perl(){
    local f

    for f in $(cat $FILES | _system_path_only) ; do
        if [ -n "$(file $PKG_DIR/$f | grep -i "Perl.*script.*executable")" ] ; then
            echo "perl"
            break;
        fi
    done \
        > $DEPS-PERL
}

_depends_on_ruby(){
    local f

    for f in $(cat $FILES | _system_path_only) ; do
        if [ -n "$(file $PKG_DIR/$f | grep -i "Ruby.*script.*executable")" ] ; then
            echo "ruby"
            break;
        fi
    done \
        > $DEPS-RUBY
}

_depends_on_tcl(){
    local f

    for f in $(cat $FILES | _system_path_only) ; do
        if [ -n "$(file $PKG_DIR/$f | grep -i "tclsh.*script.*executable")" ] ; then
            echo "tcl"
            break;
        fi
    done \
        > $DEPS-TCL
}

_find_deps(){
    touch \
        $FILES $FILES-ELFFILES $FILES-PYTHONFILES \
        $LIBS $LIBS-MISSING \
        $PYMODS $PYMODS-FOUND $PYMODS-MISSING \
        $DEPS-LIBS $DEPS-LIBS-MISSING $DEPS-PYMODS $DEPS-PYMODS-MISSING $DEPS-PERL $DEPS-RUBY $DEPS-TCL \
        $DEPS $DEPS-MISSING

    _list_files

    if [ -x /usr/bin/ldd -o -x /usr/bin/readelf ]; then
        (
            _list_elf_files
            _list_libs
            _depends_on_libs
        )&
    fi

    if [ -x /usr/bin/python ]; then
        (
            _list_python_files
            _list_python_mods
            _depends_on_python
        )&
    fi

    (
        _depends_on_perl
        _depends_on_ruby
        _depends_on_tcl
    )&

    wait

    cat $DEPS-LIBS $DEPS-PYMODS $DEPS-PERL $DEPS-RUBY $DEPS-TCL > $DEPS
    cat $DEPS-LIBS-MISSING $DEPS-PYMODS-MISSING > $DEPS-MISSING
    if [ -n "$(<$DEPS)" ] ; then
        if [ -n "$PKG" ] ; then
            cat $DEPS | grep -v "^$(echo $PKG | _pbase)$" | sort -u
        else
            cat $DEPS | sort -u
        fi
    fi
    if [ -n "$(<$DEPS-LIBS-MISSING)" ] ; then
        cat << EOF >&2
!!! WARNING WARNING WARNING !!!
$PKG missing libraries:
EOF
        cat $DEPS-LIBS-MISSING >&2
    fi
}

trap _die 1 2 3 9 15

[ -z "$1" ] && _die

if [ -d "$1" ] ; then
    PKG_DIR="$1"
else
    PKG=$(basename $1)
    PACKAGE_BASE=$(echo $PKG | _pbase)
    PACKAGE_ARCH=$(echo $PKG | _parch)

    [ -r $ADM/packages/$PKG ] || _die

    #[ "$PACKAGE_ARCH" == "noarch" ] && _die

    echo $PACKAGE_BASE | grep -q "^aaa_" && _die
    echo $PACKAGE_BASE | grep -q "^glibc" && _die
    echo $PACKAGE_BASE | grep -q "^kernel" && _die
fi

mkdir -p $TMP

_find_deps

_clean

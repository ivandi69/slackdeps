#!/bin/bash

DEPSFILE="DEPENDENCIES"
BLACKLIST="BLACKLIST"

[ -r $DEPSFILE ] || exit 1

get_deps(){
    local deps pkg
    deps=$(grep "^$1:" $DEPSFILE | cut -f2 -d ":")
    [ -z "$deps" ] && return
    for pkg in $deps ; do
        grep -q "^$pkg$" $BLACKLIST 2>/dev/null && continue
        echo "$DEPS" | grep -q "<$pkg>" && continue
        DEPS="$DEPS<$pkg>"
        get_deps $pkg
        DEPS="$(echo "$DEPS" | sed "s/<$pkg>//")<$pkg>"
    done
}

DEPS=""
for package in "$@" ; do
    get_deps $package
    DEPS="$DEPS<$package>"
done

for package in $(echo "$DEPS" | tr '<' ' ' | tr '>' ' ' | tr -s [:blank:]) ; do
    echo $package
done

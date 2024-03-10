#!/bin/bash

CWD=$(pwd)

TAGS_DIR="/home/slackware64-current/slackware64"

for template in *.template ; do
    TAG_DIR=./tags/$(basename $template .template)
    rm -rf $TAG_DIR
    for d in a ap d e f k kde kdei l n t tcl x xap xfce y ; do
	mkdir -p $TAG_DIR/$d
	cat $TAGS_DIR/$d/tagfile  | cut -f1 -d ':' \
	    | while read pkg ; do
		if grep -q "^$pkg$" $template ; then
		    echo "$pkg:ADD"
		else
		    echo "$pkg:SKP"
		fi
	    done > $TAG_DIR/$d/tagfile
    done
done

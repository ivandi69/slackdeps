#!/bin/bash

SLACK_DIR=/home/slackware64-current/slackware64
BLACKLIST=BLACKLIST

for d in d e f k kde kdei t tcl x xap xfce y ; do
    echo "# $d"
    cat $SLACK_DIR/$d/tagfile | cut -f1 -d ':' | sort -u
    echo
done \
| grep -v "^flex$" \
| grep -v "^guile$" \
| grep -v "^libtool$" \
> $BLACKLIST

echo "# l" >> $BLACKLIST
(
    echo harfbuzz
    echo freetype
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^gtk"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^qt"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^py"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "python"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^cairo"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^gdk"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^atk"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^pango"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^phonon"
    cat $SLACK_DIR/l/tagfile | cut -f1 -d ':' | grep -i "^glib$"
) | sort -u >> $BLACKLIST
echo >> $BLACKLIST

echo "# ap" >> $BLACKLIST
(
    echo "mariadb"
) | sort -u >> $BLACKLIST

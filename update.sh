#!/bin/bash

date > update.log

echo "Syncing tree..."
./slacksync.sh &>> update.log || exit 1

echo "Generating meta info..."
./genmeta.sh &>> update.log || exit 1

echo "Generating DEPENDENCIES..."
./sd2deps.sh &>> update.log || exit 1

echo "Generating BLACKLIST..."
./blacklist.sh &>> update.log || exit 1

echo "Generating MINIMAL template..."
./minimal.template.sh &>> update.log || exit 1

echo "Generating LXC template..."
./lxc.template.sh &>> update.log || exit 1

echo "Generating SERVER template..."
./server.template.sh &>> update.log || exit 1

#echo "Generating tagfiles..."
#./temp2tag.sh &>> update.log || exit 1

echo "Generating initrd..."
./initrd.sh &>> update.log || exit 1

echo "Generating install iso..."
./mkiso.sh &>> update.log || exit 1

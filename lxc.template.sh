#!/bin/bash

./deps2temp.sh \
LXC \
| grep -v LXC \
| sort -u \
> lxc.template

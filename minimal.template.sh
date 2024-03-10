#!/bin/bash

./deps2temp.sh \
MINIMAL \
| grep -v CORE \
| grep -v MINIMAL \
| grep -v NETWORK-SCRIPTS \
| grep -v SLACKPKG \
| sort -u \
> minimal.template

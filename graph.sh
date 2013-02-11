#!/bin/bash

# custom settings
. `dirname $0`/env.sh

h=${1:-24}
u=${2:-90}
let h=h*3600
out=`mktemp -u --suffix=.png`

cmd="rrdtool graph $out -s -$h"
cmd="$cmd -w 1280 -h 770 -D"
cmd="$cmd -v Seconds -u $u -r --grid-dash 1:3"
cmd="$cmd HRULE:3#0000FF:'3 sec latency'"
cmd="$cmd HRULE:30#00FF00:'30 sec latency'"
cmd="$cmd HRULE:60#FF0000:'60 sec latency'"
for id in "${!urls[@]}"; do
    c=${color[$id]}
    c=${c:-"#000000"}
    cmd="$cmd DEF:$id=$rrd:$id:MAX LINE2:$id$c:$id"
done

eval $cmd

if which feh 2>&1 >/dev/null; then
    feh -ZF $out
else
    xdg-open $out
fi

rm -f $out

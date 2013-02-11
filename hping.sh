#!/bin/bash

# current time in two formats
t=`date -u +"%F_%T %s"`

# custom settings
. `dirname $0`/env.sh

if [[ ! -d $dir ]]; then mkdir -p $dir; fi

# format timestamp
ts=`echo $t |awk '{print $1}'`

# get utc seconds
us=`echo $t |awk '{print $2}'`

logerr() {
    while read line; do
        echo "`date -u --rfc-3339=ns` $line"
    done
}

logtime() {
    awk -v usec=$us -v id=$2 '
    /real/  {
        if (NF == 4 && $3 == "real")
            print id, $4
        else
            exit 1
    }' $1
}

poke() {
    local id=$1
    local out="$dir/${id}_$ts.out"
    local err="$dir/${id}_$ts.err"
    local url=${urls[$id]}
    set -o pipefail
    if (time -p wget -O $out $url >/dev/null) |& logerr >$err; then
        if logtime $err $id; then
            rm -f $out $err
        fi
    else
        ret=$?
        # Server issued an error response?
        if (( $ret == 8 )); then
            logtime $err $id
        fi
        # removing $out if empty
        if [[ -e $out && ! -s $out ]]; then
            rm -f $out
        fi
        # cat $err
    fi
}

rrd_create() {
    cmd="rrdtool create $1 -s 300"
    for id in "${!urls[@]}"; do
        cmd="$cmd DS:$id:GAUGE:600:U:U"
    done
    cmd="$cmd RRA:MAX:0.5:1:8928"  # 31 day of 5-min step
    cmd="$cmd RRA:MAX:0.5:12:8784" # 366 days of 1-hour step
    eval $cmd
}

if [[ ! -e $rrd ]]; then
    rrd_create $rrd
fi

for id in "${!urls[@]}"; do
    poke $id &
done |awk -v usec=$us -v rrd=$rrd '
BEGIN {
    n = 0
} {
    key[n]   = $1
    val[n++] = $2
}
END {
    acc = "rrdtool update " rrd " -t " key[0]
    for (i=1; i<n; i++) acc = acc ":" key[i]
    acc = acc " -- " usec
    for (i=0; i<n; i++) acc = acc ":" val[i]
    system(acc)
}
'

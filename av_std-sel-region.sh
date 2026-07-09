#!/bin/bash
# Average and standard deviation of one column over a row range of a data file.
#
# Usage: ./av_std-sel-region.sh <file> <column> <init> <end> [stride]
#   file    : whitespace-separated data (e.g. a PLUMED COLVAR)
#   column  : 1-based column to analyse
#   init,end: 1-based inclusive row range (by line number)
#   stride  : take every Nth row in the range (default 1)
#
# Only rows whose first field starts with a digit are counted (skips headers).
# Prints two lines: a label and "<average> <stddev>".

if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo "usage: ./av_std-sel-region.sh <file> <column> <init> <end> [stride]"
    exit 1
fi
file=$1
column=$2
init=$3
end=$4
stride=${5:-1}

av=$(awk 'BEGIN{sum=0;count=0}
    {if (($1 ~ /^[0-9]/) && (NR >= '"$init"') && (NR <= '"$end"') && ((NR-'"$init"')%'"$stride"'==0)){count++;sum+=$'"$column"'}}
    END{if(count>0) printf "%5.2f", sum/count; else print "NaN"}' "$file")

std=$(awk -v av="$av" 'BEGIN{var=0;count=0}
    {if (($1 ~ /^[0-9]/) && (NR >= '"$init"') && (NR <= '"$end"') && ((NR-'"$init"')%'"$stride"'==0)){count++;var+=($'"$column"'-av)^2}}
    END{if(count>1){var/=(count-1); printf "%5.2f", sqrt(var)} else print "NaN"}' "$file")

echo "Average (Standard Deviation)"
echo "$av $std"

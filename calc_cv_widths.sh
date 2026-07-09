#!/bin/bash
# Estimate metadynamics SIGMA (Gaussian width) for each CV from an unbiased run.
#
# For every CV column of a PLUMED COLVAR file, this slides a window across the
# trajectory, takes the standard deviation of the CV within each window, and
# reports the mean of those per-window standard deviations - a robust estimate
# of the CV's local fluctuation, which is a sensible starting SIGMA.
#
# Usage: ./calc_cv_widths.sh [colvar] [n_cvs] [n_frames] [window] [step]
#   colvar   : COLVAR file            (default: COLVAR_apoMDstd)
#   n_cvs    : number of CVs          (default: 4)  -> uses columns 2..n_cvs+1
#   n_frames : rows to scan           (default: 5001)
#   window   : window length in rows  (default: 100)
#   step     : window start increment (default: 10)
#
# Outputs CV1.tmp..CVn.tmp (per-window std for each CV) and CVs_widths.dat
# (one "CV<k> <mean_std>" line per CV, the suggested SIGMA values).

colvar=${1:-COLVAR_apoMDstd}
n_cvs=${2:-4}
n_frames=${3:-5001}
window=${4:-100}
step=${5:-10}
here="$(cd "$(dirname "$0")" && pwd)"

if [ -e CVs_widths.dat ]; then
    echo "CVs_widths.dat exists - remove it first if you want to recompute."
    exit 0
fi
if [ ! -e "$colvar" ]; then
    echo "COLVAR file not found: $colvar"
    exit 1
fi

rm -f CV[0-9]*.tmp

# Per-window standard deviation of each CV.
for i in $(seq 1 "$step" "$n_frames"); do
    j=$((i + window - 1))
    for k in $(seq 1 "$n_cvs"); do
        col=$((k + 1))   # column 1 is time; CV k is in column k+1
        "$here/av_std-sel-region.sh" "$colvar" "$col" "$i" "$j" \
            | grep -v Average | awk '{print $2}' >> "CV${k}.tmp"
    done
done

# Suggested SIGMA per CV = mean of the per-window standard deviations.
: > CVs_widths.dat
for k in $(seq 1 "$n_cvs"); do
    mean=$(awk 'BEGIN{s=0;n=0}
        /^[0-9.]+$/ {s+=$1;n++}
        END{if(n>0) printf "%.3f", s/n; else print "NaN"}' "CV${k}.tmp")
    echo "CV${k} ${mean}" >> CVs_widths.dat
done

echo "Wrote CVs_widths.dat (suggested SIGMA per CV):"
cat CVs_widths.dat

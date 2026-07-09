#!/bin/bash
# Generate a moving-wall restraint schedule for a slow contraction of one CV,
# in PLUMED MOVINGRESTRAINT STEP/AT/KAPPA form.
#
# Two phases:
#   1. Kappa ramp (STEP0-STEP4): position held at R_max while the force constant
#      is ramped 2 -> 10, so the restraint switches on gently.
#   2. Moving phase (STEP5 onward): force held at 10 while the target position is
#      walked linearly from R_max down to R_min over the rest of the run.
#
# Usage: ./calc_walls.sh <R_min> <R_max> [total_steps] > restraints.dat
#   R_min, R_max : CV range (same units as the CV, e.g. Angstrom for RoG)
#   total_steps  : final MD step of the moving phase (default 250000000)
#
# Diagnostics go to stderr; only the STEP/AT/KAPPA lines go to stdout, so you can
# redirect straight into restraints.dat.

if [ $# -lt 2 ]; then
    echo "usage: ./calc_walls.sh <R_min> <R_max> [total_steps] > restraints.dat" >&2
    exit 1
fi
R_min=$1
R_max=$2
total_steps=${3:-250000000}

# Protocol constants (edit if your equilibration length differs).
ramp_start=49750000     # first STEP of the kappa ramp
ramp_incr=1250000       # step increment during the ramp
move_start=55250000     # first STEP of the moving phase
move_incr=500000        # step increment during the moving phase

n_intervals=$(( (total_steps - move_start) / move_incr + 1 ))
R_diff=$(echo "$R_max - $R_min" | bc -l)
R_step=$(echo "$R_diff / $n_intervals" | bc -l)

echo "R_diff=$R_diff  (walked over $n_intervals moving intervals)" >&2
echo "R_step=$R_step" >&2

# --- Phase 1: kappa ramp, position held at R_max, force 2 -> 10 ---
kappa=2
step=$ramp_start
for index in 0 1 2 3 4; do
    echo "STEP$index=$step  AT$index=$R_max KAPPA$index=$kappa"
    step=$((step + ramp_incr))
    kappa=$((kappa + 2))
done

# --- Phase 2: moving phase, force carried forward at 10 ---
# Integer bash loop (not seq) so STEP values are always plain integers, not
# scientific notation, on both GNU and BSD systems. The trailing /1 forces bc
# to apply scale=3 to the AT position.
index=5
n=1
s=$move_start
while [ "$s" -le "$total_steps" ]; do
    at=$(echo "scale=3; ($R_max - $n * $R_step)/1" | bc)
    echo "STEP$index=$s  AT$index=$at"
    index=$((index + 1))
    n=$((n + 1))
    s=$((s + move_incr))
done

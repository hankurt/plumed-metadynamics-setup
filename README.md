# PLUMED bias-exchange metadynamics setup

Scripts to set up **bias-exchange metadynamics** of a protein **binding site**
with [PLUMED](https://www.plumed.org/). They build the collective variables,
estimate the Gaussian widths, and generate a moving-wall restraint schedule -
everything you need to fill in the PLUMED input templates before launching.

The four collective variables describe binding-site shape:

| CV | Definition | Reports |
|---|---|---|
| `cv1` | radius of gyration of the binding-site backbone | overall size |
| `cv2` | coordination across the **XY** plane (two halves along Z) | opening along Z |
| `cv3` | coordination across the **XZ** plane (two halves along Y) | opening along Y |
| `cv4` | coordination across the **YZ** plane (two halves along X) | opening along X |

Each replica biases one CV; PLUMED's `RANDOM_EXCHANGES` swaps them.

---

## Workflow

```
1. divide_binding_site.tcl   (VMD)  ->  serials_RoG, serials_xy/xz/yz
        paste serials into plumed-common.dat (ATOMS / GROUPA / GROUPB)

2. run a short unbiased MD with plumed-common.dat  ->  COLVAR_apoMDstd

3. calc_cv_widths.sh   ->  CVs_widths.dat   (SIGMA for each CV; fills the XXX)

4. calc_walls.sh R_min R_max  >  restraints.dat   (moving RoG wall)
        paste into the MOVINGRESTRAINT block of plumed-common.dat

5. run bias-exchange metadynamics with plumed.0.dat ... plumed.3.dat
```

---

## Files

| File | Role |
|---|---|
| `divide_binding_site.tcl` | VMD script: aligns the binding site to the axes and splits its residues into the atom-serial groups for each CV |
| `plumed-common.dat` | shared PLUMED input: the 4 CV definitions + a slot for the moving wall (`ATOMS=` / `GROUPA=` / `GROUPB=` / `SIGMA=XXX` are filled from the steps below) |
| `plumed.0.dat` … `plumed.3.dat` | per-replica bias inputs, one `METAD` per CV; each `INCLUDE`s `plumed-common.dat` |
| `calc_cv_widths.sh` | estimate a metadynamics `SIGMA` per CV from an unbiased COLVAR |
| `av_std-sel-region.sh` | helper: average + std of a column over a row range (used by `calc_cv_widths.sh`) |
| `calc_walls.sh` | generate the moving-wall `STEP/AT/KAPPA` schedule |

---

## `divide_binding_site.tcl` (in VMD)

Edit the two settings at the top - the binding-site residue selection and the
`resid` / `residue` keyword (use `residue` if your numbering has gaps or spans
multiple chains) - then, with a structure + trajectory loaded:

```tcl
vmd> source divide_binding_site.tcl
```

It centres the binding site, aligns its principal axes to X/Y/Z (via the VMD
**Orient** package), and writes `serials_RoG`, `serials_xy`, `serials_xz`,
`serials_yz` - comma-separated atom serials to paste into `plumed-common.dat`.

> Requires VMD with the `Orient` package (`draw principalaxes` / `orient`).

---

## `calc_cv_widths.sh` - metadynamics SIGMA

Slides a window along an unbiased COLVAR and reports, per CV, the mean of the
per-window standard deviations - a robust estimate of each CV's fluctuation and
a good starting `SIGMA`.

```bash
./calc_cv_widths.sh [colvar] [n_cvs] [n_frames] [window] [step]
# defaults:          COLVAR_apoMDstd  4      5001      100      10
```

Writes `CV1.tmp…CVn.tmp` (per-window std) and `CVs_widths.dat` (the suggested
`SIGMA` per CV). Handles any number of CVs, so the same script covers 4-, 5- or
8-CV setups.

---

## `calc_walls.sh` - moving-wall schedule

Produces a `MOVINGRESTRAINT` schedule that (1) ramps the force constant 2→10
while holding the wall at `R_max`, then (2) walks the wall linearly from `R_max`
down to `R_min` over the rest of the run.

```bash
./calc_walls.sh <R_min> <R_max> [total_steps] > restraints.dat
# total_steps default: 250000000  (the divisor adapts to the run length)
```

Diagnostics go to stderr; only the `STEP/AT/KAPPA` lines reach stdout, so the
redirect gives a clean `restraints.dat`. Paste its contents into the
`MOVINGRESTRAINT` line of `plumed-common.dat`.

---

## Requirements

- **VMD** with the **Orient** package (for `divide_binding_site.tcl`)
- **PLUMED**-patched MD engine (e.g. GROMACS `mdrun -plumed`)
- **bash**, **awk**, **bc**

The plain-MD / metadynamics `.mdp` files that drive the GROMACS side live in
[gromacs-mdp-templates](https://github.com/hankurt/gromacs-mdp-templates); the
representative-structure clustering that consumes the trajectories is in
[rog-adaptive-clustering](https://github.com/hankurt/rog-adaptive-clustering).

---

## License

MIT - see [LICENSE](LICENSE).

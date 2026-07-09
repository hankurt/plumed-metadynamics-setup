#------------------------------------------------------------
# divide_binding_site.tcl   (run inside VMD)
#
# Prepares the atom-serial groups needed by plumed-common.dat for a
# bias-exchange metadynamics run on a binding site (BS):
#
#   * serials_RoG : backbone atoms of the BS -> radius-of-gyration CV (cv1)
#   * serials_xy  : BS residues split by the XY plane (Z>=0 / Z<0) -> cv2
#   * serials_xz  : BS residues split by the XZ plane (Y>=0 / Y<0) -> cv3
#   * serials_yz  : BS residues split by the YZ plane (X>=0 / X<0) -> cv4
#
# The BS is first centred and its principal axes aligned to X/Y/Z, then each
# residue is assigned to one side of each plane by its backbone centre of mass.
# The two halves either side of a plane become GROUPA / GROUPB of a COORDINATION
# CV that reports opening/closing of the site along that axis.
#
# Requires VMD with the Orient package (draw principalaxes / orient). Load a
# structure + trajectory first, then:  vmd> source divide_binding_site.tcl
#
# Each output file lists the two half-groups as comma-separated atom serials;
# paste them into the ATOMS= / GROUPA= / GROUPB= fields of plumed-common.dat.
#------------------------------------------------------------

# ===================== EDIT THIS BLOCK ==============================
# Residues lining the binding site of interest (VMD selection syntax).
set bs_selection "resid 8 to 13 15 31 32 35 36 57 to 59 64 84 to 86 88 92 119 120 123 134 137 156 158 167 200 201 202 205"

# Residue identifier keyword:
#   resid   -> PDB residue numbers (use when numbering is unique/clean)
#   residue -> VMD internal 0-based index (use for gaps or multiple chains)
set idkey "resid"
# ===================================================================

lappend auto_path Orient
package require Orient
namespace import Orient::orient

# Flatten a (possibly nested) serial list and write "header + comma list" to a
# file handle; also echo to the VMD console.
proc emit {fh header serials} {
    set flat [join [concat {*}$serials] ,]
    puts $fh $header
    puts $fh $flat
    puts "$header $flat"
}

# Residues -> heavy-atom serials (one sub-list per residue).
proc serials_of {idkey resids} {
    set out {}
    foreach i $resids {
        lappend out [[atomselect top "$idkey $i and noh"] get serial]
    }
    return $out
}

# --- Binding-site selection ---
set sel    [atomselect top "noh and $bs_selection"]
set selrog [atomselect top "[$sel text] and backbone"]
set L      [lsort -integer -uniq [$sel get $idkey]]

# --- RoG group: backbone serials of the whole BS (cv1) ---
set fh [open serials_RoG w]
emit $fh "Rog serials:" [lsort -integer -uniq [$selrog get serial]]
close $fh

# --- Align BS principal axes to the X/Y/Z axes ---
set all [atomselect top all]
$all moveby [vecscale -1 [measure center $sel]]
set I [draw principalaxes $sel]
$all move [orient $sel [lindex $I 2] {0 0 1}]
set I [draw principalaxes $sel]
$all move [orient $sel [lindex $I 1] {0 1 0}]

# --- Split residues by side of each plane (by backbone centre of mass) ---
set X_1 {}; set X_2 {}
set Y_1 {}; set Y_2 {}
set Z_1 {}; set Z_2 {}
foreach i $L {
    set cm [measure center [atomselect top "$idkey $i and backbone"]]
    if {[lindex $cm 0] >= 0} { lappend X_1 $i } else { lappend X_2 $i }
    if {[lindex $cm 1] >= 0} { lappend Y_1 $i } else { lappend Y_2 $i }
    if {[lindex $cm 2] >= 0} { lappend Z_1 $i } else { lappend Z_2 $i }
}

# --- Plane XY (split along Z) -> cv2 ---
puts "\nplane xy"
puts "Z_1 resids: $Z_1"
puts "Z_2 resids: $Z_2"
set fh [open serials_xy w]
emit $fh "Z_1 serials:" [serials_of $idkey $Z_1]
emit $fh "Z_2 serials:" [serials_of $idkey $Z_2]
close $fh

# --- Plane XZ (split along Y) -> cv3 ---
puts "\nplane xz"
puts "Y_1 resids: $Y_1"
puts "Y_2 resids: $Y_2"
set fh [open serials_xz w]
emit $fh "Y_1 serials:" [serials_of $idkey $Y_1]
emit $fh "Y_2 serials:" [serials_of $idkey $Y_2]
close $fh

# --- Plane YZ (split along X) -> cv4 ---
puts "\nplane yz"
puts "X_1 resids: $X_1"
puts "X_2 resids: $X_2"
set fh [open serials_yz w]
emit $fh "X_1 serials:" [serials_of $idkey $X_1]
emit $fh "X_2 serials:" [serials_of $idkey $X_2]
close $fh

puts "\nWrote serials_RoG, serials_xy, serials_xz, serials_yz"
quit

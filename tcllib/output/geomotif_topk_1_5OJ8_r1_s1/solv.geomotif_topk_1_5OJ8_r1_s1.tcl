package require solvate
package require autoionize
source size.tcl

mol new geomotif_topk_1_5OJ8_r1_s1_H.psf
mol addfile geomotif_topk_1_5OJ8_r1_s1_H.pdb

set protein [atomselect top all]
$protein moveby [vecscale -1 [measure center $protein]]

set size_info [size all all]
set dimensions [lindex $size_info 1]
set half_box [list \
  [expr {([lindex $dimensions 0] + 50.0) / 2.0}] \
  [expr {([lindex $dimensions 1] + 50.0) / 2.0}] \
  [expr {([lindex $dimensions 2] + 50.0) / 2.0}]]
set box_min [vecscale -1 $half_box]
set box_max $half_box

puts "Solvation box min: $box_min"
puts "Solvation box max: $box_max"
puts "Solvation box dimensions: [vecscale 2 $half_box]"

set metadata [open "geomotif_topk_1_5OJ8_r1_s1.dat" w]
puts $metadata "geomotif_topk_1_5OJ8_r1_s1_H_wi [join [vecscale 2 $half_box] \t] 0.0 0.0 0.0"
close $metadata

$protein writepdb geomotif_topk_1_5OJ8_r1_s1_centered.pdb
$protein delete

solvate geomotif_topk_1_5OJ8_r1_s1_H.psf geomotif_topk_1_5OJ8_r1_s1_centered.pdb -minmax [list $box_min $box_max] -o geomotif_topk_1_5OJ8_r1_s1_solvated
autoionize -psf geomotif_topk_1_5OJ8_r1_s1_solvated.psf -pdb geomotif_topk_1_5OJ8_r1_s1_solvated.pdb -sc 0.15 -cation POT -o geomotif_topk_1_5OJ8_r1_s1_H_wi
quit

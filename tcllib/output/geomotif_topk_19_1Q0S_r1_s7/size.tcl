proc size {center_selection dimension_selection} {
  set center_sel [atomselect top $center_selection]
  set dimension_sel [atomselect top $dimension_selection]

  if {[$center_sel num] == 0 || [$dimension_sel num] == 0} {
    error "size: an atom selection is empty"
  }

  set center [measure center $center_sel]
  lassign [measure minmax $dimension_sel] min_coord max_coord
  set dimensions [vecsub $max_coord $min_coord]

  $center_sel delete
  $dimension_sel delete

  puts "Center: $center"
  puts "Dimensions: $dimensions"
  return [list $center $dimensions]
}

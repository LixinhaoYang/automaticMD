package require psfgen
resetpsf
topology top_all36_prot.rtf
pdbalias residue MSE MET
pdbalias residue HIS HSE
pdbalias atom ILE CD1 CD

segment AP {
  first NTER
  pdb text.pdb
  last CTER
}

coordpdb text.pdb AP

guesscoord
regenerate angles dihedrals
guesscoord
writepdb text_H.pdb
writepsf text_H.psf
quit

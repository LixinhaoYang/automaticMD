package require psfgen
resetpsf
topology top_all36_prot.rtf
pdbalias residue MSE MET
pdbalias residue HIS HSE
pdbalias atom ILE CD1 CD

segment AP {
  first NTER
  pdb geomotif_topk_19_1Q0S_r1_s7.pdb
  last CTER
}

coordpdb geomotif_topk_19_1Q0S_r1_s7.pdb AP

guesscoord
regenerate angles dihedrals
guesscoord
writepdb geomotif_topk_19_1Q0S_r1_s7_H.pdb
writepsf geomotif_topk_19_1Q0S_r1_s7_H.psf
quit

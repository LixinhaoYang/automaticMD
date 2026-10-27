# Automated protein water-box builder

Build one or more protein systems with PSFGEN, center each protein, add 25 Å
of water on every side, and add KCl at 0.15 mol/L.

```bash
cd ..
chmod +x build_water_box.sh
./build_water_box.sh geomotif_topk_1_5OJ8_r1_s1.pdb
```

To process both test inputs:

```bash
./build_water_box.sh *.pdb
```

Intermediate results are written under `tcllib/output/<pdb-basename>/`.
Ready-to-run structure files are copied to `runfile/struc/`, while the
tab-separated `systems.dat` index stays in `runfile/`. Both structure files share one
basename (`<name>.psf` and `<name>.pdb`), so each index row stores that basename
once followed by the box lengths and box origin. Rebuilding a system replaces
its existing row. The first line of `systems.dat` is the cluster-specific
parameter directory. A NAMD config is generated from `base.conf` under
`runfile/conf/<name>.conf` for every newly built system.

The current VMD default is
`/Applications/VMD2b1.app/Contents/vmd2b1/vmd_MACOSXARM64`. On another system,
set it without editing the workflow:

```bash
VMD_BIN=/path/to/vmd ./build_water_box.sh protein.pdb
```

Set `OUTPUT_DIR` or `RUNFILE_DIR` similarly to change those locations. The Bash script
copies each PDB into an isolated work directory and replaces the literal
`text` token in the Tcl templates with its real basename before invoking VMD.

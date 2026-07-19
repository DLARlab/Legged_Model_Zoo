# SLIP Quadruped RoadMap dataset

This directory is a repository-contained copy of the complete `1_Roadmap`
folder from `DLARlab/SLIP_Model_Zoo` commit
`2c106101383ecee1b2a9d695efe09fbd72d5718a`.

It contains nine legacy MAT branches (`results`, 29×N) and the two reference
FIG files shipped by the source repository. The nine branches contain 3,443
points in total. `roadmap_manifest.json` records every source SHA-256 digest,
point count, inferred gait summary, native-artifact location, source path, and the
default RoadMap view.

The public runtime loads the generated `native/*.lmz.mat` artifacts when their
recorded source digest matches the copied MAT file. Maintainers can reimport
the legacy files and reproduce the native artifacts with:

```matlab
startup;
addpath(fullfile(pwd, 'tools', 'maintainers'));
import_slip_quadruped_roadmap
report = verify_slip_quadruped_roadmap
```

The upstream repository does not state a software or data license. These
assets were copied under the user's explicit Round 5 implementation request;
no open-source license is inferred. See `THIRD_PARTY_NOTICES.md` and
`docs/provenance.md` before redistribution.

Scientific attribution: Ding and Gan, “Breaking Symmetries Leads to Diverse
Quadrupedal Gaits,” *IEEE Robotics and Automation Letters* 9(5), 4782–4789
(2024), DOI `10.1109/LRA.2024.3384908`.

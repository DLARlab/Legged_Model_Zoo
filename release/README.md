# Release engineering

Public release output is authorization-gated. The current repository has no
root project license, and all scientific material has unresolved scope, so no
public archive is presently permitted.

From a started checkout:

```matlab
startup;
addpath(fullfile(lmz.util.ProjectPaths.root(),'tools','release'));
scan_redistribution;
core = build_release('core',struct('DryRun',true));
scientific = build_release('scientific',struct('DryRun',true));
```

Maintainers refresh hashes after an intentional source change with:

```matlab
scan_redistribution('refresh');
```

Refresh preserves existing decision fields. Review the diff: a hash refresh
is not permission to change `decisionStatus` or `redistributable`.

`Mode='technical-validation'` exercises staging, deterministic ZIP creation,
verification, and cleanup in temporary storage. It returns evidence but never
retains an archive. Add `RunInstallTest=true` to test both a preflight and final
package in unrelated child-MATLAB sessions. The child must discover and run the
built-in analytic hopper tutorial, construct the GUI invisibly, round-trip a
native artifact, remove/uninstall the package, and prove that its public entry
points no longer resolve.

ZIP `RELEASE_MANIFEST.json` and toolbox `TOOLBOX_RELEASE.json` records include
the source commit, clean/dirty/unknown worktree state, package-test evidence,
and an explicit statement that the full repository suite is not run by the
package builder. Evidence is deterministic: no timestamps, temporary paths, or
child-process output are embedded. Only successfully verified packages can be
returned, and only `Mode='public'` writes to `release/out` after every selected
entry and the project decision are explicitly permitted.

Generated ZIP/MLTBX files and checksums are local outputs and are not committed.

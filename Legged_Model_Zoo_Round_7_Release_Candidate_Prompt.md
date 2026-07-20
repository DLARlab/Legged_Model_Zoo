# Codex Round 7 — Release Candidate, CI, Packaging, Desktop QA, and Extensibility

You are the senior MATLAB release engineer and software architect responsible
for turning the existing `DLARlab/Legged_Model_Zoo` repository into a
maintainable, reproducible release candidate.

Work directly in the current local clone. Preserve all validated scientific
behavior. This is not another model-migration round and not an excuse to
rewrite the scientific equations.

The repository already contains source-equivalent scientific workflows for:

```text
slip_biped
slip_quadruped
slip_quad_load
```

The objectives of this round are:

```text
freeze and stabilize the public API
complete real GUI componentization
perform desktop and cross-release QA
add reproducible CI
build license-aware release packages
complete model-authoring/configuration documentation
prove third-party model extensibility
profile and harden performance
produce an auditable release candidate
```

Do not finish with only plans, YAML skeletons, unexecuted packaging scripts, or
claims that legal/desktop/R2019b blockers disappeared without evidence.

---

## 1. Verify the starting point

Before editing:

```bash
git status --short
git rev-parse HEAD
git log --oneline --decorate -10
```

Do not discard user work. Never use:

```text
git reset --hard
git clean -fd
git checkout -- .
history rewriting
force push
```

Do not push or create a remote release.

The public repository was last observed at:

```text
0ec3b32c7e6ed1db6efd86c30a9fd3c38cb73d11
```

The local checkout is authoritative if newer.

Read:

```text
README.md
MIGRATION_STATUS.md
CHANGELOG.md
THIRD_PARTY_NOTICES.md
docs/TEST_STATUS.md
docs/KNOWN_DIFFERENCES.md
docs/MANUAL_DESKTOP_QA.md
docs/REDISTRIBUTION_STATUS.md
docs/REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md
docs/architecture.md
docs/continuation.md
docs/data-format.md
docs/gui-design.md
docs/provenance.md
```

Run the current validation commands before changing anything:

```matlab
startup;
results = run_tests;
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
```

Also run:

```matlab
startup;
addpath(fullfile(lmz.util.ProjectPaths.root(),'tools'));
cleanup = onCleanup(@()rmpath(fullfile(lmz.util.ProjectPaths.root(),'tools')));
check_readme_contract;
[compatibilityViolations,compatibilityReport] = ...
    check_matlab_compatibility(lmz.util.ProjectPaths.root());
assert(isempty(compatibilityViolations));
```

Record the baseline:

```text
test count
test duration
example count
repository size
MATLAB release
toolboxes
operating system
desktop availability
```

The verified public starting point reports:

```text
117 tests
0 failed
0 incomplete
24 public examples
R2025b Update 5
standalone all-model isolation passed
```

All existing scientific regression tests are non-regression gates. Do not
weaken tolerances, remove fixtures, or convert source-equivalent problems back
to tutorials.

---

## 2. Confirm the remaining release blockers

The current known blockers are:

```text
human MATLAB desktop walkthrough not executed
MATLAB R2019b runtime not executed
public redistribution rights unresolved
no GitHub Actions workflow evidence
no root LICENSE file
no tested toolbox/zip release package
main GUI class still owns most widgets and callbacks
tab classes are declarative shells rather than complete components
architecture documentation is too brief
model-authoring and configuration-reference guides are absent
no fully tested external-model template/SDK
```

Verify each statement against the local tree. Correct this list if the local
checkout is newer, but do not silently ignore any verified blocker.

---

# PART A — Freeze the release contract

## 3. Establish project versioning

Create:

```text
VERSION
src/+lmz/+util/Version.m
docs/RELEASE_NOTES_1_0.md
```

Use semantic versioning.

Until all release gates pass, use:

```text
1.0.0-rc.1
```

or the next appropriate release-candidate number.

`lmz.util.Version` must expose:

```text
current
parse
compare
isCompatible
artifactSchemaVersion
catalogSchemaVersion
minimumMatlabRelease
```

All new artifacts and run records must include:

```text
frameworkVersion
artifactSchemaVersion
modelVersion
problemVersion
minimumMatlabRelease
```

Add tests for version parsing, comparison, artifact compatibility, and
unsupported future schema versions.

Do not change existing model/problem versions without a documented migration.

---

## 4. Define API compatibility policy

Create:

```text
docs/API_STABILITY.md
docs/DEPRECATION_POLICY.md
```

Classify public APIs:

```text
stable
provisional
internal
legacy-import-only
```

At minimum classify:

```text
startup
legged_model_zoo
ModelRegistry
LeggedModel
BaseProblem
NonlinearEquationProblem
OptimizationProblem
SimulationResult
Solution
SolutionBranch
ArtifactStore
SimulationService
SolveService
ContinuationService
OptimizationService
RunContext
canonical model IDs
artifact schema
catalog schema
```

Rules:

- stable APIs require deprecation before removal;
- provisional APIs may change only with release notes;
- internal packages are not promised to users;
- deprecated model IDs remain import aliases for at least one major release;
- artifacts written by 1.x must have an explicit compatibility policy.

Add compatibility tests using representative artifacts from Rounds 5 and 6.

---

# PART B — Redistribution and release profiles

## 5. Do not fabricate licensing authority

The repository currently records unresolved redistribution rights.

Codex must not invent:

```text
a license
an owner signature
a copyright assignment
a redistribution grant
a data-use grant
```

Inspect the local tree for completed owner decisions. A decision is valid only
when an owner-supplied record explicitly identifies:

```text
material
owner or authorized licensor
scope
permitted redistribution
permitted modification
license text or grant text
required attribution
date
decision authority
```

If no valid decision exists, preserve the blocker.

---

## 6. Machine-readable redistribution inventory

Create:

```text
release/redistribution_manifest.json
tools/release/scan_redistribution.m
tests/release/TestRedistributionInventory.m
```

The inventory must cover every distributable file and derived artifact:

```text
framework source
tutorial source/data
quadruped migrated code
quadruped RoadMap MAT/FIG/native/baseline/screenshots
biped migrated code
biped GaitMap/fit/native/baselines
load migrated code
load scientific data/native/baselines
documentation figures
generated test artifacts
third-party notices
```

For every entry record:

```text
relativePath
sha256
category
sourceRepository
sourceCommit
licenseId
decisionStatus
redistributable
requiredNotice
generatedFrom[]
```

The scanner must detect unlisted files and stale hashes.

Derived native artifacts and fixtures inherit the source-material decision
unless an owner decision explicitly says otherwise.

---

## 7. Release profiles

Implement two release profiles:

### 7.1 Framework/core profile

```text
legged-model-zoo-core
```

This profile includes only files with explicit redistribution authorization.

It must remain functional for:

```text
registry
schemas
artifacts
tutorial analytic models
generic solve/continuation/optimization tests
model-authoring template
GUI construction
```

Do not claim that the scientific research datasets are included.

### 7.2 Scientific/full profile

```text
legged-model-zoo-scientific
```

This profile may be built only if every included scientific source/data item
has an explicit permitted decision.

If any decision is unresolved:

- the build must fail before writing a final archive;
- the report must list blocking files and decisions;
- no partially complete “full” archive may remain.

Create:

```text
tools/release/build_release.m
tools/release/verify_release.m
tools/release/release_file_list.m
tests/release/TestCoreReleaseProfile.m
tests/release/TestScientificReleaseGate.m
```

Use temporary staging directories and atomic final rename.

Prompt files, `.git`, local caches, temporary outputs, and maintainer-only
capture scripts must be excluded from public release archives unless
explicitly required.

---

## 8. Project license and notices

There is currently no root `LICENSE`.

Do not create one from assumption.

If a valid project-owner license decision is present, install the exact
approved text as:

```text
LICENSE
```

Otherwise:

- leave `LICENSE` absent;
- keep the release status blocked;
- state that clearly in the final report.

Always synchronize:

```text
THIRD_PARTY_NOTICES.md
docs/REDISTRIBUTION_STATUS.md
release/redistribution_manifest.json
README license section
```

---

# PART C — Continuous integration

## 9. Add CI without claiming unexecuted success

Create:

```text
.github/workflows/static.yml
.github/workflows/matlab.yml
.github/workflows/release-audit.yml
```

Use maintained official MATLAB GitHub Actions when available. Inspect current
official action documentation rather than guessing action names or supported
releases.

### 9.1 Static workflow

Run on pushes and pull requests:

```text
JSON validation
README contract
architecture scan
R2019b static compatibility scan
redistribution inventory scan
git diff/whitespace checks where applicable
manifest/hash verification
```

This workflow must not require MATLAB if equivalent static tools are available.

### 9.2 MATLAB workflow

Run:

```matlab
startup;
results = run_tests;
assert(~any([results.Failed]));
assert(~any([results.Incomplete]));
```

Also run public examples and clean-copy isolation where runner limits permit.

Matrix policy:

- newest supported MATLAB release;
- oldest actually available release near the compatibility target;
- macOS or Windows smoke run when available and justified.

Do not configure an impossible matrix merely to satisfy documentation.

### 9.3 Release audit workflow

Run:

```text
release inventory
license/decision gate
package build in dry-run mode
package verification
artifact upload only when authorized
```

The workflow must never publish a release automatically during this task.

### 9.4 CI evidence

Run the workflow logic locally where possible.

Since Codex cannot push, provide:

```text
exact workflow files
local equivalent commands
expected required secrets/licenses
instructions for the maintainer to enable CI
```

Do not state “CI passes” until a GitHub workflow run actually exists.

---

# PART D — Real GUI componentization

## 10. Refactor the main application

The current `LeggedModelZooApp` still owns most widget construction and
callbacks. The existing tab classes create only tab shells.

Refactor so that:

```text
LeggedModelZooApp
```

owns only:

```text
application lifecycle
top-level figure
header/model/problem selection
status aggregation
tab composition
close/cancel coordination
```

Move complete widget ownership and callback handling into:

```text
lmz.gui.tabs.BranchTab
lmz.gui.tabs.SolutionTab
lmz.gui.tabs.SimulationTab
lmz.gui.tabs.SolveTab
lmz.gui.tabs.ContinuationTab
lmz.gui.tabs.OptimizationTab
```

Each tab is a handle class with:

```text
constructor/build
refresh
setBusy
setCapabilities
setSelection
dispose/delete
test hooks
```

The tab delegates scientific actions to `AppController`; it never calls model
evaluators or numerical algorithms.

Do not enforce an arbitrary line count, but the main app must no longer contain
tab-specific widget callbacks or rendering logic.

---

## 11. State/event synchronization

Replace manual cross-tab refresh chains with an explicit presentation event
mechanism.

Use one of:

```text
observable AppState properties with listeners
typed app events
a small presentation event bus
```

Required events:

```text
ModelChanged
ProblemChanged
DatasetsChanged
SelectionChanged
WorkingSolutionChanged
SimulationChanged
SolveResultChanged
SeedPairChanged
ContinuationChanged
OptimizationChanged
RunStateChanged
StatusChanged
```

Requirements:

- listeners are removed on app close;
- no stale callbacks retain deleted figures;
- changing model/problem invalidates incompatible state exactly once;
- tests detect duplicate refresh invocation and listener leaks;
- headless controller tests remain independent of widgets.

---

## 12. GUI usability and accessibility

Add and test:

```text
tooltips for non-obvious controls
keyboard navigation
tab order
high-DPI/resizable layouts
minimum usable window size
busy-state disabling
cancel availability during long runs
clear error dialogs with technical details expandable
status timestamps
copyable diagnostics
persistent user preferences
recent data/output folders
```

Store preferences under MATLAB preferences using a versioned namespace. Do not
store absolute source-repository paths.

Add a reset-preferences command.

Support a high-contrast/default palette and ensure selected/hovered branch
markers remain distinguishable without relying only on color.

---

## 13. Manual desktop QA

If a real MATLAB desktop/display is available, execute every step in:

```text
docs/MANUAL_DESKTOP_QA.md
```

Record:

```text
MATLAB release
OS
screen resolution
steps
results
defects found
fix commits
human-captured screenshots
```

Store human captures under:

```text
docs/screenshots/manual/slip_quadruped/
docs/screenshots/manual/slip_biped/
docs/screenshots/manual/slip_quad_load/
```

Do not relabel automated captures as human evidence.

If no desktop is available:

- keep the blocker explicit;
- improve the checklist and scripted support;
- do not claim manual QA completion.

---

# PART E — Cross-release compatibility

## 14. Search for actual MATLAB installations

Search local standard locations for:

```text
R2019b
R2020b
R2021a
other older releases
```

Do not download proprietary MATLAB installers or bypass licensing.

If R2019b is available, run:

```text
core unit tests
registry/catalog tests
artifact tests
one tutorial per model
one scientific simulation per model
biped solve
quadruped solve and short continuation
load objective evaluation
GUI construction where supported
```

Record exact results.

If only a newer old release is available, run it and state the actual release.

---

## 15. Compatibility shims

Implement a centralized compatibility layer:

```text
src/+lmz/+compat/
```

Candidate responsibilities:

```text
graphics export fallback
UI property compatibility
JSON/file helpers
VideoWriter profile selection
temporary-file atomic move
string/char normalization
datetime/timestamp formatting
recursive file discovery
Optimization Toolbox option translation
```

Do not scatter release checks throughout model code.

Update `check_matlab_compatibility` to verify that guarded APIs go through
compatibility helpers.

Add tests on R2025b that exercise both preferred and forced-fallback paths.

Do not claim R2019b runtime support without execution on R2019b.

---

# PART F — Packaging and clean installation

## 16. Build a MATLAB toolbox package

Create a toolbox project or reproducible build script:

```text
release/LeggedModelZoo.prj
tools/release/build_toolbox.m
```

The package must:

```text
install startup/runtime code correctly
avoid adding tests/tools recursively
preserve catalog and data paths
include required notices
exclude disallowed release-profile files
expose legged_model_zoo
avoid modifying default MATLAB path permanently beyond toolbox install
```

Build both permitted profiles when authorized.

---

## 17. Install/uninstall test

In a clean temporary MATLAB environment:

1. build the toolbox;
2. install it with MATLAB's supported toolbox installation API;
3. change to an unrelated directory;
4. run registry discovery;
5. run one permitted model workflow;
6. construct the GUI;
7. save/load an artifact;
8. uninstall the toolbox;
9. verify public functions no longer resolve.

Create:

```text
tests/release/TestToolboxInstall.m
tools/release/run_clean_install_test.m
```

If toolbox installation cannot run headlessly on a platform, document and
test the zip/install-script fallback.

---

## 18. Reproducible zip package

Also produce a deterministic zip:

```text
Legged_Model_Zoo-<version>-<profile>.zip
```

Requirements:

```text
sorted file order
normalized timestamps when feasible
SHA-256 checksum
release manifest
version and commit
test evidence
license decision report
```

Verify the archive in a clean temporary directory.

Do not commit generated release binaries unless project policy explicitly
requires it.

---

# PART G — Model authoring and configuration SDK

## 19. Complete missing documentation

Create:

```text
docs/model-author-guide.md
docs/configuration-reference.md
docs/artifact-reference.md
docs/service-api.md
docs/visualization-authoring.md
docs/testing-a-model.md
```

The model-author guide must walk through:

```text
model package
manifest
problem descriptors
state/parameter/decision schemas
simulation
nonlinear-equation problem
optimization problem
capabilities and maturity
scene/kinematics
plot provider
legacy adapter
built-in data manifest
artifacts
tests
GUI integration
```

Every code sample must be executable or linked to an executable example.

---

## 20. Model template generator

Create:

```text
tools/model_template/
tools/new_model.m
```

Command example:

```matlab
new_model('example_hopper', outputRoot);
```

Generate:

```text
models/+lmzmodels/+example_hopper/
catalog/example_hopper/
tests/generated/example_hopper/
examples/demo_example_hopper.m
```

The generated model must not be automatically activated in the production
catalog unless explicitly requested.

Validate IDs, package names, collisions, and output paths.

---

## 21. Prove extensibility with an external plugin fixture

Create a small analytic hybrid hopper or pendular leg model as a test fixture
outside the main model packages.

It must demonstrate:

```text
state/parameter schemas
scheduled hybrid modes
event/reset records
simulation
a periodic nonlinear problem
generic solve
short continuation
scene/kinematics rendering
artifact save/load
optional GUI discovery
```

Install/discover it from a temporary external model root rather than by editing
the core registry code.

Add tests proving:

```text
no model-specific change to src/+lmz is needed
manifest validation works
registry discovers the plugin
solve/continuation work
GUI capability badges work
removing the plugin removes discovery cleanly
```

This is the principal proof that the framework is a model zoo rather than a
hard-coded three-model application.

---

# PART H — Generic hybrid and scene extension contracts

## 22. Add native hybrid extension interfaces without rewriting scientific oracles

Implement stable extension contracts:

```text
lmz.simulation.HybridSystem
lmz.simulation.HybridMode
lmz.simulation.HybridEvent
lmz.simulation.ScheduledEventPolicy
lmz.simulation.GuardEventPolicy
lmz.simulation.ResetMap
lmz.simulation.HybridSimulator
```

Use the external analytic plugin to exercise them.

Do not rewrite the validated scientific biped/quadruped/load evaluators in this
round. They remain compatibility oracles.

Requirements:

```text
stable event ordering
pre/post-event states
duplicate-time policy
mode/contact history
solver options
named outputs
RunContext integration
cancellation
deterministic tests
```

---

## 23. Add generic scene contracts

Implement:

```text
lmz.viz.SceneSpec
lmz.viz.SceneValidator
lmz.viz.SceneRenderer2D
lmz.viz.KinematicsFrame
lmz.viz.PlotPlugin
```

Scene JSON remains declarative and must never evaluate expressions.

Support:

```text
ground
polygon/body
point/marker
line/link
spring
rope
force vector
trail
text
```

Use the analytic plugin as the first complete generic scene example.

Adapt one existing tutorial renderer to the generic scene path without
removing the scientific renderer regression oracle.

---

# PART I — Performance and robustness

## 24. Establish benchmarks

Create:

```text
benchmarks/run_benchmarks.m
benchmarks/README.md
tests/performance/TestPerformanceBudgets.m
```

Measure at minimum:

```text
startup and registry discovery
load one/all quadruped RoadMap branches
load all biped GaitMap branches
load load multi-stride dataset
evaluate each scientific default solution
render 100 animation frames
run short biped solve
run short quadruped continuation
evaluate load objective
build GUI
artifact save/load
```

Record:

```text
median
spread
memory estimate
MATLAB release
hardware
fixture
```

Use conservative regression budgets based on measured baselines. Avoid brittle
microsecond thresholds.

---

## 25. Evaluation caching

Profile before adding caching.

If repeated scientific evaluations dominate GUI interactions, implement a
bounded cache keyed by:

```text
model/problem version
decision values
parameter values
evaluation options
source/data hash
```

Requirements:

```text
no stale results after edits
no hidden cross-run mutation
bounded memory
explicit clear
diagnostics for hit/miss
thread/process safety for supported execution modes
tests for invalidation
```

Do not cache merely because the prompt mentions it.

---

## 26. Numerical diagnostics and reproducibility

Ensure every solve/continuation/optimization run records:

```text
framework version
model/problem versions
MATLAB release
toolboxes
random seed
options
source artifact ID
source/data hashes
elapsed time
function evaluations
termination reason
warnings
```

Add a `reproduceRun` helper that reconstructs a run from a run artifact when
all referenced built-in data remains available.

Test exact reconstruction of options and source lineage; numerical equality is
subject to documented solver/platform tolerances.

---

# PART J — Code quality and documentation quality

## 27. MATLAB code analysis

Create:

```text
tools/run_code_quality.m
tests/architecture/TestCodeQuality.m
```

Run `checkcode` over public runtime code.

Maintain an explicit allowlist for justified warnings. Do not suppress broad
warning classes without explanation.

Detect:

```text
unreachable code
shadowed built-ins
unused variables
excessive nesting
missing public help
package/class name mismatches
direct UI-to-solver calls
resource cleanup omissions
```

---

## 28. Test coverage

Generate code coverage for:

```text
src/+lmz
models/+lmzmodels
```

Report coverage by package and class.

Do not set an arbitrary high threshold that forces meaningless tests.
Establish a measured baseline and fail only on material regression in stable
core/services.

Exclude generated/source-preserved compatibility files only with explicit
justification; keep their numerical regression coverage separately visible.

---

## 29. Complete architecture documentation

Expand `docs/architecture.md` beyond the current short overview.

Include:

```text
dependency diagram
model/problem/service/data/presentation contracts
scientific compatibility evaluator boundary
generic hybrid extension boundary
registry and plugin discovery
artifact/version migration
RunContext lifecycle
GUI state/event architecture
release profiles
security/trust boundaries for JSON and MAT files
```

Add Architecture Decision Records for:

```text
per-problem maturity
compatibility evaluators as scientific oracles
release profiles under mixed licensing
GUI event synchronization
external plugin discovery
hybrid extension contracts
generic scene format
```

---

# PART K — Security and trust boundaries

## 30. Harden file loading

MAT files and JSON manifests are inputs.

Requirements:

```text
never execute loaded function handles
never evaluate strings
validate expected variables/types/dimensions
limit unexpected large allocations where practical
reject path traversal in manifests
canonicalize paths
do not allow implementation classes outside approved roots/namespaces unless
explicitly registered as trusted external plugin roots
```

Add malicious/malformed fixture tests.

Document the trust model.

---

## 31. Project governance files

Create:

```text
CONTRIBUTING.md
SECURITY.md
CODE_OF_CONDUCT.md
CITATION.cff
SUPPORT.md
```

`CITATION.cff` must include the framework citation plus clearly separated
scientific model/publication citations.

Do not assign authorship or copyright ownership without verified project
information.

---

# PART L — Final release gates

## 32. Full validation matrix

Run:

```text
all existing 117 tests
all new tests
all public examples
all data/hash validators
README contract
architecture scan
compatibility scan
redistribution scan
code-quality scan
coverage
core release build and clean install
scientific release build only when authorized
external plugin fixture
clean-copy standalone all-scientific-model test
```

Record exact commands and results.

Do not weaken existing scientific tolerances.

---

## 33. Desktop gate

A desktop-usability release claim requires a completed human walkthrough.

If completed, record evidence.

If not completed:

```text
release candidate may be numerically validated
desktop usability remains unverified
```

Do not collapse those claims.

---

## 34. R2019b gate

A claim of R2019b runtime support requires execution on R2019b.

If unavailable, change user-facing wording from:

```text
MATLAB R2019b or newer
```

to a rigorously qualified statement such as:

```text
Designed for R2019b compatibility; runtime-verified on <actual releases>.
```

Do not overclaim.

---

## 35. Redistribution gate

A public scientific/full release requires completed owner decisions.

If unresolved:

- do not produce a public scientific archive;
- produce only an internal/dry-run report;
- optionally produce the authorized core profile;
- state the blocker prominently.

---

## 36. Release candidate report

Create:

```text
docs/RELEASE_CANDIDATE_STATUS.md
```

It must distinguish:

```text
scientific correctness evidence
automated GUI evidence
human desktop evidence
cross-release evidence
CI evidence
packaging evidence
redistribution authority
```

Use:

```text
Passed
Passed with qualification
Blocked
Not executed
```

Do not use ambiguous “Done” for blocked release gates.

---

## 37. Definition of done

Do not finish this round until all technically achievable gates below hold:

1. Existing 117 scientific tests remain green.
2. Project version and API compatibility policy exist and are tested.
3. Redistribution inventory covers every release file.
4. Release builders enforce authorization decisions.
5. CI workflows are complete and locally validated; remote execution status is
   reported honestly.
6. Main GUI delegates complete tab responsibilities to tab components.
7. App state/event synchronization is explicit and leak-tested.
8. Desktop QA is completed when a desktop exists, otherwise the blocker
   remains explicit.
9. Actual oldest available MATLAB runtime testing is recorded.
10. Compatibility helpers centralize post-R2019b fallbacks.
11. Core toolbox and zip packages build and pass clean installation tests.
12. Scientific/full package builds only when authorized.
13. Model-authoring and configuration documentation is complete.
14. A generated external plugin model is discovered and runs without core
    modifications.
15. Generic hybrid and scene extension contracts are exercised by the plugin.
16. Benchmarks and coverage baselines are recorded.
17. File-loading trust boundaries are tested.
18. Governance, citation, support, and security documents exist.
19. README and release notes match verified evidence.
20. `docs/RELEASE_CANDIDATE_STATUS.md` gives an auditable final decision.

Do not call the project “publicly released” unless redistribution and remote
release actions are explicitly authorized. Do not call desktop QA complete
without a human desktop session. Do not call R2019b verified without an
R2019b execution.

---

## 38. Final report

Report:

1. target repository path;
2. final Git status and HEAD;
3. framework release-candidate version;
4. test totals and exact commands;
5. scientific non-regression totals;
6. CI files and remote/local status;
7. desktop QA status;
8. MATLAB release matrix;
9. core/scientific release-profile results;
10. toolbox install/uninstall result;
11. zip checksum and verification result;
12. redistribution decisions and blockers;
13. external plugin/model-template result;
14. hybrid/scene extension result;
15. performance and coverage summary;
16. code-quality summary;
17. README/API/documentation contract result;
18. final release recommendation:
    - release,
    - release core only,
    - internal release candidate,
    - blocked.

Begin by freezing the Round 6 baseline and creating the redistribution/release
inventory. Next implement CI and package profiles. Then refactor the GUI,
complete cross-release/desktop QA, add the model-authoring/plugin proof, and
finish with packaging and the audited release-candidate report. Continue
without asking for confirmation between technical gates.

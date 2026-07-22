# Quadruped workflow parity map

This audit maps the pinned SLIP quadruped source workflow at commit
`2c106101383ecee1b2a9d695efe09fbd72d5718a` to Legged Model Zoo Round 11.
The immutable source files inspected were:

- `SLIP_Quadruped/SLIP_Quadruped_GUI.m`;
- `SLIP_Quadruped/README.md`;
- `NumericalContinuation1D_Quadruped_v2.m` and
  `NumericalContinuation2D_Quadruped_v2.m` under
  `3_Numerical_Continuation/1_Continuation_Algorithm`;
- `Quadrupedal_ZeroFun_v2.m` and `SolveQuadrupedalZE.m` under
  `1_Dynamic_Frameworks/v2`.

“Complete” below means the user-visible operation has a tested framework route;
it does not mean identical widget geometry. “Qualified” records a deliberate
framework difference. Numerical source equivalence, layout similarity, and
human visual approval are separate claims.

| Source behavior | Source file / function | Current LMZ implementation | Parity status | Remaining difference | Round 11 target | Test / evidence |
|---|---|---|---|---|---|---|
| Source data loading | `SLIP_Quadruped_GUI`: `SelectFolder`, `GetMatFiles`, `PlotSelectedDataset`; README **Input data** | Registered `roadmap` descriptor, `RoadMapDataSourceProvider`, `WorkflowRegistry`, generic `BranchService.loadDataSource` | Complete, with a safer boundary | Source accepts an arbitrary current folder; the built-in route is manifest/hash-bound and user files enter through explicit import. | Registered data-source provider | `TestWorkflowRegistryBuiltIns`, `TestRoadMapManifest`, `TestResults29NativeBranchConversion` |
| Multi-branch plotting | `PlotAllDatasets`, `PlotDatasetByName`, `PlotBranchInGUI` | Provider `list/load`, `AppController.loadAllDataSources`, reusable branch canvas/dataset panel | Complete | Dataset styling and labels follow registered metadata rather than source-global arrays. | Persistent branch canvas | `TestRoadMapAllBranchesImport`, `TestRoadMapGUIInteractions` |
| Fixed/varying parameter filtering | `UpdateParameterValues`, `PopulateNonVaryingDropdowns`, `SelectDatasetFromParameter` | Workbench `parameterFilters`, named parameter schemas, branch dataset/filter controls | Qualified functional parity | Controls use named schema/provider metadata; exact source dropdown ordering is not a compatibility promise. | Workbench contribution + parameter-filter panel | `TestRoadMapGUIConstruction`, `TestRoadMapSelectionSynchronization` |
| Hover preview | `FigureWindowMoved`, `ResolveNearestCursorSelection`, `ShowBranchDataTip` | `BranchInteractionController`, schema-scaled nearest selection, transient `HoverSelection` | Complete | LMZ normalizes selection records and publishes presentation events. | Branch interaction controller | `TestRoadMapGUIInteractions.visibleThreeDimensionalHoverDoesNotLock`, `TestRoadMapSelectionSynchronization` |
| Locked point selection | `FigureWindowClicked`, `BranchLineClicked`, `ActivateDatasetSelection` | `BranchService.selectPoint`, locked controller selection, synchronized event bus | Complete | Lock state is controller-owned instead of nested GUI/global state. | Shared application state | `TestRoadMapSelectionSynchronization`, `TestPresentationEventBus` |
| State/timing/parameter inspection | Source seed tables and `FormatCursorInfoText` | Named decision/event/parameter/observable/residual/diagnostic/provenance tables | Complete and expanded | LMZ shows schema groups and immutable provenance beyond the source summary. | Info / Selection sidebar | `TestRoadMapGUIInteractions`, `TestScientificSectionCombinationControls` |
| Noise | `ApplySeedNoise`, `ApplyRandomization`, `FormatSeedNoiseStatus` | `SeedService.perturb`, controller `perturbWorkingSolution`, schema-scaled/absolute modes with recorded seed | Complete | Randomness is explicitly tied to a supplied seed/run context. | Solve / Seeds workspace | `TestAdvancedControllerWorkflows`, RoadMap GUI tests |
| Prediction | `BuildPredictedSeedCandidate`, `PlotPredictedSeedCandidate` | Generic second-seed predictor/corrector, overlay `prediction` layer | Complete | Prediction uses problem chart/scales and a generic typed solution rather than raw 29-row arrays. | Shared overlay controller | `TestRoadMapSeedContinuation.generatedSecondSeedFromRoadMap`, `TestQuadrupedReferenceWorkflowEndToEnd` |
| Root refinement | `SolvePredictedSeedCandidate`, `ProjectSeedGuessToSolution`; `SolveQuadrupedalZE` | `SolveService`, `FsolveSolver`, registered solve options, accepted-existing-seed route | Complete | Algorithms are service-owned; the default published point is accepted without an unnecessary numerical iteration. | Workflow session solve + progress contract | `TestFsolveSolver`, `TestSolveIterationEvents`, `TestQuadrupedReferenceWorkflowEndToEnd` |
| Solved-point overlay | `PlotSolvedSeedCandidate`, `RefreshSingleSeedCandidateMarker` | Shared overlay `corrected solution` layer on persistent branch axes | Complete | Marker appearance follows the active palette/profile. | `BranchOverlayController` | `TestWorkbenchPersistentBranchCanvas`, RoadMap GUI tests |
| First seed | `ResolveContinuationFirstSeed`, cursor/index/percentage/solver sources | Registered locked point 267; controller also supports locked/manual sources | Complete | The reference workflow makes the source and recommended index explicit in catalog data. | `SeedPreset` + workflow session | `TestQuadrupedWorkflowDescriptor`, `TestQuadrupedReferenceWorkflowEndToEnd` |
| Second seed | `SolveContinuationSecondSeed`, `FindContinuationSecondSeedAtStateRadius` | Adjacent next/previous or generated/corrected seed through `SeedService`/`WorkflowSession` | Complete | Generic chart distance replaces raw state-only indexing where topology requires it. | Registered seed preset | `TestRoadMapSeedContinuation`, `TestQuadrupedReferenceWorkflowEndToEnd` |
| Descending and ascending branch search | `NumericalContinuation1D_Quadruped_v2`: two-direction loop and direction flip; GUI `RunNumericalContinuation1D` | `PseudoArclengthContinuation` with `DirectionMode=forward|backward|both`; quadruped labels decreasing/increasing `dx` | Complete | The source labels velocity directions; LMZ registers coordinate-oriented labels and gives `MaximumPoints` total-result semantics. | Both-direction continuation | `TestQuadrupedReferenceWorkflowEndToEnd` verifies each direction and both signs |
| Live prediction/correction progress | Source `HandleGUIContinuationStatus`, `UpdateContinuationPreviewPredictor`, continuation callbacks | Typed solve snapshots plus continuation prediction/accepted/rejected callbacks and shared overlay layers | Complete | Progress is GUI-independent and serializable where appropriate; source nested callbacks are not reused. | Solve/continuation progress contracts | `TestSolveIterationEvents`, `TestStatusPanelProgress`, continuation callback regressions |
| Pause/stop | `ToggleContinuationPause`, `RequestContinuationStop`, `PollGUIContinuationControl` | `RunContext.Pause`, cancellation token, controlled-stop result with accepted-point preservation | Complete | Cooperative controls are shared by GUI and programmatic callers. | Existing run context retained | `TestRoadMapSeedContinuation.controlledStopPreservesPartialBranch`, `TestScientificCheckpointResume` |
| Temporary/checkpoint solution | Source `solution_temp.mat`, `SaveTemporarySolution`, final MAT output | Atomic native checkpoint artifacts, compatibility validation, resume from stored accepted history | Complete with intentional format change | LMZ does not promise the source temporary filename/structure; exact Results29 is a separate legacy export. | Native checkpoint/resume | `TestScientificCheckpointResume`, `TestQuadrupedReferenceWorkflowEndToEnd` |
| Parameter continuation | GUI `RunParameterVaryingContinuation`, `GUIParameterInterimSearch` | `ContinuationService.parameterHomotopy`, active schema parameters, registered homotopy preset | Complete | Inactive `phi_neutral` is rejected rather than presented as a dynamics-changing parameter. | Homotopy task panel | `TestActiveQuadrupedHomotopy`, `TestInactiveParameterHomotopyRejection` |
| Repeated branch scan | GUI `Run2DContinuationScan`; `NumericalContinuation2D_Quadruped_v2` | `ContinuationService.branchFamilyScan`, registered family-scan preset | Complete, terminology qualified | It repeats one-dimensional branches at parameter targets; it is not labeled a two-dimensional manifold solver. | Family scan task panel | `TestRoadMapSeedContinuation.namedHomotopyAndFamilyScan`, `TestHomotopyAndFamilyScan` |
| Visualization | `RunVisualization`, frame/trajectory/recording helpers | Model-owned renderer and plot providers, simulation/recording/export services, `research_legacy` profile | Complete with broader exports | Rendering is component/service based and shared with non-GUI runs; pixel identity is not claimed. | Visualization sidebar + central views | `TestQuadrupedVisualization`, `TestRoadMapRecordingSmoke`, graphics-fidelity tests |
| Oscillator interaction | `SyncOscillatorFromMainSelection`, `SelectOscillatorSolution`, playback/GIF helpers | Locked selection synchronizes oscillator index; model plot provider and recording service expose phase views | Complete | Detailed plots remain in the reusable visualization component; workbench placement differs. | Oscillator / Analysis panel | `TestQuadrupedVisualization`, `TestRoadMapSelectionSynchronization` |
| Status reporting | `SetStatus`, `FormatGUIContinuationStatus`, bottom status area | Always-visible `StatusDock`/`StatusPanel`, timestamped copyable history, stage/gauge/diagnostics | Complete and expanded | Status is event-driven and retained across layout/sidebar changes. | Persistent status/progress row | `TestStatusPanelProgress`, `TestSidebarSpansWorkspace` |

## Numerical non-regression boundary

The registered reference uses the same `periodic_apex` problem, unchanged
Results29 adapter, repository RoadMap hashes, and generic continuation engine
that were validated before Round 11. The canonical focused workflow verifies
point 267, initial residual, accepted solve, adjacent and generated pairs,
forward, backward, both-direction callbacks, checkpoint/resume, and artifact
round trip. It never calls `SLIP_Quadruped_GUI`,
`NumericalContinuation1D_Quadruped_v2`, or
`NumericalContinuation2D_Quadruped_v2` at runtime.

The source GUI and legacy algorithms remain valuable audit oracles, not runtime
dependencies. Layout correspondence is documented in
[quadruped-gui-layout-map.md](quadruped-gui-layout-map.md). Human visual
comparison remains unexecuted in the batch-only environment.

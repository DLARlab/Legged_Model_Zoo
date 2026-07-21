# Redistribution status

This record separates local scientific migration authorization from public
redistribution rights. A request to perform the migration is not a copyright
license. No open-source license is inferred where an upstream repository does
not contain an explicit grant.

## Release decision

Public packaging or release of the framework, copied scientific assets, and
adapted source code is **blocked pending written owner decisions**. The local
tree remains usable for development and scientific verification. Use
`REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md` to record an explicit grant,
replacement-data decision, or removal requirement before release.

| Material | Source owner | Source repository | Existing license / notice | User authorization recorded | Public redistribution status | Release action required |
|---|---|---|---|---|---|---|
| Framework, tutorials, documentation, tests, and release tooling | Project owner/authorized licensor is not identified by a signed record | `https://github.com/DLARlab/Legged_Model_Zoo.git` | No root `LICENSE` or owner-supplied redistribution grant is present | Yes—Rounds 1–10 request local implementation work; that is not a public copyright license | **Not authorized / pending owner review** | Obtain an owner-supplied project license or grant covering framework code, tutorials, documentation, tests, and tooling before retaining a public core archive |
| Quadruped source code | Repository owner/maintainer: DLARlab; copyright ownership is not stated in the repository | `https://github.com/DLARlab/SLIP_Model_Zoo.git`, commit `2c106101383ecee1b2a9d695efe09fbd72d5718a` | No `LICENSE`, `COPYING`, `NOTICE`, or redistribution grant found | Yes—Round 5 requested the local migration and adaptation | **Not authorized / pending owner review** | Obtain a written code redistribution and modification grant, including attribution and license text, or exclude adapted code from a public package |
| Quadruped RoadMap data and reference figures | Repository owner/maintainer: DLARlab; data copyright ownership is not stated | Same repository/commit; `SLIP_Quadruped/.../1_Roadmap` | No explicit data license or notice found | Yes—Round 5 explicitly requested copying the RoadMap for the local migration | **Not authorized / pending owner review** | Obtain a written data/figure redistribution grant defining permitted files and attribution, or replace/remove them from a public package |
| Biped source code and gait-map data | Repository owner/maintainer: DLARlab; individual copyright ownership is not stated | `https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git`, commit `4595146c5881a5313bc8fe92de85099193ef9be9` | `READMEDing2021JerboaFrontier.txt` states CC BY-NC 4.0; the checkout has no standalone `LICENSE`, `COPYING`, or `NOTICE` file clarifying the precise code/data scope | Yes—Round 6 requests scientific migration and copying of required branch assets | **Noncommercial notice recorded; packaging scope pending owner review** | Preserve CC BY-NC attribution/noncommercial terms and obtain written confirmation that the notice covers the adapted equations, regression fixtures, and gait branches before public packaging |
| Load-pulling source code and experimental/model data | Repository owner/maintainer: DLARlab; individual and experimental-data ownership is not stated | `https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git`, commit `19f3133073c988cc0c3424a647b4adbb60a90b99` | The upstream README claims BSD 3-Clause and links a license, but this commit contains no `LICENSE`, `COPYING`, or `NOTICE` file containing those terms | Yes—Round 6 requests scientific migration and repository-contained datasets | **License claim cannot be verified from the commit / pending owner review** | Obtain the authoritative BSD 3-Clause license file and confirmation that it covers code and experimental/model data, or obtain a separate written grant; otherwise exclude or replace the materials |

## Round 8 graphics-derived material

The release decision above also applies to source-derived research graphics,
not only dynamics code and copied MAT/FIG data.

| Graphics family | Local material covered | Pinned source authority | Current decision |
|---|---|---|---|
| SLIP quadruped | `ResearchBodyGeometry`, `ResearchLegGeometry`, `ResearchCOMGeometry`, `ResearchGroundGeometry`, `ResearchPhaseDiagramGeometry`, research visual constants/styles, graphics fixtures/fingerprints, and source-referenced comparison measurements | `https://github.com/DLARlab/SLIP_Model_Zoo.git`, commit `2c106101383ecee1b2a9d695efe09fbd72d5718a` | **Unresolved / not authorized for public redistribution.** Explicit-black defaults and the Round 8 axis-equal camera qualification do not create new rights. |
| SLIP biped | `ResearchBodyGeometry`, `ResearchCOGGeometry`, `ResearchLegGeometry`, `ResearchGroundGeometry`, research visual constants/styles, graphics fixtures, and source-referenced comparison measurements | `https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git`, commit `4595146c5881a5313bc8fe92de85099193ef9be9` | **CC BY-NC notice recorded; exact graphics/code/data scope remains unconfirmed.** Explicit-black default resolution does not expand the notice's scope. |
| Quadruped with load | `ResearchLoadGeometry`, `ResearchRopeGeometry`, load camera/style constants, shared quadruped research composition, stride-selection graphics evidence, fixtures, and source-referenced comparison measurements | Load-specific material: `https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git`, commit `19f3133073c988cc0c3424a647b4adbb60a90b99`; shared quadruped geometry: `https://github.com/DLARlab/SLIP_Model_Zoo.git`, commit `2c106101383ecee1b2a9d695efe09fbd72d5718a` | **Both source decisions remain pending.** The unverified BSD claim does not authorize the load material, and the reused quadruped geometry remains subject to its separate unresolved decision. |

Research geometry equations, source-faithful style constants, and numeric
fixtures/fingerprints inherit the applicable source decision. Local
high-contrast profiles retain that geometry/layer structure and are treated
conservatively as derivatives while authority is unresolved; native
`clean_generic` material is not represented as source graphics. Any locally
generated source, source-faithful target, or difference raster likewise
inherits the relevant pending decision and must not be published without the
required grant.

No Round 8 source or difference raster is committed. The files under
`docs/graphics-comparison/<model>/batch_metrics_r2025b_macos_arm64.json` are
non-raster measurement records: they contain scalar image metrics, image
dimensions/bounds, thresholds, environment metadata, and status flags, not
pixels or encoded image payloads. They explicitly record
`sourceImagesStored: false`, `differenceImagesStored: false`, and
`humanApproved: false`. Retaining numeric measurements for local validation
does not authorize redistribution of the underlying source render or convert
automated evidence into human approval.

## Decision controls

- Preserve source filenames, commit IDs, hashes, citations, and adaptation notes
  while review is pending.
- Do not describe any pending material as MIT, BSD, GPL, public domain, or
  otherwise openly licensed without an explicit owner-supplied grant.
- Derived native MAT artifacts and numerical baselines remain derived from the
  same upstream data and are covered by the same pending decision.
- Source-derived graphics providers/styles, geometry fixtures, and any local
  source/difference rasters remain covered by their pinned source decision;
  non-raster batch metrics do not override that decision.
- Re-run the release inventory after any owner decision so generated archives
  cannot include a disallowed source, fixture, cache, or screenshot.
- Update this record and `THIRD_PARTY_NOTICES.md` together when a decision is
  received.
- Both `core` and `scientific` final builders enforce these decisions. A
  temporary `technical-validation` package may be built only to test package
  mechanics; it is labeled `NOT_FOR_REDISTRIBUTION`, is not a permission
  override, and must not remain as a release artifact.
- The machine-readable per-file authority is
  `release/redistribution_manifest.json`; `scan_redistribution` rejects stale
  hashes, missing entries, unsafe paths, and derived artifacts whose recorded
  decision conflicts with their sources.

The closing Round 8 refresh contains 628 inventoried files with no structural,
stale-hash, missing, or unlisted finding. Both release profiles still stop on
the unresolved project decision, and all 613 files selected by the scientific
profile remain blocking. This larger, clean inventory is evidence that the
new graphics/configuration/tests/docs are classified; it does not change any
owner decision or authorize a package.

Status recorded: 2026-07-19. This is an engineering release gate, not legal
advice.

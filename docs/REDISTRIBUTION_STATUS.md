# Redistribution status

This record separates local scientific migration authorization from public
redistribution rights. A request to perform the migration is not a copyright
license. No open-source license is inferred where an upstream repository does
not contain an explicit grant.

## Release decision

Public packaging or release of the copied scientific assets and adapted source
code is **blocked pending a written owner decision**. The files remain in the
working migration because they are required for scientific verification. Use
`REDISTRIBUTION_OWNER_DECISION_TEMPLATE.md` to record an explicit grant,
replacement-data decision, or removal requirement before release.

| Material | Source owner | Source repository | Existing license / notice | User authorization recorded | Public redistribution status | Release action required |
|---|---|---|---|---|---|---|
| Quadruped source code | Repository owner/maintainer: DLARlab; copyright ownership is not stated in the repository | `https://github.com/DLARlab/SLIP_Model_Zoo.git`, commit `2c106101383ecee1b2a9d695efe09fbd72d5718a` | No `LICENSE`, `COPYING`, `NOTICE`, or redistribution grant found | Yes—Round 5 requested the local migration and adaptation | **Not authorized / pending owner review** | Obtain a written code redistribution and modification grant, including attribution and license text, or exclude adapted code from a public package |
| Quadruped RoadMap data and reference figures | Repository owner/maintainer: DLARlab; data copyright ownership is not stated | Same repository/commit; `SLIP_Quadruped/.../1_Roadmap` | No explicit data license or notice found | Yes—Round 5 explicitly requested copying the RoadMap for the local migration | **Not authorized / pending owner review** | Obtain a written data/figure redistribution grant defining permitted files and attribution, or replace/remove them from a public package |
| Biped source code and gait-map data | Repository owner/maintainer: DLARlab; individual copyright ownership is not stated | `https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions.git`, commit `4595146c5881a5313bc8fe92de85099193ef9be9` | `READMEDing2021JerboaFrontier.txt` states CC BY-NC 4.0; the checkout has no standalone `LICENSE`, `COPYING`, or `NOTICE` file clarifying the precise code/data scope | Yes—Round 6 requests scientific migration and copying of required branch assets | **Noncommercial notice recorded; packaging scope pending owner review** | Preserve CC BY-NC attribution/noncommercial terms and obtain written confirmation that the notice covers the adapted equations, regression fixtures, and gait branches before public packaging |
| Load-pulling source code and experimental/model data | Repository owner/maintainer: DLARlab; individual and experimental-data ownership is not stated | `https://github.com/DLARlab/2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights.git`, commit `19f3133073c988cc0c3424a647b4adbb60a90b99` | The upstream README claims BSD 3-Clause and links a license, but this commit contains no `LICENSE`, `COPYING`, or `NOTICE` file containing those terms | Yes—Round 6 requests scientific migration and repository-contained datasets | **License claim cannot be verified from the commit / pending owner review** | Obtain the authoritative BSD 3-Clause license file and confirmation that it covers code and experimental/model data, or obtain a separate written grant; otherwise exclude or replace the materials |

## Decision controls

- Preserve source filenames, commit IDs, hashes, citations, and adaptation notes
  while review is pending.
- Do not describe any pending material as MIT, BSD, GPL, public domain, or
  otherwise openly licensed without an explicit owner-supplied grant.
- Derived native MAT artifacts and numerical baselines remain derived from the
  same upstream data and are covered by the same pending decision.
- Re-run the release inventory after any owner decision so generated archives
  cannot include a disallowed source, fixture, cache, or screenshot.
- Update this record and `THIRD_PARTY_NOTICES.md` together when a decision is
  received.

Status recorded: 2026-07-19. This is an engineering release gate, not legal
advice.

# Source inventory

Inventory date: 2026-07-18. The local filesystem was authoritative. All sources remained read-only. The writable target was `/Users/nanyoujiayu/Documents/GitHub/Legged_Model_Zoo`; the brief's older target name `SLIP_Model_Zoo` was interpreted as the behavioral source because that sibling repository was outside the writable target and already populated.

| Source | Branch | Commit | Dirty | License observed | Role |
|---|---|---|---|---|---|
| `../SLIP_Model_Zoo` | main | `2c106101383ecee1b2a9d695efe09fbd72d5718a` | clean | no root license found; quadruped README does not state one | primary local GUI/quadruped behavior |
| `../2023_Breaking_Symmetry_Leads_to_Diverse_Gaits` | main | `6b7afba9b854abd481223aca3634a035d0e92841` | clean | README says BSD-3-Clause; referenced LICENSE was absent locally | quadruped search/continuation and saved branches |
| `../2022_A_Template_Model_Explains_Jerboa_Gait_Transitions` | main | `4595146c5881a5313bc8fe92de85099193ef9be9` | clean | dataset README states CC BY-NC 4.0; embedded MathWorks utility license also appears in related copies | jerboa/biped model, fitting and continuation |
| `../2025_Gait_Transitions_in_Load_Pulling_Quadrupeds_Insights` | main | `19f3133073c988cc0c3424a647b4adbb60a90b99` | clean | README says BSD-3-Clause; referenced LICENSE was absent locally | load model, 44+13 layout, objectives and GUIs |
| `../SLIP_Quadruped` | main | `818e503c2282d83b6df0a69bbd0b5e76af9f2f72` | clean | not found | supplementary quadruped copy |
| `../SLIP_Biped` | main | `be8164923236a1babdf1deb9a95531810c81a65b` | clean | MathWorks BSD-like, MathWorks-products-only condition | supplementary biped copy |
| `../SLIP_Jerboa` | main | `9b2b34c3ba684c40adc110eb3d2d64b6f91df061` | clean | BSD-3-Clause; some utilities carry MathWorks restricted license | supplementary jerboa copy |
| `../SLIP_SledDog` | main | `0fae0dfa917c5a043ca0f99e512344ceb949775e` | clean | not found | supplementary load-model copy |

The target had no commits and no pre-existing files or uncommitted changes. The discovery found all requested named entry points. Representative data include quadruped `PK_20_2.mat` and `BD1_20_2_*.mat`, jerboa `HP1.mat`, `SK1.mat`, `R1.mat`, and load-model `P3_*.mat`/`P4_*.mat`. Large and license-constrained datasets were not copied.

Legacy characteristics: scheduled event times; duplicate time rows around event resets; pervasive fixed-vector indexing; direct ODE45 integration; solver/graphics coupling in demos and GUIs; globals in load GUIs and objectives; normalized-index resampling in the load objective; direct `fsolve`, `fmincon`, `fminsearch`, `figure`, `pause`, `drawnow`, `pwd`, and path mutation. The new numerical core does not reproduce those side effects.

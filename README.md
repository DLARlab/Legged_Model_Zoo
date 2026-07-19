# Legged Model Zoo

Legged Model Zoo is a MATLAB framework for hybrid legged models, periodic-orbit problems, optimization, multi-start search, weighted pseudo-arclength continuation, visualization, persistence, and a programmatic GUI.

Run `startup`, then `lmz.gui.LeggedModelZooApp` to open the application. For a headless smoke test, run `examples/discover_and_simulate`. Run `tests/run_all_tests` from MATLAB to execute the test suite.

The numerical architecture separates physical models (`lmz.models`) from numerical problems (`lmz.problems`) and composes stateless/headless solver services. Model discovery is manifest-based under `assets/models`; adding a model does not require edits to registry or solver switch statements.

This repository contains clean-room adapters and framework code. It does not bundle the legacy research implementations or datasets. See `docs/migration/source_inventory.md` for source provenance and license constraints.

# GUI design

`LeggedModelZooApp` owns widget construction. `AppController` owns state transitions and calls services. `AppState` synchronizes datasets, selection, working solution, simulation, solve result, seed pair, continuation result, and optimization result.

Branch, Solution, Solve, Continuation, and Optimization tabs execute native workflows. The current UI is a compact vertical slice: full branch dataset styling, cell editing, file dialogs, pause/resume controls, rich diagnostics, and manual interactive visual review remain future work.

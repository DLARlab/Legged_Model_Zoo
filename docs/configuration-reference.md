# Configuration reference

## Plugin descriptor

`plugin.json` is required at an explicitly trusted external root.

| Field | Contract |
|---|---|
| `schemaVersion` | Currently `1.0.0` |
| `id` | Unique lowercase identifier |
| `version` | Semantic version |
| `namespace` | Isolated `lmzplugins.*` or `lmzmodels.<new-id>` prefix |
| `codeRoot` | Relative directory containing the package root |
| `catalogRoot` | Relative catalog directory |

Absolute paths, `.`/`..`, symlink escapes, all built-in model namespaces,
ambiguous class resolution, and implementations outside the registered code
root are rejected.

## Model manifest

Required fields are `schemaVersion`, `id`, `version`, `name`,
`implementationClass`, and `problems`. `capabilities` is accepted as a declared
summary, but runtime availability is derived from problem descriptors.
`implementationClass` is executable trusted code; no class name is accepted
from an unregistered external root.

## Problem descriptor

Required fields are:

```text
schemaVersion, id, kind, implementationId, implemented,
maturity, provenance, validationStatus, capabilities
```

Kinds are `simulation`, `nonlinear_equation`, and `optimization`. Capabilities
are logical scalars named `simulate`, `solve`, `continue`, `optimize`,
`visualize`, `animate`, and optionally `parameterHomotopy` and
`branchFamilyScan`. An unimplemented problem cannot advertise a capability.

## Variable specifications

`VariableSpec` supports `Label`, `LatexLabel`, `Group`, `Unit`, `Note`,
`DefaultValue`, `LowerBound`, `UpperBound`, `Scale`, `Topology`,
`PeriodSource`, and `Activity`. Topologies are `euclidean`, `positive`,
`bounded`, `angle`, and `cyclic_time`. Activities are `active`, `inactive`,
and `derived`.

## Hybrid simulator options

`HybridSimulator.simulate(system, request, context, options)` accepts:

| Option | Default | Meaning |
|---|---:|---|
| `RelativeTolerance` | `1e-9` | ODE relative tolerance |
| `AbsoluteTolerance` | `1e-11` | ODE absolute tolerance |
| `MaximumStep` | `0.02` | Maximum continuous-flow step |
| `DuplicateTimePolicy` | `post` | Keep final post-event public sample |

The request is a scalar struct with increasing `TimeSpan`, `Parameters`, and
model-defined declarative values such as `Decision`. Unknown options are
rejected.

## Solver and continuation configuration

`SolveService.solve` accepts either `SolverOptions` or its scalar-struct form.
`ContinuationService.run` accepts `ContinuationOptions` or a scalar struct.
Use schema scales and bounded point counts. Callback fields belong to trusted
run configuration and are stripped when reproducing persisted continuation
runs. Optimization options are translated through `lmz.compat.Optimization`.

## Scene configuration

Scene schema `1.0.0` declares `frames` and `primitives`. Supported primitives,
fields, aliases, and limits are listed in
[visualization-authoring.md](visualization-authoring.md). Bindings are simple
identifiers, never MATLAB expressions.

## Input limits

`SafeJson` defaults to 1 MiB, nesting depth 32, and 100,000 decoded items.
`SafeMat` defaults to 512 MiB, depth 64, and 20,000,000 aggregate elements.
MAT values are restricted to bounded numeric/logical/character/string/cell and
plain-struct data. Function handles and objects are rejected before application
use. MATLAB can deserialize a nested object during `load`, before the recursive
check runs, so intentionally hostile MAT serialization requires process
isolation; this loader is validation, not a sandbox.

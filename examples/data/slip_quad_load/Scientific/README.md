# Scientific SLIP quadruped-with-load datasets

This directory contains one source single-stride replication and one source
two-stride gait transition. `dataset_manifest.json` records their immutable
source paths, SHA-256 hashes, exact `44+13*(N-1)` dimensions, and native
artifact destinations.

The source 44-vector is grouped as 13 quadruped initial states, nine event
times, 14 quadruped parameters, two load states, and six load parameters.
Every later stride adds nine event times and four post-contact swing
stiffnesses. Runtime code uses `XAccumAdapter`; it does not index an unnamed
`extra13` block.

The audited source commit is
`19f3133073c988cc0c3424a647b4adbb60a90b99`. Its README claims a BSD
3-Clause license but the commit contains no license or notice file, so
redistribution remains subject to review and no license grant is inferred.

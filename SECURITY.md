# Security policy

## Supported release line

Security fixes are applied to the current `1.x` release-candidate line. Report
the affected version, MATLAB release/OS, minimal reproduction, and whether the
input came from a plugin, JSON, MAT file, archive, or GUI action. Do not include
private research data or credentials in a report.

## Trust model

External model plugins are native MATLAB code. Explicitly registering a plugin
means trusting it to execute arbitrary code with the MATLAB process's user
permissions. Review its source and dependencies first. Registry namespace and
resolved-path containment prevent accidental discovery/shadowing; they are not
a sandbox or malware defense.

Catalogs, scenes, built-in examples, legacy MAT files, and artifacts are data.
The project never evaluates JSON strings and never accepts scene expressions.
Safe loaders enforce canonical-root containment, bounded allocation/nesting,
expected variables/types/dimensions, and rejection of function handles and
objects before application use. A MATLAB MAT load can deserialize a nested
object before recursive validation observes and rejects it, so this boundary
does not make an intentionally hostile serialized object safe. Inspect an
unknown MAT file in an isolated process; do not bypass the project loaders or
treat them as a malware sandbox.

MATLAB's general `load`, `addpath`, Java access, system commands, and arbitrary
third-party classes are outside this data boundary. A malicious or vulnerable
MATLAB installation/toolbox is also outside the project threat model.

## Reporting

Until a private security channel is published by the repository owner, avoid
posting exploit payloads or sensitive paths publicly. Contact the verified
project maintainers through the repository's established private contact path,
or open a minimal GitHub security advisory when that feature is enabled. See
`SUPPORT.md` for non-security questions.

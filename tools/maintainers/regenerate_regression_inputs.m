function regenerate_regression_inputs
%REGENERATE_REGRESSION_INPUTS Maintainer-only historical fixture extraction.
% This utility intentionally requires immutable sibling migration sources.
error('lmz:Maintainers:MigrationSourcesRequired', ...
    ['Historical fixture regeneration is maintainer-only. Use the source ' ...
    'paths and hashes recorded in docs/baseline-fixtures.md.']);
end

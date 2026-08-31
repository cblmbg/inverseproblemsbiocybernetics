# MATLAB review bundle — 31 August 2026

This folder contains the full review and the MATLAB diagnostics used to reproduce its findings. The reviewed implementation is in the parent repository directory, at commit `62ee2e679c8bee7d83cf61899fbdd0d46bbf76df`.

## Contents

- [code_review.md](code_review.md): the complete prioritized review, source locations, numerical evidence, recommendations, limitations, and correction of the earlier README encoding observation.
- [reproduce_review.m](reproduce_review.m): the standalone runner, with all required helper functions embedded. No files from the original Codex workspace are needed.
- [review_execution_log.txt](review_execution_log.txt): captured MATLAB summary of the executed diagnostics.
- [review_evidence.mat](review_evidence.mat): the `reviewAudit` struct containing baseline results, supplied unit-test results, and diagnostic outputs.
- [helpers/reviewNumericalChecks.m](helpers/reviewNumericalChecks.m): original separate numerical-integration and quadrature probes.
- [helpers/reviewDiscoveryChecks.m](helpers/reviewDiscoveryChecks.m): original separate cross-validation and sparse-support probes.
- [helpers/reviewBestResponses.m](helpers/reviewBestResponses.m): original separate multistart unilateral-deviation probes.

The helper copies are included for inspection and optional separate use. The standalone runner already includes them as local functions, so they do not need to be added to the path.

## Run the review diagnostics

Set MATLAB's Current Folder to this folder, then run:

```matlab
audit = reproduce_review;
```

Requirements: MATLAB R2026a, Optimization Toolbox, Statistics and Machine Learning Toolbox, and Signal Processing Toolbox. The complete run took approximately one minute on the reviewed installation.

The runner executes the existing tests and the full case study with plotting and saving disabled, then runs diagnostic experiments. It restores the MATLAB search path and random-number-generator state. It does not modify the reviewed implementation or its saved results. The probes intentionally display the defective behavior; they are not regression tests that declare those behaviors correct.

To inspect the recorded evidence without rerunning:

```matlab
recorded = load('review_evidence.mat', 'reviewAudit');
audit = recorded.reviewAudit;
```

Source links in the full review point to the reviewed GitHub commit. The runner locates its parent repository automatically and accepts an explicit checkout path as an optional argument. It therefore works after cloning or moving the repository.

# Response to code review `code_review.md` — finding status

Branch `fix/review-cdx-31aug26` (Stages 1–4). All nine reproduced defects are
addressed in code. Environment: MATLAB 26.1.0.3234472 (R2026a) Update 1; Code
Analyzer 0 findings; unit tests 11/11. See `RESPONSE_PLAN.md` for the plan and
`RESPONSE_CHANGES.md` for the numeric deltas and per-stage verification.

| # | Sev | Finding | Stage | Status |
|---|-----|---------|-------|--------|
| 1 | P1 | Small damping can falsely certify Nash convergence | 1 | Fixed — certificate requires the unilateral-deviation check plus solver success; the damped-iterate change is a diagnostic only |
| 2 | P1 | Bound-active controls treated as interior stationary controls | 2 | Fixed (first pass) — bound-row fallback removed; interior rows pooled and identifiability reported by rank. KKT inequalities are the agreed follow-up |
| 3 | P1 | Failed forward solves used as demonstrations/validation | 1 | Fixed — solver success gated (exit flag + finite outputs); unverified runs report NaN errors and `status="unverified"` |
| 4 | P2 | Integrated discovery uses the wrong input convention at switches | 3 | Fixed — zero-order-held (left-held) integration of allocation candidates |
| 5 | P2 | Cross-validation splits overlapping windows / no independent prediction | 3 | Fixed — leave-one-experiment-out grouped CV; separate held-out experiments for prediction; R² labeled in-sample |
| 6 | P2 | Non-finite inputs silently become valid trajectories | 4 | Fixed — `mustBeFinite` on inputs; non-finite integration results rejected; RHS no longer masks NaN/Inf |
| 7 | P2 | Adaptive simulation violates its output-size contract for two times | 4 | Fixed — `deval` evaluation at the requested sample times |
| 8 | P2 | "Support recovered" true while spurious terms present | 3 | Fixed — exact-match support metric with false-positive and missed counts |
| 9 | P2 | Underdetermined objectives receive an infinite separation diagnostic | 2 | Fixed — padded singular spectrum; finite separation, rank, nullity, and identifiability reported |

## Verification-review responses (round 2)

A second review (`analysis_of_fixes_by_cdx/fix_branch_review.md`) checked the fix
branch and raised six items — three acceptance-criterion gaps, one incomplete
gate, and two regressions I had introduced. All six are now addressed on the
branch (unit tests 16/16, 0 analyzer findings, defaults unchanged):

| Ref | Item | Status |
|-----|------|--------|
| R1 | Nash certificate accepted infeasible profiles | Fixed — project the start onto the box; certificate requires the final profile to satisfy the bounds |
| R2 | `rank(A) ≥ n−1` overstated identification | Fixed — augmented-rank test `rank([A; 1']) == n` |
| R3 | Non-finite kinetic parameters masked | Fixed — `validateModelParameters` at both simulator entries |
| R4 | Failed demonstrations still entered inference | Fixed — Levels 3/4 assemble the inverse matrix from successful/verified demonstrations only |
| R5 | One experiment silently skipped cross-validation | Fixed — require ≥2 groups, else fixed fallback penalty with `crossValidated=false` |
| R6 | One-feature inverse crashed | Fixed — single-feature special case |

A third review of `2fa85bb` confirmed R1–R6 and raised two more, both now fixed:

| Ref | Item | Status |
|-----|------|--------|
| N1 | R1 projection masked non-finite starting controls | Fixed — reject non-finite start before projecting (`InverseLadder:NonFiniteControls`) |
| N2 | Augmented-rank wording overstated (sufficient, not necessary) | Fixed — comment qualified as a conservative criterion; behavior unchanged |

See `RESPONSE_CHANGES.md` (Round 2 and addendum) for before/after probe results.

## Not in this PR (agreed follow-ups)

- **Bound handling, full solution (finding 2):** add the bound-gradient (KKT)
  inequalities so bound-active demonstrations contribute correct information,
  beyond the current interior-row-pooling first pass.
- **Stage 5 — manuscript reassessment (review's "Additional limitations"):**
  numerical-refinement study (RK4 substeps 4→8→16→64), propagation of
  Level 1 kinetic-parameter error into Levels 3–4, and restating upper-level
  results as local, numerical equilibrium evidence and Level 2 R² as in-sample.

## Note on results

Levels 1, 3, and 4 default metrics are unchanged; the only default-run changes
are explicit `status`/`identifiable` reporting. Level 2 numbers changed by
design (corrected quadrature and cross-validation): in-sample R² [0.957, 0.942],
held-out prediction R² [0.943, 0.962], and exact support recovery is now `false`
because strain 2 remains structurally ambiguous — the intended Level 2 lesson,
now honestly quantified.

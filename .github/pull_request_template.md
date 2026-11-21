## Task

Task id and one-line intent. Link the spec or plan that authorised it.

- Task: `T-0xx`
- Branch: `phase-x/t0xx-slug`
- Spec / plan: `docs/...`

## What changed

Bullet the mechanism, not the file list. Say what a reader would otherwise have
to infer from the diff.

## Validation

Fill in real numbers from real runs — an unstated level is an unverified level.

| Level | Command | Result |
|---|---|---|
| L1 static | `godot --headless --path . --check-only --script res://<file>.gd` | exit |
| L2 runtime | `node tools/run_tests.mjs` | `n/25 suites green` |
| L2 regression | `node tools/run_evidence.mjs` | `runs= negatives= failures=` |
| L3 visual | capture scene + screenshots actually viewed | paths |
| L4 playtest | human session, or `Not Run` | brief |

Negative control: state which check was expected to go red and confirm it went
red for that reason. A first-run green from a new harness is unproven until a
known-bad fixture turns it red.

## Record

- [ ] `docs/STATE.md` updated with the outcome and the numbers
- [ ] `docs/DECISIONS.md` entry added for any parameter, waiver, or gate change
- [ ] `assets/ASSET_LOG.md` entry added for any new asset (origin, tool, licence)
- [ ] No unrelated fix bundled in — out-of-scope bugs went to Known Issues

## Risk

What breaks if this merges, and how to roll it back.

import { spawnSync } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Grades E1-E5 of docs/phase-c/OPERATIONAL_DEFINITIONS.md section 5 in one
// command: every positive harness plus the negative control that must go red
// for a named evidence id. --selftest adds an expectation that cannot be met,
// so a green report is proof the grader itself is capable of saying red.

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const GODOT = process.env.GODOT
	?? 'C:\\Users\\My Lenovo\\Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64.exe';
const OUT_DIR = path.join(ROOT, 'docs', 'phase-c', 'evidence', 't023');
const TIMEOUT_MS = 900_000;

const POSITIVE = [
	{ name: 't018_cycles', scene: 'run_t018_cycles' },
	{ name: 't019_swarm', scene: 'run_t019_swarm' },
	{ name: 't020_ranged', scene: 'run_t020_ranged' },
	{ name: 't021_boss', scene: 'run_t021_boss' },
	{ name: 't022_reward', scene: 'run_t022_reward' },
	{ name: 't023_onehit', scene: 'run_t023_onehit' },
	{ name: 't023_flow', scene: 'run_t023_flow' },
];

// proves: the section 5 item that consists of the negative control itself.
const NEGATIVE = [
	{ name: 't018_cycles', expect: ['flow.reset_state'] },
	{ name: 't019_swarm', expect: ['E1.1'] },
	{ name: 't023_onehit', expect: ['E1.3', 'E1.4'], proves: 'E1.4' },
	{ name: 't020_ranged', expect: ['E2.1'], proves: 'E2.4' },
	{ name: 't021_boss', expect: ['E3.2'], proves: 'E3.5' },
	{ name: 't022_reward', expect: ['E4.2'], proves: 'E4.4' },
	{ name: 't023_flow', expect: ['E5.1', 'E5.2'], proves: 'E5.4' },
];

const SELFTEST_ENTRY = {
	name: 't023_onehit',
	expect: ['E9.9'],
	selftest: true,
	note: 'expectation that cannot be met - must be reported red',
};

const REQUIRED_IDS = [
	'E1.1', 'E1.2', 'E1.3', 'E1.4',
	'E2.1', 'E2.2', 'E2.3',
	'E3.1', 'E3.2', 'E3.3', 'E3.4',
	'E4.1', 'E4.2', 'E4.3',
	'E5.1', 'E5.2', 'E5.3',
];

function sceneArgs(scene, negative) {
	const args = ['--headless', '--path', '.', `res://scenes/phase_c/${scene}.tscn`, '--fixed-fps', '60'];
	if (negative) args.push('--', 'negative');
	return args;
}

function execute(scene, negative) {
	const started = Date.now();
	const result = spawnSync(GODOT, sceneArgs(scene, negative), {
		cwd: ROOT,
		encoding: 'utf8',
		timeout: TIMEOUT_MS,
		maxBuffer: 128 * 1024 * 1024,
	});
	const stdout = result.stdout ?? '';
	const stderr = result.stderr ?? '';
	const checks = [];
	for (const line of stdout.split(/\r?\n/)) {
		if (line.startsWith('CHECK PASS ') || line.startsWith('CHECK FAIL ')) {
			const label = line.slice(11);
			checks.push({ ok: line[6] === 'P', id: label.split(' ')[0], label });
		}
	}
	const summaryLine = stdout.split(/\r?\n/).filter((line) => line.includes('failures=')).pop() ?? '';
	return {
		exit: result.status,
		timedOut: result.error !== undefined && result.error.code === 'ETIMEDOUT',
		scriptErrors: (stderr.match(/SCRIPT ERROR/g) ?? []).length,
		checks,
		summary: summaryLine.trim(),
		seconds: Math.round((Date.now() - started) / 1000),
		command: `"${GODOT}" ${sceneArgs(scene, negative).join(' ')}`,
	};
}

function gradePositive(run) {
	if (run.timedOut) return { ok: false, reason: `timeout after ${TIMEOUT_MS / 1000}s` };
	if (run.scriptErrors > 0) return { ok: false, reason: `${run.scriptErrors} SCRIPT ERROR (harness, not evidence)` };
	const failed = run.checks.filter((check) => !check.ok);
	if (run.exit !== 0) return { ok: false, reason: `exit ${run.exit}: ${failed.map((check) => check.label).join(' | ') || 'no CHECK FAIL line'}` };
	if (failed.length > 0) return { ok: false, reason: failed.map((check) => check.label).join(' | ') };
	// t018/t019 report counters instead of a failures= field; for them the exit
	// code plus zero CHECK FAIL lines is the contract.
	if (run.summary.includes('failures=') && !run.summary.includes('failures=0')) {
		return { ok: false, reason: `summary says ${run.summary}` };
	}
	return { ok: true, reason: `${run.checks.length} checks` };
}

function gradeNegative(run, expected) {
	if (run.timedOut) return { ok: false, reason: 'timeout' };
	if (run.scriptErrors > 0) return { ok: false, reason: `${run.scriptErrors} SCRIPT ERROR (harness, not evidence)` };
	const failedIds = run.checks.filter((check) => !check.ok).map((check) => check.id);
	if (run.exit !== 1) return { ok: false, reason: `negative control exited ${run.exit}, expected 1` };
	const missing = expected.filter((id) => !failedIds.some((seen) => seen.startsWith(id)));
	if (missing.length > 0) {
		return { ok: false, reason: `did not fail as named (missing ${missing.join(', ')}; red: ${failedIds.join(', ') || 'none'})` };
	}
	return { ok: true, reason: `red on ${failedIds.join(', ')}` };
}

const selftest = process.argv.includes('--selftest');
const negativePlan = selftest ? [...NEGATIVE, SELFTEST_ENTRY] : [...NEGATIVE];
const evidence = {};
const report = { generatedBy: 'tools/run_evidence.mjs', selftest, positive: [], negative: [], failures: [] };
const startedAll = Date.now();

for (const entry of POSITIVE) {
	const run = execute(entry.scene, false);
	const verdict = gradePositive(run);
	report.positive.push({ name: entry.name, ...verdict, checks: run.checks.length, summary: run.summary, seconds: run.seconds });
	if (!verdict.ok) report.failures.push(`positive ${entry.name}: ${verdict.reason}`);
	for (const check of run.checks) {
		if (!/^E\d\.\d/.test(check.id)) continue;
		const seen = evidence[check.id];
		if (!seen || seen.ok) evidence[check.id] = { ok: check.ok, label: check.label, source: entry.name };
	}
}

for (const entry of negativePlan) {
	const scene = POSITIVE.find((candidate) => candidate.name === entry.name).scene;
	const run = execute(scene, true);
	const graded = gradeNegative(run, entry.expect);
	// The selftest entry is expected to be reported red: that is the fixture
	// proving this grader bites, so its own verdict flips only for it.
	const ok = entry.selftest ? !graded.ok : graded.ok;
	const reason = entry.selftest
		? (ok ? `known-bad expectation rejected as designed (${graded.reason})` : 'grader accepted an impossible expectation')
		: graded.reason;
	report.negative.push({ name: entry.name, expect: entry.expect, proves: entry.proves ?? null, ok, reason, seconds: run.seconds });
	if (!ok) report.failures.push(`negative ${entry.name}: ${reason}`);
}

for (const id of REQUIRED_IDS) {
	if (!evidence[id]) {
		report.failures.push(`evidence ${id} never checked`);
		evidence[id] = { ok: false, label: 'no harness reported this id', source: '-' };
	}
}

const seconds = Math.round((Date.now() - startedAll) / 1000);
const verdict = report.failures.length === 0 ? 'E1-E5 PASSED' : 'E1-E5 FAILED';

const rows = REQUIRED_IDS.map((id) => {
	const entry = evidence[id];
	return `| ${id} | ${entry.ok ? 'Passed' : 'Failed'} | ${entry.source} | \`${entry.label}\` |`;
}).join('\n');
const negativeRows = report.negative.map((entry) => `| ${entry.proves ?? '(support)'} | ${entry.name} | ${entry.expect.join(', ')} | ${entry.ok ? 'worked' : 'BROKEN'} | ${entry.reason} |`).join('\n');
const positiveRows = report.positive.map((entry) => `| ${entry.name} | ${entry.ok ? 'Passed' : 'Failed'} | ${entry.checks} | ${entry.summary} | ${entry.seconds}s | ${entry.ok ? '' : entry.reason} |`).join('\n');

mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(path.join(OUT_DIR, 'evidence_report.json'), JSON.stringify({ verdict, seconds, evidence, report }, null, 2) + '\n');
writeFileSync(path.join(OUT_DIR, 'evidence_report.md'), `# E1-E5 evidence report

Generated by \`node tools/run_evidence.mjs\` — do not hand-edit; rerun instead.
Mode: ${selftest ? 'selftest (includes a known-bad expectation)' : 'gate'} · total ${seconds}s · Godot 4.7.2 headless, --fixed-fps 60.

## Verdict: ${verdict}

${report.failures.length === 0 ? '' : 'Failures:\n\n' + report.failures.map((line) => `- ${line}`).join('\n') + '\n'}

## Evidence ids (OPERATIONAL_DEFINITIONS.md section 5)

| id | status | harness | check label |
|---|---|---|---|
${rows}

E2.4 / E3.5 / E4.4 / E5.4 and the E1.4 half that consists of a negative
control are graded in the next table.

## Negative controls (each must exit 1 and fail the named id)

| proves | harness | expected red | status | detail |
|---|---|---|---|---|
${negativeRows}

## Positive harness runs

| harness | status | checks | counters | time | note |
|---|---|---|---|---|---|
${positiveRows}
`);

console.log(`EVIDENCE ${verdict.toLowerCase()} runs=${report.positive.length} negatives=${report.negative.length} ids=${REQUIRED_IDS.length} failures=${report.failures.length} seconds=${seconds}`);
for (const line of report.failures) console.log(`  - ${line}`);
console.log(`report: ${path.relative(ROOT, path.join(OUT_DIR, 'evidence_report.md'))}`);
process.exit(report.failures.length === 0 ? 0 : 1);

import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Runs every headless suite under tests/ in one command, which is what CI does.
// A suite is green only when it exits 0, logs no SCRIPT ERROR and prints its own
// `PASS <name>: N checks` verdict: a headless run can report success while
// GDScript failed to load, and silence is not a pass. Passing a substring runs
// one suite only, for iteration.

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const GODOT = process.env.GODOT
	?? 'C:\\Users\\My Lenovo\\Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64.exe';
const TIMEOUT_MS = 180_000;

const filter = process.argv.slice(2).find((arg) => !arg.startsWith('-')) ?? '';
const all = readdirSync(path.join(ROOT, 'tests'))
	.filter((name) => name.startsWith('test_') && name.endsWith('.gd'))
	.sort();
const suites = filter ? all.filter((name) => name.includes(filter)) : all;

if (suites.length === 0) {
	console.log(`no suite matches "${filter}" (${all.length} suites available)`);
	process.exit(1);
}

function verdict(stdout) {
	return stdout.split(/\r?\n/).filter((line) => /^(PASS|FAIL)\s/.test(line)).pop() ?? '';
}

// Suites report in several shapes (`PASS name: 23 checks`, a `checks=N
// failures=0` line, `TEST PASS: name`, `NAME TEST PASS`), so the gate is the
// exit code plus the presence of a PASS and the absence of any FAIL, not a
// regex over one format. The check count is best-effort reporting.
function measure(stdout) {
	const lines = stdout.split(/\r?\n/);
	const summary = lines.filter((each) => each.includes('failures=')).pop() ?? '';
	const inline = verdict(stdout).match(/: (\d+) checks/)?.[1] ?? summary.match(/checks=(\d+)/)?.[1] ?? '';
	return {
		line: verdict(stdout),
		checks: inline === '' ? '-' : inline,
		hasPass: lines.some((each) => /\bPASS\b/.test(each)),
		failLine: lines.filter((each) => /\bFAIL\b/.test(each)).pop() ?? '',
	};
}

const started = Date.now();
let red = 0;
for (const name of suites) {
	const args = ['--headless', '--path', '.', '-s', `res://tests/${name}`];
	const runStarted = Date.now();
	const run = spawnSync(GODOT, args, {
		cwd: ROOT,
		encoding: 'utf8',
		timeout: TIMEOUT_MS,
		maxBuffer: 64 * 1024 * 1024,
	});
	const stdout = run.stdout ?? '';
	const stderr = run.stderr ?? '';
	const seconds = ((Date.now() - runStarted) / 1000).toFixed(1);
	const scriptErrors = (stderr.match(/SCRIPT ERROR/g) ?? []).length;
	const { line, checks, hasPass, failLine } = measure(stdout);
	let reason = '';
	if (run.error && run.error.code === 'ETIMEDOUT') reason = `timeout after ${TIMEOUT_MS / 1000}s`;
	else if (scriptErrors > 0) reason = `${scriptErrors} SCRIPT ERROR in stderr`;
	else if (failLine !== '') reason = failLine.trim();
	else if (run.status !== 0) reason = `exit ${run.status} · ${line || 'no verdict line'}`;
	else if (!hasPass) reason = 'no PASS line: silence is not a pass';
	if (reason) red += 1;
	console.log(`${reason ? 'FAIL' : 'PASS'} ${name.slice(0, -3).padEnd(32)} ${String(checks).padStart(4)} checks ${seconds}s${reason ? ` · ${reason}` : ''}`);
	if (reason) console.log(stdout.trim().split(/\r?\n/).slice(-10).map((each) => `      ${each}`).join('\n'));
}

const total = suites.length;
console.log(`${total - red}/${total} suites green · ${Math.round((Date.now() - started) / 1000)}s · ${GODOT}`);
process.exit(red === 0 ? 0 : 1);

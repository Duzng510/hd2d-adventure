import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import path from 'node:path';

// T-032 A/B: does the tempo tell change how the player spends the tempo cost?
// One launch per arm, RUNS runs per launch (R resets between them). The log is
// truncated at every launch, so each arm's artifacts are copied out the moment
// its window closes - nothing else keeps the two arms from overwriting each other.
//
//   node tools/l4_ab.mjs              # arm A (tell on) then arm B (tell off)
//   node tools/l4_ab.mjs --arm B      # one arm only, e.g. to repeat or reverse order
//   node tools/l4_ab.mjs --score      # only re-score what is already on disk

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const GODOT = process.env.GODOT
	?? 'C:\\Users\\My Lenovo\\Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64.exe';
const OUT_DIR = path.join(ROOT, 'docs', 'phase-d', 'evidence', 't032', 'ab');
const USER_DIR = path.join(
	process.env.APPDATA ?? path.join(os.homedir(), 'AppData', 'Roaming'),
	'Godot', 'app_userdata', 'hd2d-adventure',
);
const RUNS = 5;
const ARMS = {
	A: { scene: 'res://scenes/phase_c/play_arena.tscn', label: 'tell ON' },
	B: { scene: 'res://scenes/phase_c/play_arena_notell.tscn', label: 'tell OFF' },
};

const argv = process.argv.slice(2);
const scoreOnly = argv.includes('--score');
const only = argv.includes('--arm') ? argv[argv.indexOf('--arm') + 1] : null;
if (only !== null && ARMS[only] === undefined) {
	console.log(`unknown arm '${only}' (have: ${Object.keys(ARMS).join(', ')})`);
	process.exit(1);
}
const arms = only !== null ? [only] : Object.keys(ARMS);

function collect(arm) {
	const dir = path.join(OUT_DIR, arm);
	mkdirSync(dir, { recursive: true });
	const wanted = readdirSync(USER_DIR).filter((name) => /^(combat_log\.csv|l4_probe\.csv|l4_death_\d+\.png)$/.test(name));
	for (const name of wanted) copyFileSync(path.join(USER_DIR, name), path.join(dir, name));
	if (!wanted.includes('combat_log.csv')) {
		console.log(`arm ${arm}: no combat_log.csv in ${USER_DIR} - the session never wrote a log?`);
		return null;
	}
	return dir;
}

function measure(arm) {
	const dir = path.join(OUT_DIR, arm);
	if (!existsSync(path.join(dir, 'combat_log.csv'))) return null;
	const run = spawnSync('node', [path.join(ROOT, 'tools', 'score_l4.mjs'), path.join(dir, 'combat_log.csv'), '--runs', String(RUNS)], { encoding: 'utf8' });
	const line = (run.stdout ?? '').split(/\r?\n/).find((text) => text.startsWith('L4 source='));
	if (line === undefined) {
		console.log(`arm ${arm}: scorer printed no summary line\n${run.stdout ?? ''}${run.stderr ?? ''}`);
		return null;
	}
	const fields = Object.fromEntries(line.split(/\s+/).slice(1).map((pair) => pair.split('=')));
	return { ...fields, swings: line.match(/swings=(\d+)/)?.[1] ?? '-' };
}

if (!scoreOnly) {
	for (const arm of arms) {
		console.log(`\n=== arm ${arm} (${ARMS[arm].label}) - play ${RUNS} runs, then close the window ===`);
		console.log('    same brief as always: WASD, mouse aim, LMB attack, Space dodge, R reset.');
		console.log('    nothing is asked of you about the ring; the log answers that.');
		const result = spawnSync(GODOT, ['--path', '.', ARMS[arm].scene], { cwd: ROOT, stdio: 'inherit' });
		if (result.error) {
			console.log(`arm ${arm} could not start: ${result.error.message}`);
			process.exit(1);
		}
		collect(arm);
	}
}

const rows = arms.map((arm) => ({ arm, label: ARMS[arm].label, data: measure(arm) }));
const missing = rows.filter((row) => row.data === null).map((row) => row.arm);
if (missing.length > 0) {
	console.log(`\nno measurement for arm(s) ${missing.join(', ')} - run \`node tools/l4_ab.mjs --arm ${missing[0]}\``);
}
const keys = [['valid', 'valid runs'], ['wins', 'wins'], ['tempoPaid', 'swings that paid a tier'],
	['tempoCeiling', 'swings sitting on the ceiling'], ['tempoDanger', 'telegraph open: paid dodge vs other dodge']];
console.log('\n# T-032 A/B - the tell is the only difference between arms');
console.log(`| measurement | ${rows.map((row) => `${row.arm} (${row.label})`).join(' | ')} |`);
console.log('|---|' + rows.map(() => '---|').join(''));
for (const [key, name] of keys) {
	console.log(`| ${name} | ${rows.map((row) => row.data?.[key] ?? '-').join(' | ')} |`);
}
console.log(`
Read the last row as the discriminator: a paid-tier dodge taken while no boss
window is open is a pay-back, not an escape. If A and B land on the same numbers
the tell moved nothing, and that is the result - not a missing one. Order here is
${arms.join(' then ')}; a learning effect runs the same direction in both arms only
if the gap survives, so a borderline split is worth repeating with --arm reversed.`);

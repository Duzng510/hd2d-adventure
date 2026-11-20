import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import os from 'node:os';

// Scores one L4 session log (user://combat_log.csv) against the machine-observable
// half of docs/phase-c/OPERATIONAL_DEFINITIONS.md sections 2-4: run validity (C1.1),
// per-run result / wave / duration (C1.2), the reset chain (C3.2) and the invariants
// a live session can still break (hit/damage pairing, telegraph floor, wave order,
// one phase flip, reward only on a win). Readability, fairness, "hits I understood"
// and fun stay user-reported (MP 5.3): this tool measures, it never grades feel.
//
//   node tools/score_l4.mjs <combat_log.csv> [--runs 10] [--engine-log <godot.log>] [--save]
//   node tools/score_l4.mjs --selftest [case]   # every case must go red for its named reason

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT_DIR = path.join(ROOT, 'docs', 'phase-c', 'evidence', 't024');
const HEADER = 'frame,entity,event,attack_id,target_id,value';
const TELEGRAPH_FLOOR = 18; // GDD 6.8 floor, the same floor E1.2 / E2.2 / E3.3 measure
const PLAYER_ID = 2;
const TICKS_PER_SECOND = 60;

function parseCsv(text) {
	const lines = text.replace(/\r\n?/g, '\n').split('\n').filter((line) => line.trim() !== '');
	const problems = [];
	if (lines.length === 0) return { events: [], problems: ['empty log file'] };
	const hasHeader = lines[0].startsWith(HEADER);
	if (!hasHeader) problems.push(`line 1 is not the log header: "${lines[0]}"`);
	const body = hasHeader ? lines.slice(1) : lines;
	const events = [];
	for (let index = 0; index < body.length; index += 1) {
		const cols = body[index].split(',');
		const numbers = [cols[0], cols[3], cols[4], cols[5]].map(Number);
		if (cols.length !== 6 || cols[1] === '' || cols[2] === '' || numbers.some((value) => !Number.isInteger(value))) {
			problems.push(`line ${index + 2} is not a log row: "${body[index]}"`);
			continue;
		}
		events.push({
			frame: numbers[0], entity: cols[1], event: cols[2],
			attackId: numbers[1], targetId: numbers[2], value: numbers[3],
		});
	}
	// A copy taken from the wrong launch (or truncated by reopening Godot) still
	// parses, so the census of event names is what catches it.
	for (const required of ['wave_start', 'damage', 'encounter_reset']) {
		if (!events.some((event) => event.event === required)) problems.push(`no '${required}' rows - wrong build, or the CSV was overwritten before it was copied?`);
	}
	if (!events.some((event) => event.event === 'wave_start' && event.value === 1)) problems.push("no 'wave_start value=1' row - no wave-1 run start in this log");
	if (!events.some((event) => event.event === 'encounter_win' || event.event === 'encounter_lose')) problems.push('no encounter_win/encounter_lose row - this session never finished a run');
	return { events, problems };
}

function segment(events) {
	const runs = [];
	let current = null;
	let pendingReset = false;
	for (const event of events) {
		if (event.event === 'wave_start' && event.value === 1) {
			current = {
				index: runs.length + 1, startFrame: event.frame, endFrame: null, result: null,
				waves: [1], resetBefore: pendingReset || runs.length === 0, resetAfter: false,
				hitsTaken: 0, damageTaken: 0, damageByEnemy: {},
				hitsDealt: 0, damageDealt: 0, swings: 0, dodges: 0, deaths: {}, projectileFires: 0,
				rewards: 0, heals: 0, healAmount: 0, bossPhases: [], hitRows: 0, damageRows: 0,
				wave3Frame: null, bossDamageDealt: 0,
				openings: [],
			};
			runs.push(current);
			pendingReset = false;
			continue;
		}
		if (current === null) continue; // pre-trigger idle before the first run, and events after the last reset
		if (event.event === 'wave_start') {
			current.waves.push(event.value);
			if (event.value === 3) current.wave3Frame = event.frame; // wave 3 is the boss alone
		}
		else if (event.event === 'encounter_win' || event.event === 'encounter_lose') {
			current.result = event.event === 'encounter_win' ? 'W' : 'L';
			current.endFrame = event.frame;
		} else if (event.event === 'encounter_reset') {
			current.resetAfter = true;
			current = null;
			pendingReset = true;
		} else if (event.event === 'damage' && event.targetId === PLAYER_ID) {
			current.damageRows += 1;
			current.hitsTaken += 1;
			current.damageTaken += event.value;
			current.damageByEnemy[event.entity] = (current.damageByEnemy[event.entity] ?? 0) + event.value;
		} else if (event.event === 'damage' && event.entity === 'player') {
			current.damageRows += 1;
			current.hitsDealt += 1;
			current.damageDealt += event.value;
			if (current.wave3Frame !== null) current.bossDamageDealt += event.value;
		} else if (event.event === 'hit' || event.event === 'projectile_hit') {
			current.hitRows += 1;
		} else if (event.event === 'action_start' && event.entity === 'player') current.swings += 1;
		else if (event.event === 'input_dodge') current.dodges += 1;
		else if (event.event === 'death') current.deaths[event.entity] = (current.deaths[event.entity] ?? 0) + 1;
		else if (event.event === 'projectile_fire') current.projectileFires += 1;
		else if (event.event === 'reward_granted') current.rewards += 1;
		else if (event.event === 'heal') { current.heals += 1; current.healAmount += event.value; }
		else if (event.event === 'boss_phase') current.bossPhases.push(event.value);
		else if (event.event === 'telegraph_start' || event.event === 'active_start') current.openings.push(event);
	}
	return runs;
}

function validate(runs) {
	const problems = [];
	for (const run of runs) {
		if (!run.resetBefore) problems.push(`run ${run.index}: no encounter_reset before wave 1 - did not start from the standard state`);
		if (run.result === null) problems.push(`run ${run.index}: abandoned - no encounter_win/encounter_lose before the next reset`);
		if (!run.resetAfter) problems.push(`run ${run.index}: no encounter_reset after the run ended`);
		const ordered = run.waves.map((_, index) => index + 1);
		if (run.waves.join() !== ordered.join()) problems.push(`run ${run.index}: wave order ${run.waves.join('>')} (expected ${ordered.join('>')})`);
		if (run.result === 'W' && run.waves.length !== 3) problems.push(`run ${run.index}: win without clearing wave 3 (waves ${run.waves.join('>')})`);
		if (run.result === 'W' && run.rewards !== 1) problems.push(`run ${run.index}: win logged reward_granted ${run.rewards} times (expected exactly 1)`);
		if (run.result === 'L' && run.rewards !== 0) problems.push(`run ${run.index}: loss logged reward_granted ${run.rewards} times`);
		if (run.bossPhases.length > 1) problems.push(`run ${run.index}: boss_phase logged ${run.bossPhases.length} times (expected at most 1)`);
		if (run.bossPhases.some((phase) => phase !== 2)) problems.push(`run ${run.index}: boss_phase value ${run.bossPhases.join(',')} (expected 2)`);
		// attack_id is per enemy instance, so a live multi-enemy CSV cannot prove
		// one-hit-per-swing - E1.3/E1.4 do that on a frozen single-role stage.
		// What this log can prove is that every hit settled exactly one damage row.
		if (run.damageRows !== run.hitRows) problems.push(`run ${run.index}: ${run.damageRows} damage rows vs ${run.hitRows} hit rows (a hit without damage, or a damage row without a hit)`);
		const byAttack = new Map();
		for (const open of run.openings) {
			const key = `${open.entity}#${open.attackId}`;
			byAttack.set(key, (byAttack.get(key) ?? []).concat(open));
		}
		// attack_id is per enemy instance, so three swarms all own "#1" and their rows
		// interleave: only a role that appears once per run can be measured here. That
		// is the boss; the per-role floors belong to E1.2 / E2.2 / E3.3 on the frozen
		// single-role stage.
		let bossLeads = null;
		for (const [key, seen] of byAttack) {
			if (!key.startsWith('boss#')) continue;
			if (seen.length === 1 && seen[0].event === 'telegraph_start') continue; // run ended inside the telegraph
			if (seen.length !== 2 || seen[0].event !== 'telegraph_start' || seen[1].event !== 'active_start') {
				problems.push(`run ${run.index}: boss attack ${key} opened with ${seen.map((item) => item.event).join(',')} (expected telegraph_start then active_start)`);
				continue;
			}
			const lead = seen[1].frame - seen[0].frame;
			bossLeads = bossLeads === null ? lead : Math.min(bossLeads, lead);
			if (lead < TELEGRAPH_FLOOR) problems.push(`run ${run.index}: attack ${key} telegraph lead ${lead} < ${TELEGRAPH_FLOOR}`);
		}
		run.minBossTelegraph = bossLeads;
	}
	return problems;
}

// Godot rotates every launch into godot<timestamp>.log beside godot.log, so one
// playtest can span several files with the same prefix.
function engineLog(entries) {
	const out = { files: [], scriptErrors: 0 };
	for (const entry of entries) {
		const resolved = path.resolve(entry);
		let names = [path.basename(resolved)];
		try {
			const prefix = path.basename(resolved).split('.')[0];
			names = readdirSync(path.dirname(resolved)).filter((name) => name.endsWith('.log') && name.startsWith(prefix)).sort();
		} catch {
			// directory unreadable: score only the file named on the command line
		}
		for (const name of names) {
			const file = path.join(path.dirname(resolved), name);
			let text = '';
			try {
				text = readFileSync(file, 'utf8');
			} catch {
				continue;
			}
			const count = (text.match(/SCRIPT ERROR/g) ?? []).length;
			out.files.push({ file: file.replace(/\\/g, '/'), scriptErrors: count });
			out.scriptErrors += count;
		}
	}
	return out;
}

function buildReport(source, events, runs, problems, engine, expectedRuns) {
	const valid = runs.filter((run) => run.resetBefore && run.resetAfter && run.result !== null);
	const wins = valid.filter((run) => run.result === 'W').length;
	const hitsTaken = valid.reduce((sum, run) => sum + run.hitsTaken, 0);
	const gate = [
		{ id: 'C1.1', text: `${valid.length} valid run(s), ${expectedRuns} expected`, ok: valid.length >= expectedRuns },
		{ id: 'C1.2', text: `${wins} win(s) on ${valid.length} valid run(s); gate needs >= 8/10`, ok: wins >= 8 },
		{ id: 'C3.1', text: engine === null ? 'Not Run - pass --engine-log <godot.log> to count SCRIPT ERROR' : `${engine.scriptErrors} SCRIPT ERROR across ${engine.files.length} engine log file(s)`, ok: engine !== null && engine.scriptErrors === 0 },
		{ id: 'C3.2', text: `${runs.filter((run) => run.resetAfter).length}/${runs.length} run(s) closed by encounter_reset (the reset state itself is proven by harness run_t022_reward)`, ok: runs.length > 0 && runs.every((run) => run.resetAfter) },
	];
	const rows = runs.map((run) => {
		const ticks = run.endFrame === null ? '-' : run.endFrame - run.startFrame;
		const seconds = run.endFrame === null ? '-' : (ticks / TICKS_PER_SECOND).toFixed(2);
		const roles = Object.entries(run.damageByEnemy).map(([key, value]) => `${key} ${value}`).join('<br>') || '-';
		const bossSeconds = run.wave3Frame === null || run.endFrame === null ? '-' : ((run.endFrame - run.wave3Frame) / TICKS_PER_SECOND).toFixed(1);
		return `| ${run.index} | ${run.result ?? '-'} | ${run.waves.join('>')} | ${ticks} | ${seconds} | ${run.hitsTaken} | ${run.damageTaken} | ${roles} | ${bossSeconds} | ${run.wave3Frame === null ? '-' : run.bossDamageDealt} | ${run.hitsDealt} | ${run.swings} | ${run.dodges} | ${run.projectileFires} | ${run.rewards} | ${run.healAmount} | ${valid.includes(run) ? 'valid' : 'INVALID'} |`;
	}).join('\n');
	const markdown = `# L4 session measurement - Phase C grove arena

Generated by \`node tools/score_l4.mjs\` from \`${source}\` - do not hand-edit, rerun instead.
${events.length} log rows, ${runs.length} run start(s), ${valid.length} valid under the C1 rules.

## Per-run table (C1.2 fields, machine-measured)

| # | W/L | Waves | Ticks | s | Hits taken | HP lost | HP lost by role | boss fight s | dmg dealt to boss | Hits dealt | Swings | Dodges | projectile_fire | reward_granted | heal | status |
|---|-----|-------|-------|---|-----------|---------|-----------------|--------------|-------------------|------------|--------|--------|-----------------|----------------|------|--------|
${rows}

Total hits taken across valid runs = **${hitsTaken}**. That is the denominator \`n\` of
C2.2; the numerator \`x\` (hits whose reason the player understood) is user-reported only.

## Machine-checkable sub-gates

| gate | measurement | status |
|---|---|---|
${gate.map((item) => `| ${item.id} | ${item.text} | ${item.ok ? 'ok' : 'CHECK'} |`).join('\n')}

C1.3 (whether the losses came from in-encounter decisions), C2.1 (Readability /
Fairness per run), C2.2 \`x\`, C2.3 (telegraph stills) and C3.3 (FPS while playing)
cannot come from a CSV - they are filled in from the playtest report and the L3
captures. This table never marks an L4 sub-check Passed on its own.

## Violations

${problems.length === 0 ? 'none' : problems.map((line) => `- ${line}`).join('\n')}
`;
	return {
		summary: {
			source, rows: events.length, runs: runs.length, valid: valid.length, wins,
			losses: valid.length - wins, hitsTaken, violations: problems.length,
			bossTelegraphMin: Math.min(...runs.map((run) => run.minBossTelegraph).filter(Number.isFinite), 999),
			scriptErrors: engine === null ? 'n/a' : engine.scriptErrors,
		},
		markdown,
		gate,
		problems,
	};
}

function sourceLabel(file) {
	const absolute = path.resolve(file).replace(/\\/g, '/');
	const relative = path.relative(ROOT, absolute).replace(/\\/g, '/');
	return relative.startsWith('..') ? absolute : relative;
}

function scoreFile(file, expectedRuns, engineLogs) {
	const source = sourceLabel(file);
	const { events, problems } = parseCsv(readFileSync(file, 'utf8'));
	const runs = segment(events);
	const engine = engineLogs.length > 0 ? engineLog(engineLogs) : null;
	return buildReport(source, events, runs, problems.concat(validate(runs)), engine, expectedRuns);
}

// --- selftest fixtures -------------------------------------------------------
// Schema-exact synthetic sessions in the event order the arena really emits. The
// clean fixture must stay green and every mutation must go red with the reason
// named below: that is what proves this scorer can disagree with a log.
function row(frame, entity, event, attackId, targetId, value) {
	return { frame, entity, event, attackId, targetId, value };
}

// `runs` winning wave-3 runs, then a wave-1 death and its reset.
function baseSession(runs = 2) {
	const out = [];
	let frame = 10;
	for (let run = 1; run <= runs + 1; run += 1) {
		if (run > 1) out.push(row(frame, 'encounter', 'encounter_reset', 0, 0, run - 1));
		const waves = run <= runs ? 3 : 1;
		for (let wave = 1; wave <= waves; wave += 1) {
			frame += 5;
			out.push(row(frame, 'encounter', 'wave_start', 0, 0, wave));
			frame += 30;
			out.push(row(frame, 'grunt', 'alert', 0, 0, 0));
			out.push(row(frame, 'grunt', 'telegraph_start', wave, 0, 0));
			out.push(row(frame + TELEGRAPH_FLOOR, 'grunt', 'telegraph_end', wave, 0, 0));
			out.push(row(frame + TELEGRAPH_FLOOR, 'grunt', 'active_start', wave, 0, 0));
			frame += TELEGRAPH_FLOOR + 3;
			out.push(row(frame, 'grunt', 'active_end', wave, 0, 0));
			out.push(row(frame, 'grunt', 'hit', wave, PLAYER_ID, 0));
			out.push(row(frame, 'grunt', 'damage', wave, PLAYER_ID, 15));
			out.push(row(frame, 'player', 'action_start', 100 + run * 10 + wave, 0, 0));
			out.push(row(frame + 4, 'player', 'hit', 100 + run * 10 + wave, 10 + wave, 0));
			out.push(row(frame + 4, 'player', 'damage', 100 + run * 10 + wave, 10 + wave, 10));
			out.push(row(frame + 5, wave === 3 ? 'boss' : 'grunt', 'death', 0, 0, 0));
			if (wave === 3) out.push(row(frame + 6, 'boss', 'boss_phase', 0, 0, 2));
		}
		frame += 10;
		out.push(row(frame, 'encounter', waves === 3 ? 'encounter_win' : 'encounter_lose', 0, 0, 0));
		if (waves === 3) out.push(row(frame, 'reward', 'reward_granted', 0, 0, 1));
		frame += 20;
		if (waves === 3) out.push(row(frame, 'reward', 'heal', 0, PLAYER_ID, 60));
	}
	out.push(row(frame + 30, 'encounter', 'encounter_reset', 0, 0, runs + 1));
	return out;
}

// Insert `extra` right after the first row matching `where`, so the injection
// lands inside a live run instead of after its final reset.
function inject(events, where, extra) {
	const index = events.findIndex(where);
	if (index < 0) throw new Error('fixture injection point not found');
	return [...events.slice(0, index + 1), ...extra, ...events.slice(index + 1)];
}

function cloneFirst(events, where) {
	const found = events.find(where);
	if (found === undefined) throw new Error('fixture row not found');
	return inject(events, where, [found]);
}

function toCsv(events) {
	return [HEADER, ...events.map((event) => `${event.frame},${event.entity},${event.event},${event.attackId},${event.targetId},${event.value}`)].join('\n') + '\n';
}

const CASES = [
	{ name: 'clean', broken: null, events: () => baseSession(2) },
	{ name: 'damage-without-hit', broken: 'damage rows vs', events: () => cloneFirst(baseSession(2), (event) => event.event === 'damage' && event.entity === 'grunt') },
	{ name: 'short-telegraph', broken: `telegraph lead ${TELEGRAPH_FLOOR - 1} < ${TELEGRAPH_FLOOR}`, events: () => inject(baseSession(2), (event) => event.event === 'telegraph_start', [row(900002, 'boss', 'telegraph_start', 77, 0, 0), row(900002 + TELEGRAPH_FLOOR - 1, 'boss', 'active_start', 77, 0, 0)]) },
	{ name: 'abandoned-run', broken: 'abandoned - no encounter_win/encounter_lose', events: () => baseSession(2).concat([row(900100, 'encounter', 'wave_start', 0, 0, 1)]) },
	{ name: 'win-without-reward', broken: 'win logged reward_granted 0 times', events: () => baseSession(2).filter((event) => event.event !== 'reward_granted') },
	{ name: 'two-phase-flips', broken: 'boss_phase logged 2 times', events: () => cloneFirst(baseSession(1), (event) => event.event === 'boss_phase') },
	{ name: 'no-reset-between-runs', broken: 'no encounter_reset before wave 1', events: () => baseSession(2).filter((event) => !(event.event === 'encounter_reset' && event.value === 1)) },
	{ name: 'swarm-id-collision', broken: null, events: () => cloneFirst(baseSession(2), (event) => event.event === 'telegraph_start' && event.entity === 'grunt') },
	{ name: 'missing-header', broken: 'line 1 is not the log header', raw: '0,encounter,wave_start,0,0,1\n10,encounter,encounter_win,0,0,0\n' },
];

function selftest(wanted) {
	const chosen = wanted ? CASES.filter((item) => item.name === wanted) : CASES;
	if (chosen.length === 0) {
		console.log(`SELFTEST FAILED unknown case '${wanted}' (have: ${CASES.map((item) => item.name).join(', ')})`);
		return 1;
	}
	const dir = mkdtempSync(path.join(os.tmpdir(), 'l4-selftest-'));
	let failures = 0;
	for (const item of chosen) {
		const file = path.join(dir, `${item.name}.csv`);
		writeFileSync(file, item.raw ?? toCsv(item.events()));
		const { problems, summary } = scoreFile(file, 3, []);
		if (item.broken === null) {
			const ok = problems.length === 0 && summary.valid === 3 && summary.wins === 2;
			failures += ok ? 0 : 1;
			console.log(`${ok ? 'ok  ' : 'FAIL'} ${item.name}: clean fixture measured valid=${summary.valid} wins=${summary.wins} violations=${problems.length}`);
			for (const line of problems) console.log(`       unexpected red: ${line}`);
			continue;
		}
		const caught = problems.some((line) => line.includes(item.broken));
		failures += caught ? 0 : 1;
		console.log(`${caught ? 'ok  ' : 'FAIL'} ${item.name}: red contains "${item.broken}"`);
		for (const line of problems) console.log(`       red: ${line}`);
	}
	console.log(`SELFTEST ${failures === 0 ? 'PASSED' : 'FAILED'} cases=${chosen.length} failures=${failures} - a scorer that cannot go red measures nothing`);
	return failures === 0 ? 0 : 1;
}

const argv = process.argv.slice(2);
const engineLogs = [];
const files = [];
let expectedRuns = 10;
for (let index = 0; index < argv.length; index += 1) {
	const arg = argv[index];
	if (arg === '--engine-log') index += 1, engineLogs.push(argv[index]);
	else if (arg === '--runs') index += 1, expectedRuns = Number(argv[index]);
	else if (arg !== '--selftest' && arg !== '--save') files.push(arg);
}

if (argv.includes('--selftest')) process.exit(selftest(files[0]));

if (files.length === 0) {
	console.log('usage: node tools/score_l4.mjs <combat_log.csv> [--runs 10] [--engine-log <godot.log>] [--save]');
	console.log('       node tools/score_l4.mjs --selftest [case]');
	console.log('  session log: %APPDATA%\\Godot\\app_userdata\\hd2d-adventure\\combat_log.csv');
	console.log('  copy it out before reopening Godot - every launch truncates it');
	process.exit(2);
}

const result = scoreFile(files[0], expectedRuns, engineLogs);
console.log(result.markdown);
console.log(`L4 ${Object.entries(result.summary).map(([key, value]) => `${key}=${value}`).join(' ')}`);
if (result.problems.length > 0) {
	console.log('exit 1 - see Violations above; if the log really is clean, prove the scorer still bites with `node tools/score_l4.mjs --selftest`');
	process.exit(1);
}
if (argv.includes('--save')) {
	mkdirSync(OUT_DIR, { recursive: true });
	writeFileSync(path.join(OUT_DIR, 'session_table.md'), result.markdown);
	writeFileSync(path.join(OUT_DIR, 'session_table.json'), JSON.stringify({ generatedBy: 'tools/score_l4.mjs', ...result.summary, gate: result.gate }, null, 2) + '\n');
	console.log(`saved: ${path.relative(ROOT, path.join(OUT_DIR, 'session_table.md')).replace(/\\/g, '/')}`);
}
process.exit(0);

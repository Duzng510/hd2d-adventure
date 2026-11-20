import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, readdirSync, existsSync } from 'node:fs';
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

// The probe sidecar (T-025) is what removes the player's memory from the loop:
// for every hit it recorded how many usable telegraph frames there were (raw
// gap minus hitstop), whether the player moved after it, whether dodge was up,
// how close cover was, plus boss state per sample, fps and a PNG per death.
const PROBE_KINDS = new Set(['s', 'h', 'd', 'p']);
const BOSS_RECOVERY = 4; // GruntAI.State { IDLE, CHASE, TELEGRAPH, ACTIVE, RECOVERY }
const LAUNCH_FRAMES = 96; // samples up to here are warm-up: 19 fps at launch is not a play drop

function parseProbe(text) {
	const lines = text.replace(/\r\n?/g, '\n').split('\n').filter((line) => line.trim() !== '');
	const problems = [];
	if (lines.length === 0) return { rows: [], problems: ['empty probe file'] };
	const header = lines[0].split(',');
	for (const column of ['frame', 'kind', 'dreact']) {
		if (!header.includes(column)) problems.push(`probe header has no '${column}' column - wrong rig version?`);
	}
	const rows = [];
	for (let index = 1; index < lines.length; index += 1) {
		const cells = lines[index].split(',');
		const row = {};
		header.forEach((column, position) => { row[column] = cells[position] ?? ''; });
		if (!Number.isInteger(Number(row.frame))) {
			problems.push(`probe line ${index + 1} has no integer frame: "${lines[index]}"`);
			continue;
		}
		rows.push(row);
	}
	return { rows, problems };
}

function numberOr(value, fallback) {
	const parsed = Number(value);
	return Number.isFinite(parsed) ? parsed : fallback;
}

function share(part, whole) {
	return whole === 0 ? '-' : `${Math.round((part / whole) * 100)}%`;
}

function median(values) {
	if (values.length === 0) return '-';
	const sorted = [...values].sort((left, right) => left - right);
	return sorted[Math.floor(sorted.length / 2)];
}

// Median distance between consecutive sample rows, in ticks.
function sampleGap(samples) {
	const frames = samples.map((sample) => Number(sample.frame)).sort((left, right) => left - right);
	const gaps = [];
	for (let index = 1; index < frames.length; index += 1) gaps.push(frames[index] - frames[index - 1]);
	return median(gaps) === '-' ? 0 : median(gaps);
}

// Assigns probe rows to runs by frame window, then reduces them. Windows are
// half-open against the next run's start, so the ticks between a death and its
// reset still belong to the run that died.
function attachProbe(runs, rows, events) {
	const starts = runs.map((run) => run.startFrame);
	const groups = runs.map((run, index) => ({
		run,
		low: starts[index],
		high: index + 1 < starts.length ? starts[index + 1] - 1 : Number.POSITIVE_INFINITY,
		samples: [],
		hits: [],
		deaths: [],
		shots: 0,
	}));
	for (const row of rows) {
		if (!PROBE_KINDS.has(row.kind)) continue;
		const group = groups.find((candidate) => Number(row.frame) >= candidate.low && Number(row.frame) <= candidate.high);
		if (group === undefined) continue;
		if (row.kind === 's') group.samples.push(row);
		else if (row.kind === 'h') group.hits.push(row);
		else if (row.kind === 'd') group.deaths.push(row);
		else if (row.kind === 'p') group.shots += 1;
	}
	const problems = [];
	for (const group of groups) {
		const { run } = group;
		const leads = group.hits.map((hit) => numberOr(hit.dreact, -1));
		const breached = leads.filter((lead) => lead >= 0 && lead < TELEGRAPH_FLOOR).length;
		const unknown = leads.filter((lead) => lead < 0).length;
		// The first ~1.5 s of a launch is shader and asset warm-up, not play: it is
		// reported separately so a 19 fps startup never reads as an in-fight drop.
		const play = group.samples.filter((sample) => Number(sample.frame) > LAUNCH_FRAMES);
		const fps = play.map((sample) => numberOr(sample.fps, 0)).filter((value) => value > 0);
		const launch = group.samples.filter((sample) => Number(sample.frame) <= LAUNCH_FRAMES)
			.map((sample) => numberOr(sample.fps, 0)).filter((value) => value > 0);
		const recovery = group.samples.filter((sample) => numberOr(sample.boss_state, -1) === BOSS_RECOVERY);
		// Sample rows land every few ticks; the gap is measured from the file so a
		// changed sample rate can never silently rescale the window.
		const gap = sampleGap(group.samples);
		// Empty cells are '' and Number('') is 0, so the trace has to test the raw
		// field: treating a missing boss_hp as 0 invents damage out of nothing.
		const trace = group.samples
			.filter((sample) => sample.boss_hp !== '' && sample.boss_state !== ''
				&& Number(sample.boss_hp) >= 0 && Number(sample.boss_state) >= 0)
			.map((sample) => ({ frame: Number(sample.frame), hp: Number(sample.boss_hp), state: Number(sample.boss_state) }));
		let dmgInRecovery = 0;
		let dmgTraced = 0;
		for (let index = 1; index < trace.length; index += 1) {
			const drop = trace[index - 1].hp - trace[index].hp;
			if (drop <= 0) continue;
			dmgTraced += drop;
			if (trace[index].state === BOSS_RECOVERY || trace[index - 1].state === BOSS_RECOVERY) dmgInRecovery += drop;
		}
		const fightTicks = run.wave3Frame === null || run.endFrame === null ? 0 : run.endFrame - run.wave3Frame;
		const recoveryTicks = recovery.length * gap;
		run.probe = {
			hits: group.hits.length,
			readable: leads.filter((lead) => lead >= TELEGRAPH_FLOOR).length,
			breached,
			unknown,
			minLead: leads.filter((lead) => lead >= 0).length === 0 ? '-' : Math.min(...leads.filter((lead) => lead >= 0)),
			moved: share(group.hits.filter((hit) => hit.moved === '1').length, group.hits.length),
			dodgeReady: share(group.hits.filter((hit) => hit.dodge === '1').length, group.hits.length),
			cover: share(group.hits.filter((hit) => hit.nearobs === '1').length, group.hits.length),
			killer: group.deaths.length === 0 ? '-' : String(group.deaths[0].src),
			bossHpLeft: group.deaths.length === 0 ? '-' : numberOr(group.deaths[0].boss_hp, -1),
			recoveryTicks,
			fightTicks,
			recoveryShare: share(recoveryTicks, fightTicks),
			dmgInRecovery,
			dmgTraced,
			punishShare: share(dmgInRecovery, dmgTraced),
			fpsMin: fps.length === 0 ? '-' : Math.min(...fps),
			fpsMedian: median(fps),
			fpsLaunchMin: launch.length === 0 ? '-' : Math.min(...launch),
			shots: group.shots,
		};
		if (run.hitsTaken !== group.hits.length) {
			problems.push(`run ${run.index}: probe saw ${group.hits.length} hit(s) but the combat log has ${run.hitsTaken} - the two files are not the same session`);
		}
		if (breached > 0) problems.push(`run ${run.index}: ${breached} hit(s) landed with only ${run.probe.minLead} usable telegraph frames (< ${TELEGRAPH_FLOOR})`);
		if (unknown > 0) problems.push(`run ${run.index}: ${unknown} hit(s) had no telegraph record at all`);
		if (group.deaths.length > 1) problems.push(`run ${run.index}: ${group.deaths.length} death rows in one run`);
		// Two independent readings of the same fact must agree: the log counts damage
		// rows, the probe watches boss_hp fall.
		if (run.wave3Frame !== null && dmgTraced > 0 && dmgTraced !== run.bossDamageDealt) {
			problems.push(`run ${run.index}: boss_hp trace shows ${dmgTraced} damage to the boss, the log recorded ${run.bossDamageDealt}`);
		}
	}
	return problems;
}

function probeTable(runs) {
	const rows = runs.filter((run) => run.probe !== undefined).map((run) => {
		const probe = run.probe;
		return `| ${run.index} | ${probe.hits} | ${probe.readable}/${probe.hits} | ${probe.minLead} | ${probe.moved} | ${probe.dodgeReady} | ${probe.cover} | ${probe.killer} | ${probe.bossHpLeft} | ${probe.recoveryTicks}t (${probe.recoveryShare}) | ${probe.dmgInRecovery}/${probe.dmgTraced} (${probe.punishShare}) | ${probe.fpsMin} / ${probe.fpsMedian} (${probe.fpsLaunchMin}) | ${probe.shots} |`;
	}).join('\n');
	const withBoss = runs.filter((run) => run.probe !== undefined && run.probe.dmgTraced > 0);
	const dmgIn = withBoss.reduce((sum, run) => sum + run.probe.dmgInRecovery, 0);
	const dmgAll = withBoss.reduce((sum, run) => sum + run.probe.dmgTraced, 0);
	const windowTicks = withBoss.reduce((sum, run) => sum + run.probe.recoveryTicks, 0);
	const fightTicks = withBoss.reduce((sum, run) => sum + run.probe.fightTicks, 0);
	return `## What the rig measured so nobody has to remember (T-025 probe)

| # | Hits | Readable (>= ${TELEGRAPH_FLOOR}f) | Min usable lead | Moved after telegraph | Dodge was ready | Taken at cover/wall | Killed by | Boss HP left | Recovery window | Boss dmg in recovery | fps min / median (launch) | Death PNGs |
|---|------|--------------------|-----------------|-----------------------|-----------------|---------------------|-----------|--------------|-----------------|----------------------|------------------|--------------|
${rows}

\`usable lead\` is the raw telegraph gap minus the hitstop ticks frozen for both
fighters, so it is what a human actually had. The punish window is read two ways:
how much of the boss fight the player spent in RECOVERY, and how much of the
damage they dealt landed inside it - a window that is open but carries no damage
is a different problem from one that is short. Pooled here: **${share(dmgIn, dmgAll)}**
of boss damage landed in the recovery window, which was **${share(windowTicks, fightTicks)}**
of the measured boss-fight ticks. fps comes from the probe's own samples, so C3.3 needs
no HUD reading; in a \`--fixed-fps\` capture it is meaningless by definition.
`;
}

function buildReport(source, events, runs, problems, engine, expectedRuns, probe) {
	const valid = runs.filter((run) => run.resetBefore && run.resetAfter && run.result !== null);
	const wins = valid.filter((run) => run.result === 'W').length;
	const hitsTaken = valid.reduce((sum, run) => sum + run.hitsTaken, 0);
	const probeProblems = probe === null ? [] : attachProbe(runs, probe.rows, events);
	const allProblems = problems.concat(probeProblems);
	const measured = probe === null ? [] : runs.filter((run) => run.probe !== undefined && run.probe.hits > 0);
	const readable = measured.reduce((sum, run) => sum + run.probe.readable, 0);
	const withBoss = measured.filter((run) => run.probe.dmgTraced > 0);
	const punishShare = withBoss.reduce((sum, run) => sum + run.probe.dmgTraced, 0) === 0 ? '-'
		: share(withBoss.reduce((sum, run) => sum + run.probe.dmgInRecovery, 0),
			withBoss.reduce((sum, run) => sum + run.probe.dmgTraced, 0));
	const fpsMin = measured.length === 0 ? null : Math.min(...measured.map((run) => run.probe.fpsMin).filter((value) => typeof value === 'number'));
	const fpsMedian = measured.length === 0 ? '-' : Math.max(...measured.map((run) => run.probe.fpsMedian).filter((value) => typeof value === 'number'));
	const fpsLaunchMin = measured.length === 0 ? '-' : Math.min(...measured.map((run) => run.probe.fpsLaunchMin).filter((value) => typeof value === 'number'));
	const extraGate = probe === null ? [] : [
		{ id: 'C2.2', text: `readable-share ${readable}/${measured.reduce((sum, run) => sum + run.probe.hits, 0)} hits had >= ${TELEGRAPH_FLOOR} usable telegraph frames - a proxy, the player's own "I understood" is still the numerator`, ok: measured.length > 0 && readable === measured.reduce((sum, run) => sum + run.probe.hits, 0) },
		{ id: 'C3.3', text: fpsMin === null ? 'no probe samples with fps - diagnostic only, no gate threshold' : `play fps min ${fpsMin}, median ${fpsMedian}; launch warm-up min ${fpsLaunchMin} excluded (frames <= ${LAUNCH_FRAMES})`, ok: true },
	];
	const gate = [
		{ id: 'C1.1', text: `${valid.length} valid run(s), ${expectedRuns} expected`, ok: valid.length >= expectedRuns },
		{ id: 'C1.2', text: `${wins} win(s) on ${valid.length} valid run(s); gate needs >= 8/10`, ok: wins >= 8 },
		{ id: 'C3.1', text: engine === null ? 'Not Run - pass --engine-log <godot.log> to count SCRIPT ERROR' : `${engine.scriptErrors} SCRIPT ERROR across ${engine.files.length} engine log file(s)`, ok: engine !== null && engine.scriptErrors === 0 },
		{ id: 'C3.2', text: `${runs.filter((run) => run.resetAfter).length}/${runs.length} run(s) closed by encounter_reset (the reset state itself is proven by harness run_t022_reward)`, ok: runs.length > 0 && runs.every((run) => run.resetAfter) },
	].concat(extraGate);
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

${probe === null ? '' : probeTable(runs)}Total hits taken across valid runs = **${hitsTaken}**. That is the denominator \`n\` of
C2.2; the numerator \`x\` (hits whose reason the player understood) is user-reported only.

## Machine-checkable sub-gates

| gate | measurement | status |
|---|---|---|
${gate.map((item) => `| ${item.id} | ${item.text} | ${item.ok ? 'ok' : 'CHECK'} |`).join('\n')}

What never comes from a log: C1.3 (were the losses intended), C2.1 (Readability
and Fairness as judged by the player) and Fun. With the probe attached, C2.2 has
a measured proxy above, C2.3 is covered by the death PNGs, and C3.3 is measured -
but a proxy is not a rating, so this table still never marks an L4 sub-check
Passed on its own.

## Violations

${problems.length === 0 ? 'none' : problems.map((line) => `- ${line}`).join('\n')}
`;
	return {
		summary: {
			source, rows: events.length, runs: runs.length, valid: valid.length, wins,
			losses: valid.length - wins, hitsTaken, violations: allProblems.length,
			bossTelegraphMin: Math.min(...runs.map((run) => run.minBossTelegraph).filter(Number.isFinite), 999),
			probeRows: probe === null ? 0 : probe.rows.length,
			readableShare: `${readable}/${measured.reduce((sum, run) => sum + run.probe.hits, 0)}`,
			punishShare,
			fpsPlayMin: fpsMin === null ? '-' : fpsMin,
			fpsLaunchMin: fpsLaunchMin,
			scriptErrors: engine === null ? 'n/a' : engine.scriptErrors,
		},
		markdown,
		gate,
		problems: allProblems,
	};
}

function sourceLabel(file) {
	const absolute = path.resolve(file).replace(/\\/g, '/');
	const relative = path.relative(ROOT, absolute).replace(/\\/g, '/');
	return relative.startsWith('..') ? absolute : relative;
}

function scoreFile(file, expectedRuns, engineLogs, probeFile) {
	const source = sourceLabel(file);
	const { events, problems } = parseCsv(readFileSync(file, 'utf8'));
	const runs = segment(events);
	const engine = engineLogs.length > 0 ? engineLog(engineLogs) : null;
	let probe = null;
	if (probeFile !== null) {
		const parsed = parseProbe(readFileSync(probeFile, 'utf8'));
		probe = { rows: parsed.rows, problems: parsed.problems };
		return buildReport(source, events, runs, problems.concat(validate(runs), parsed.problems), engine, expectedRuns, probe);
	}
	return buildReport(source, events, runs, problems.concat(validate(runs)), engine, expectedRuns, null);
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

function probeRow(cells) {
	return PROBE_HEADER.split(',').map((column) => (cells[column] === undefined ? '' : String(cells[column]))).join(',');
}

function wave3Frame(events) {
	const found = events.filter((event) => event.event === 'wave_start' && event.value === 3).pop();
	if (found === undefined) throw new Error('fixture has no wave 3');
	return found.frame;
}

// Probe sidecar for the fixtures: one h row per damage-to-player event with the
// real telegraph gap, plus 10 Hz samples, so the probe path is exercised by the
// same session rather than by a file that merely parses.
function baseProbe(events, options = {}) {
	const fps = options.fps ?? 60;
	const telegraphs = {};
	const rows = [];
	const hits = [];
	const trace = options.bossTrace; // { from, damage, inRecovery } - a boss fight to grade
	const states = [2, 3, 4]; // CHASE, TELEGRAPH, RECOVERY
	let bossHp = 300;
	let traced = 0;
	let step = 0;
	for (let frame = 6; frame <= events[events.length - 1].frame; frame += 6) {
		const inTrace = trace !== undefined && frame >= trace.from;
		const state = inTrace ? states[step % 3] : -1;
		let boss_hp = -1;
		if (inTrace) {
			const punishTick = trace.inRecovery ? state === 4 : state !== 4;
			// Never drop on the first traced sample: without a full-hp baseline there
			// is nothing for the scorer to compare against, and the damage vanishes.
			if (punishTick && traced > 0 && bossHp > 300 - trace.damage) bossHp -= 10;
			traced += 1;
			boss_hp = bossHp;
		}
		step += 1;
		rows.push(probeRow({
			frame, kind: 's', hp: 100, x: 0, z: 0, nearobs: 2, dodge: 1, swing: 0,
			boss_hp, boss_state: state, fps: frame <= 96 ? (options.launchFps ?? fps) : fps,
		}));
	}
	for (const event of events) {
		if (event.event === 'telegraph_start') telegraphs[`${event.entity}:${event.attackId}`] = event.frame;
		if (event.event !== 'damage' || event.targetId !== 2) continue;
		const record = event.entity === 'projectile' ? `ranged:${event.attackId}` : `${event.entity}:${event.attackId}`;
		const start = telegraphs[record] ?? -1;
		hits.push({
			frame: event.frame, kind: 'h', hp: 85, x: 0, z: 0, nearobs: 1, dodge: 1, swing: 0,
			boss_hp: -1, boss_state: -1, atk: event.attackId, src: event.entity, dist: 0.9,
			dreact: start < 0 ? -1 : event.frame - start, moved: 1, dmg: event.value, fps,
		});
	}
	if (options.firstLead !== undefined && hits.length > 0) hits[0].dreact = options.firstLead;
	rows.push(...hits.slice(0, hits.length - (options.dropHits ?? 0)).map(probeRow));
	const killing = events.filter((event) => event.event === 'damage' && event.targetId === 2).pop();
	if (events.some((event) => event.event === 'encounter_lose')) {
		rows.push(probeRow({ frame: killing.frame, kind: 'd', hp: 0, atk: killing.attackId, src: killing.entity, dmg: killing.value, boss_hp: -1, note: 'hits=1' }));
	}
	return rows;
}

const PROBE_HEADER = 'frame,kind,hp,x,z,nearobs,dodge,swing,boss_hp,boss_state,atk,src,dist,dreact,moved,dmg,near_role,near_dist,fps,note';

function toProbeCsv(rows) {
	return [PROBE_HEADER, ...rows].join('\n') + '\n';
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
	{ name: 'probe-launch-noise', broken: null, expect: { readableShare: '7/7', fpsPlayMin: 60, fpsLaunchMin: 19 }, events: () => baseSession(2), probe: (events) => baseProbe(events, { launchFps: 19 }) },
	{ name: 'probe-clean', broken: null, expect: { readableShare: '7/7' }, events: () => baseSession(2), probe: (events) => baseProbe(events) },
	{ name: 'probe-unreadable', broken: `usable telegraph frames (< ${TELEGRAPH_FLOOR})`, events: () => baseSession(2), probe: (events) => baseProbe(events, { firstLead: TELEGRAPH_FLOOR - 9 }) },
	{ name: 'probe-desync', broken: 'the two files are not the same session', events: () => baseSession(2), probe: (events) => baseProbe(events, { dropHits: 1 }) },
	{ name: 'probe-punish-used', broken: null, expect: { punishShare: '100%' }, events: () => baseSession(2), probe: (events) => baseProbe(events, { bossTrace: { from: wave3Frame(events), damage: 10, inRecovery: true } }) },
	{ name: 'probe-punish-unused', broken: null, expect: { punishShare: '0%' }, events: () => baseSession(2), probe: (events) => baseProbe(events, { bossTrace: { from: wave3Frame(events), damage: 10, inRecovery: false } }) },
	{ name: 'punish-trace-desync', broken: 'boss_hp trace shows', events: () => baseSession(2), probe: (events) => baseProbe(events, { bossTrace: { from: wave3Frame(events), damage: 30, inRecovery: true } }) },
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
		let probeFile = null;
		if (item.probe !== undefined) {
			probeFile = path.join(dir, `${item.name}_probe.csv`);
			writeFileSync(probeFile, toProbeCsv(item.probe(item.events())));
		}
		const { problems, summary } = scoreFile(file, 3, [], probeFile);
		if (item.broken === null) {
			const expected = item.expect ?? {};
			const ok = problems.length === 0 && summary.valid === 3 && summary.wins === 2
				&& (expected.probeRows === undefined || summary.probeRows === expected.probeRows)
				&& (expected.readableShare === undefined || summary.readableShare === expected.readableShare)
				&& (expected.punishShare === undefined || summary.punishShare === expected.punishShare)
				&& (expected.fpsPlayMin === undefined || summary.fpsPlayMin === expected.fpsPlayMin)
				&& (expected.fpsLaunchMin === undefined || summary.fpsLaunchMin === expected.fpsLaunchMin);
			failures += ok ? 0 : 1;
			console.log(`${ok ? 'ok  ' : 'FAIL'} ${item.name}: clean fixture measured valid=${summary.valid} wins=${summary.wins} violations=${problems.length} punish=${summary.punishShare}`);
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
let probeFile = null;
let expectedRuns = 10;
for (let index = 0; index < argv.length; index += 1) {
	const arg = argv[index];
	if (arg === '--engine-log') index += 1, engineLogs.push(argv[index]);
	else if (arg === '--probe') index += 1, probeFile = argv[index];
	else if (arg === '--runs') index += 1, expectedRuns = Number(argv[index]);
	else if (arg !== '--selftest' && arg !== '--save') files.push(arg);
}

if (argv.includes('--selftest')) process.exit(selftest(files[0]));

if (files.length === 0) {
	console.log('usage: node tools/score_l4.mjs <combat_log.csv> [--runs 10] [--probe <l4_probe.csv>] [--engine-log <godot.log>] [--save]');
	console.log('  --probe defaults to l4_probe.csv next to the combat log (the rig writes it beside it in user://)');
	console.log('       node tools/score_l4.mjs --selftest [case]');
	console.log('  session log: %APPDATA%\\Godot\\app_userdata\\hd2d-adventure\\combat_log.csv');
	console.log('  copy it out before reopening Godot - every launch truncates it');
	process.exit(2);
}

if (probeFile === null) {
	const sibling = path.join(path.dirname(path.resolve(files[0])), 'l4_probe.csv');
	if (existsSync(sibling)) probeFile = sibling;
}
const result = scoreFile(files[0], expectedRuns, engineLogs, probeFile);
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

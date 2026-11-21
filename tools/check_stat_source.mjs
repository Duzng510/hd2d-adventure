#!/usr/bin/env node
// T-029 law: only player_stats.gd may read player stat fields from tuning.
// Runtime code must go through PlayerStats so buffs have exactly one effect path.

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const STAT_KEYS = [
  'light_damage', 'player_max_hp', 'player_move_speed',
  'light_startup_frames', 'light_active_frames', 'light_recovery_frames',
  'light_combo_hits', 'combo_window_frames', 'light_reach',
  'dodge_speed', 'dodge_total_frames', 'dodge_iframe_frames',
  'fatigue_free_swings', 'fatigue_step_frames', 'fatigue_max_frames',
  'fatigue_decay_frames',
];
const BANNED = new RegExp(`tuning\\.(${STAT_KEYS.join('|')})\\b`);
const ALLOWED = new Set(['scripts/combat/player_stats.gd', 'scripts/combat/combat_tuning.gd']);

function walk(dir, out = []) {
  for (const name of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, name.name);
    if (name.isDirectory()) walk(path, out);
    else if (name.name.endsWith('.gd')) out.push(path);
  }
  return out;
}

function scan(sources) {
  const violations = [];
  for (const [path, text] of sources) {
    if (ALLOWED.has(path)) continue;
    text.split('\n').forEach((line, i) => {
      if (BANNED.test(line)) violations.push(`${path}:${i + 1}: ${line.trim()}`);
    });
  }
  return violations;
}

if (process.argv.includes('--selftest')) {
  // The checker must flag a violation and must leave a non-stat read alone.
  const dirty = scan(new Map([
    ['scripts/combat/sample.gd', 'var d := tuning.light_damage\nvar h := tuning.hitstop_frames'],
  ]));
  const clean = scan(new Map([
    ['scripts/combat/player_stats.gd', 'var d := tuning.light_damage'],
  ]));
  const ok = dirty.length === 1 && clean.length === 0;
  console.log(`selftest ${ok ? 'PASS' : 'FAIL'} violations=${dirty.length} allowed_hit=${clean.length}`);
  process.exit(ok ? 0 : 1);
}

const files = walk('scripts');
const violations = scan(new Map(files.map((p) => [p.split('\\').join('/'), readFileSync(p, 'utf8')])));
if (violations.length > 0) {
  for (const v of violations) console.error(v);
  console.error(`stat-source violations: ${violations.length}`);
  process.exit(1);
}
console.log(`stat-source clean: ${files.length} scripts`);

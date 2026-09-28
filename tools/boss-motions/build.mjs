/** Publish the current runtime roster and the review UI into the local web build. */
import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '../..');
const out = path.join(root, 'builds/web/boss-motions');
const selected = JSON.parse(fs.readFileSync(path.join(root, 'assets/runtime/motions/v04/selected-motions.json')));
const skills = JSON.parse(fs.readFileSync(path.join(root, "assets/runtime/combat/v06/warden-skills.json")));
const roster = JSON.parse(fs.readFileSync(path.join(root, 'assets/runtime/characters/v04/animation-manifest.json'))).general;
const custom = {Sword_Idle:'持枪待机', Warden_Kneel_Enter:'单膝跪下 · 进入处决窗口', Warden_Kneel_Hold:'单膝跪地 · 等待处决', Warden_Rise:'支撑起身 · 处决超时恢复'};
const rows = Object.entries(roster).map(([id, info]) => {
    const row = selected.find(item => item.id === id) || {};
    const name = row.name || custom[id] || id;
    const group = (row.category || '').includes('Attack') ? 'attack' : /Walk|Run|待机/.test(name) ? 'movement' : /Hit|Standup|单膝|起身/.test(name) ? 'reaction' : 'other';
    const use = {attack:'攻击', movement:'移动 / 待机', reaction:'受击 / 恢复', other:'怒吼 / 登场'}[group];
    let description = group === 'attack' ? 'V06 使用审阅后招式；常规攻击 1×，每招独立范围判定及恢复停顿。' : '使用实际重映射的 Boss 骨架，战旗和武器随挂点同步运动。';
    if (id.startsWith('Warden_')) description = '本轮在目标骨架上制作的单膝跪姿及过渡，不是原受击动作的末帧停顿。';
    if (skills[id]) description += ` 判定 ${skills[id].shape}，范围 ${skills[id].reach}m，伤害点 ${skills[id].windows.join(" / ")}；收招 ${skills[id].recovery}s。`;
    if (id === "combat-master-1409c47c83223aac5e53") description = "登场在游戏中 0.75×，已加入先慢后快的非线性节奏。";
    return {id, name, duration:info.length, group, use, description, note:row.review?.note || '', previousDecision:row.review?.status || 'pending'};
});
fs.mkdirSync(out, {recursive:true});
for (const file of ['index.html', 'board.css', 'board.mjs']) fs.copyFileSync(path.join(import.meta.dirname, file), path.join(out, file));
fs.writeFileSync(path.join(out, 'motions.json'), JSON.stringify(rows, null, 2)+'\n');
fs.copyFileSync(path.join(out, 'motions.json'), path.join(import.meta.dirname, 'motions.json'));
console.log(`Published ${rows.length} current Boss motions`);

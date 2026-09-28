/** Copy only user-selected audio; preserve exact catalog identities and provenance. */
import fs from 'node:fs';
import path from 'node:path';
const project = path.resolve(import.meta.dirname, '../..');
const workspace = path.resolve(project, '../..');
const library = path.join(workspace, 'asset-audition/pro-sound/public');
const shared = path.join(workspace, 'asset-audition/shared-pool');
const catalogs = [
    ...JSON.parse(fs.readFileSync(path.join(library, 'catalog.json'))).items.map(x => ({...x, local: path.join(library, x.url)})),
    ...JSON.parse(fs.readFileSync(path.join(shared, 'public/audio-catalog.json'))).items.map(x => ({...x, local: path.join(shared, x.source)})),
];
const cues = {
    boss_step: ['footstep_concrete_land_08'], boss_run: ['footstep_concrete_run_08'],
    player_step: ['snow_digging_scooping_shoveling_15'],
    player_steps_loop: ['snow_digging_scooping_shoveling_loop_01'],
    player_roll: ['foley_cloth_light_fast_movement_12'], ambient: ['background_room_tone_loop_02'],
    execution: ['cinematic_deep_low_whoosh_impact_03', 'SD_Blood Guts Small 01'],
    boss_roar: ['troll_monster_battle_grunt_05'],
    boss_hurt: ['troll_monster_hurt_pain_short_05', 'troll_monster_hurt_pain_long_04'],
    boss_victory: ['troll_monster_laugh_07'],
    player_hurt: ['voice_male_b_hurt_pain_set_2_03', 'voice_male_b_hurt_pain_set_2_04'],
    player_launch: ['voice_male_b_hurt_pain_set_1_04'],
    blood_hit: ['bullet_impact_body_flesh_02', 'bullet_impact_body_flesh_03', 'bullet_impact_body_flesh_04'],
    boss_swing: ['SD_Blade,Swing,Whoosh.5'],
    player_swing_1: ['SD_Ruby,Schwing-Scrape 13'], player_swing_2: ['SD_Ruby,Schwing-Scrape 07'],
    player_swing_3: ['SD_Schwing,Fast 09'], player_death: ['SD_Broad Drop Large 01'],
};
const out = path.join(project, 'assets/runtime/audio/v04');
fs.mkdirSync(out, {recursive:true});
const manifest = {};
for (const [cue, names] of Object.entries(cues)) {
    manifest[cue] = names.map((name, i) => {
        const matches = catalogs.filter(x => x.name === name && fs.existsSync(x.local));
        matches.sort((a,b) => a.channels - b.channels);
        const asset = matches[0];
        if (!asset) throw new Error('Missing exact selected sound: ' + name);
        const file = `${cue}_${i}.wav`;
        fs.copyFileSync(asset.local, path.join(out, file));
        return {name, id:asset.id, source:asset.local, file:`res://assets/runtime/audio/v04/${file}`, duration:asset.duration};
    });
}
fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify({cues:Object.keys(manifest).length, sounds:Object.values(manifest).flat().length}));

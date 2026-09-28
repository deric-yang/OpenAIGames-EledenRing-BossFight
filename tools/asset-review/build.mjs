/** Publish only public model artifacts into the existing local web build. */
import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '../..');
const output = path.join(root, 'builds/web/asset-review');
const catalog = [
    ['silver_knight_v04_rigged', '银灰骑士 · V04', '银灰雕纹铠甲、灰黑披风与羽饰。已减面并绑定骨架，游戏内接入三连、翻滚、受击、击飞、死亡与处决。', {source:'assets/runtime/characters/v04/knight_animated.glb', kind:'Tripo + Blender · 已绑定与烘焙动作', orbit:'0deg 80deg auto'}],
    ['old_general_v04_rigged', '王骸的守望者 · 羽饰老将', '旧金铠甲、酒红战袍与羽饰大氅。运行时体型放大 1.25 倍，约 8 米；含当前 36 个所选动作、待机和 3 个单膝跪姿过渡。', {source:'assets/runtime/characters/v04/general_animated.glb', kind:'Tripo + Blender · 已绑定与烘焙动作', orbit:'0deg 80deg auto'}],
    ['knight_longsword_v04', '玩家直剑', '细长直刃、上弯护手与圆形剑首，按最新参考生成并减面。游戏中随真实手部挂点运动。', {source:'assets/runtime/characters/v04/knight_sword.glb', kind:'Tripo + Blender · 6,500 三角面', orbit:'0deg 80deg auto'}],
    ['banner_polearm_v04', '老将战旗长枪 · 刚性部分', '新版本替代巨剑：长柄、雕纹枪刃和旧金饰件。旗布独立绑骨，完整握持与飘动请进入可玩场景。', {source:'assets/runtime/characters/v04/general_polearm.glb', kind:'Tripo + Blender · 9,500 三角面', orbit:'0deg 80deg auto'}],
    ['banner_cloth_v04', '酒红金纹战旗 · 柔性旗布', '独立网格和 7 节骨骼。此处可预览循环风动；游戏内叠加武器运动惯性和重力垂落方向。', {source:'assets/runtime/characters/v04/banner_cloth.glb', kind:'Blender · 7 节骨骼', orbit:'0deg 80deg auto'}],
    ['golden_tree_v01', '黄金巨树 · 已认可', '用户已认可本版树形，保留现有造型。后续只做运行时优化和场景中的发光、雾气与构图。'],
    ['war_relic_cluster_v01', '战争残骸', '成组盾牌、盔甲与断裂武器。后续减面后用于沙丘散布与近景组合。'],
    ['sword_grave_cluster_v02', '剑冢 · 插剑群', '多把直剑插入沙地，形成疏密与高低差，配合低矮盾甲残骸构成不同层次。'],
    ['polearm_grave_cluster_v02', '剑冢 · 枪戟群', '高挑长枪与戟的竖向轮廓，穿插散布在沙丘两侧；避免堵住中央战斗与相机通道。'],
    ['broken_war_bow_v04', '散落残骸 · 断弓', '新生成的断弓残骸，按随机角度、大小散布到战场。', {source:'assets/runtime/world/v04/broken_bow.glb', kind:'Tripo + Blender · 减面版'}],
    ['fallen_soldier_relic_v04', '散落残骸 · 阵亡士兵', '风化盔甲与士兵残骸，配合独立断刃、盾牌、箭杆与甲片分散摆放。', {source:'assets/runtime/world/v04/fallen_soldier.glb', kind:'Tripo + Blender · 减面版'}],
    ['soul_standard_v04', '接地半透明魂幡', '长幅残旗，淡金符纹、半透明布面和循环飘动。完整场景中底部埋入地面，顶部飘向空中。', {source:'assets/runtime/world/v04/standard.glb', kind: 'Blender · 半透明 / 循环风动', orbit: '0deg 80deg auto'}],
    ['dune_battlefield_v04', '古战场遗迹 · 起伏战场', '320 × 360 米沙丘，战斗区也有连续起伏；游戏内已有对应碰撞和非重复世界坐标沙地材质。', {source:'assets/runtime/world/v04/terrain.glb', kind: 'Blender · 地形', orbit: '25deg 45deg auto', labels: ['俯览', '侧向俯览', '反向俯览']}],
    ['golden_respawn_sigil_v03', '黄金复活符文', '新生成的繁复金色符文圆盘，已放平为贴地浅浮雕。整体场景中叠加呼吸金光、光环与上升粒子。', {source: 'assets/runtime/assembly/sigil.glb', kind: 'Tripo + Blender 贴地加工', orbit: '20deg 25deg auto', labels: ['俯览', '侧向俯览', '反向俯览']}],
];
fs.mkdirSync(output, {recursive: true});
for (const name of ['index.html', 'review.css', 'review.mjs', 'vendor']) {
    fs.cpSync(path.join(import.meta.dirname, name), path.join(output, name), {recursive: true});
}
const manifest = [];
for (const [id, title, description, options = {}] of catalog) {
    const source = options.source ? path.join(root, options.source) : path.join(root, 'assets/source', id, 'model.glb');
    const review = path.join(root, 'assets/processed', id, 'review');
    if (!fs.existsSync(source) || !fs.existsSync(path.join(review, 'back.png'))) continue;
    const inspection = JSON.parse(fs.readFileSync(path.join(review, 'inspection.json'), 'utf8'));
    const target = path.join(output, id);
    fs.mkdirSync(target, {recursive: true});
    fs.copyFileSync(source, path.join(target, 'model.glb'));
    for (const name of ['front', 'three-quarter', 'back']) {
        fs.copyFileSync(path.join(review, name + '.png'), path.join(target, name + '.png'));
    }
    manifest.push({id, title, description, kind: 'Tripo 原始模型', orbit: '90deg 80deg auto', ...options,
        triangles: inspection.triangles,
        armatures: inspection.armatures, bytes: fs.statSync(source).size});
}
fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
const selected = JSON.parse(fs.readFileSync(path.join(root,'assets/runtime/motions/v04/selected-motions.json'),'utf8'));
const labels = Object.fromEntries(selected.map(row => [row.id,row.name]));
Object.assign(labels, {Sword_Idle:'持剑待机',Walk_Loop:'行走',Jog_Fwd_Loop:'小跑',Sprint_Loop:'疾跑',Roll:'翻滚 / 受身',Hit_Chest:'受击',Death01:'死亡',ual2__Sword_Regular_A:'三连 · 第一段',ual2__Sword_Regular_B:'三连 · 第二段',ual2__Sword_Regular_Combo:'三连 · 第三段',ual2__Hit_Knockback_RM:'被击飞'});
fs.writeFileSync(path.join(output,'motion-labels.json'),JSON.stringify(labels,null,2)+'\n');
console.log(`Published ${manifest.length} source assets for local review`);

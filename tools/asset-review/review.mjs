const entries = await fetch('manifest.json').then(response => response.json());
await customElements.whenDefined('model-viewer');
const viewer = document.querySelector('model-viewer');
const state = document.querySelector('#load-state');
const motion = document.querySelector('#motion');
const motionLabels = await fetch('motion-labels.json').then(response => response.json());
viewer.addEventListener('load', () => {
    state.textContent = '模型已加载';
    viewer.setAttribute('camera-orbit', currentOrbit);
    viewer.jumpCameraToGoal();
    motion.replaceChildren(...viewer.availableAnimations.map(name => {
        const option = document.createElement('option');
        option.value = name;
        option.textContent = motionLabels[name] || name;
        return option;
    }));
    motion.hidden = viewer.availableAnimations.length < 2;
    const idle = viewer.availableAnimations.find(name => name === 'Sword_Idle') || viewer.availableAnimations[0];
    if (idle) { motion.value = idle; viewer.animationName = idle; viewer.play(); }
});
motion.onchange = () => { viewer.animationName = motion.value; viewer.play(); };
viewer.addEventListener('error', () => { state.textContent = '模型加载失败，可查看下方渲染图'; });
const labels = ['正面', '侧前方', '背面'];
const files = ['front', 'three-quarter', 'back'];
let currentOrbit = '90deg 80deg auto';
function select(entry, index) {
    document.querySelectorAll('nav button').forEach((button, i) => button.setAttribute('aria-pressed', i === index));
    document.querySelector('#number').textContent = `SOURCE ASSET / ${String(index + 1).padStart(2, '0')}`;
    document.querySelector('#title').textContent = entry.title;
    document.querySelector('#description').textContent = entry.description;
    document.querySelector('#metrics').textContent = `${entry.triangles.toLocaleString()} 三角面 · ${(entry.bytes / 1048576).toFixed(1)} MB · ${entry.kind}`;
    document.querySelector('#download').href = `${entry.id}/model.glb`;
    state.textContent = '加载模型中…';
    viewer.src = `${entry.id}/model.glb`;
    const character = ['silver_knight_v04_rigged','old_general_v04_rigged'].includes(entry.id);
    currentOrbit = character ? '0deg 80deg 4.8m' : entry.orbit;
    viewer.setAttribute('camera-orbit', currentOrbit);
    viewer.setAttribute('camera-target', character ? '0m 0.95m 0m' : 'auto auto auto');
    document.querySelector('#ground-view').hidden = entry.id !== 'dune_battlefield_v04';
    document.querySelector('#wind').hidden = !['soul_standard_v04','banner_cloth_v04'].includes(entry.id);
    document.querySelector('#wind').textContent = '暂停飘动';
    viewer.autoplay = true;
    document.querySelector('#renders').replaceChildren(...files.map((file, i) => {
        const link = document.createElement('a');
        link.href = `${entry.id}/${file}.png`;
        link.target = '_blank';
        const img = document.createElement('img');
        img.src = link.href;
        img.alt = `${entry.title} · ${(entry.labels || labels)[i]}`;
        img.loading = 'lazy';
        const caption = document.createElement('span');
        caption.textContent = (entry.labels || labels)[i];
        link.append(img, caption);
        return link;
    }));
}
entries.forEach((entry, i) => {
    const button = document.createElement('button');
    button.textContent = `${String(i + 1).padStart(2, '0')} / ${entry.title}`;
    button.onclick = () => select(entry, i);
    document.querySelector('#assets').append(button);
});
document.querySelector('#reset').onclick = () => {
    viewer.setAttribute('camera-orbit', currentOrbit);
    viewer.setAttribute('camera-target', 'auto auto auto');
};
document.querySelector('#ground-view').onclick = () => {
    viewer.setAttribute('camera-target', '0m 2m 0m');
    viewer.setAttribute('camera-orbit', '180deg 86deg 20m');
};
document.querySelector('#wind').onclick = event => {
    if (viewer.paused) {
        viewer.play();
        event.target.textContent = '暂停飘动';
    } else {
        viewer.pause();
        event.target.textContent = '继续飘动';
    }
};
if (entries.length) select(entries[0], 0);

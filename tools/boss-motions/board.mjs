const rows = await fetch('motions.json').then(r => r.json());
const $ = id => document.getElementById(id);
const labels = {keep:'保留', remove:'移除', adjust:'需调整', pending:'待审阅'};
const key = 'gilded-warden-motion-review-v06';
let reviews = {};
try { reviews = JSON.parse(localStorage.getItem(key) || '{}'); } catch { /* Keep review usable when storage is unavailable. */ }
let current = rows[0];
let ready = false;
let paused = false;
function send(extra = {}) {
    if (ready) $('preview').contentWindow.postMessage({type:'warden-motion', ...extra}, location.origin);
}
function save() {
    try { localStorage.setItem(key, JSON.stringify(reviews)); $('saved').textContent = '已保存在当前浏览器；完成后可导出审阅。'; }
    catch { $('saved').textContent = '浏览器未允许本地保存，请使用导出按钮保存本次审阅。'; }
}
function list() {
    const query = $('search').value.toLowerCase();
    const visible = rows.filter(row => (row.name+' '+row.note).toLowerCase().includes(query)
        && ($('category').value === 'all' || row.group === $('category').value)
        && ($('filter').value === 'all' || (reviews[row.id]?.status || 'pending') === $('filter').value));
    $('motions').replaceChildren(...visible.map(row => {
        const button = document.createElement('button');
        button.textContent = row.name;
        button.setAttribute('aria-pressed', row.id === current.id);
        const small = document.createElement('small');
        small.textContent = `${row.duration.toFixed(2)}s · ${row.use} · ${labels[reviews[row.id]?.status || 'pending']}`;
        button.append(small);
        button.onclick = () => select(row);
        return button;
    }));
    const done = rows.filter(row => reviews[row.id]?.status && reviews[row.id].status !== 'pending').length;
    $('counts').textContent = `${rows.length} 个动作 · 已审 ${done} · 当前显示 ${visible.length}`;
}
function select(row) {
    current = row;
    $('name').textContent = row.name;
    $('group').textContent = `WARDEN / ${row.use} / ${row.duration.toFixed(2)}s`;
    $('description').textContent = row.description;
    $('source-note').textContent = row.note ? `原始备注：${row.note}` : '原始选择未填写备注。';
    $('note').value = reviews[row.id]?.note || '';
    document.querySelectorAll('[data-status]').forEach(button => button.setAttribute('aria-pressed', button.dataset.status === (reviews[row.id]?.status || 'pending')));
    $('seek').value = 0;
    paused = false;
    $('play').textContent = '暂停';
    send({id:row.id, paused:false, rate:Number($('rate').value)});
    list();
}
window.addEventListener('message', event => {
    if (event.origin !== location.origin || event.source !== $('preview').contentWindow || !['warden-ready','warden-playing'].includes(event.data?.type)) return;
    if (event.data.type === 'warden-playing') {
        const row = rows.find(item => item.id === event.data.id);
        $('actual').textContent = '实际播放：' + (row?.name || event.data.id);
        return;
    }
    ready = true;
    $('loading').hidden = true;
    send({id:current.id, paused, rate:Number($('rate').value)});
});
for (const id of ['search', 'category', 'filter']) $(id).addEventListener('input', list);
$('play').onclick = () => { paused = !paused; $('play').textContent = paused ? '继续' : '暂停'; send({paused}); };
$('replay').onclick = () => select(current);
$('rate').onchange = () => send({rate:Number($('rate').value)});
$('seek').oninput = () => { paused = true; $('play').textContent = '继续'; send({paused:true, seek:Number($('seek').value)/100}); };
$('note').oninput = () => { reviews[current.id] = {...reviews[current.id], note:$('note').value, updated:new Date().toISOString()}; save(); };
document.querySelectorAll('[data-status]').forEach(button => button.onclick = () => {
    reviews[current.id] = {...reviews[current.id], status:button.dataset.status, updated:new Date().toISOString()};
    save();
    document.querySelectorAll('[data-status]').forEach(other => other.setAttribute('aria-pressed', other === button));
    list();
});
let exportUrl;
$('export').onclick = () => {
    const payload = {project:'gilded-ruin-boss', version:'v06', exported:new Date().toISOString(), motions:rows.map(row => ({id:row.id, name:row.name, status:'pending', note:'', ...reviews[row.id]}))};
    const text = JSON.stringify(payload, null, 2);
    if (exportUrl) URL.revokeObjectURL(exportUrl);
    exportUrl = URL.createObjectURL(new Blob([text], {type:'application/json'}));
    $('export-text').value = text;
    $('download-export').href = exportUrl;
    $('copy-state').textContent = '';
    $('export-dialog').showModal();
};
$('copy-export').onclick = async () => {
    try { await navigator.clipboard.writeText($('export-text').value); $('copy-state').textContent = '已复制，可粘贴到当前会话。'; }
    catch { $('export-text').select(); $('copy-state').textContent = '请按 ⌘C / Ctrl+C 复制已选中的 JSON。'; }
};
$('close-export').onclick = () => $('export-dialog').close();
select(current);

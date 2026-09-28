/** Tripo v3 production workflow. Credentials via environment; curl config via stdin. */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';

const root = path.resolve(import.meta.dirname, '../..');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'scripts/tripo/production-v01.json'), 'utf8'));
const base = process.env.TRIPO_BASE_URL || 'https://openapi.tripo3d.ai/v3';
if (!['https://openapi.tripo3d.ai/v3', 'https://openapi.tripo3d.com/v3'].includes(base)) {
    throw new Error('Only official Tripo API hosts are allowed');
}
const records = path.join(root, 'generation-records/production-v01');
const key = process.env.TRIPO_API_KEY;
let address;

function save(file, data) {
    fs.mkdirSync(path.dirname(file), {recursive: true});
    fs.writeFileSync(file + '.tmp', JSON.stringify(data, null, 2) + '\n', {mode: 0o600});
    fs.renameSync(file + '.tmp', file);
}

function runCurl(config, download = false) {
    const args = ['-q', '-sS', '--connect-timeout', '15', '--max-time', download ? '300' : '75', '--proto', '=https', '--proto-redir', '=https'];
    if (process.env.CURL_CA_BUNDLE) args.push('--cacert', process.env.CURL_CA_BUNDLE, '--proxy-cacert', process.env.CURL_CA_BUNDLE);
    if (address && !download) args.push('--resolve', 'openapi.tripo3d.ai:443:' + address);
    args.push('--config', '-');
    const env = {...process.env};
    if (download && process.env.TRIPO_DOWNLOAD_DIRECT === '1') {
        for (const name of ['HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy', 'ALL_PROXY', 'all_proxy']) delete env[name];
    }
    const response = spawnSync('curl', args, {input: config, encoding: 'utf8', env, maxBuffer: 8 * 1024 * 1024});
    if (response.status !== 0) throw new Error('Network request failed (curl ' + response.status + '); response omitted');
    return response.stdout;
}

function api(endpoint, body, file) {
    if (!key) throw new Error('TRIPO_API_KEY is not configured');
    if (key.startsWith('tcli_')) throw new Error('Client ID is not an API key; configure the API key from Tripo Console');
    const config = ['url = ' + JSON.stringify(base + endpoint), 'header = ' + JSON.stringify('Authorization: Bearer ' + key)];
    if (file) config.push('form = ' + JSON.stringify('file=@' + file));
    else if (body) config.push('header = "Content-Type: application/json"', 'data = ' + JSON.stringify(JSON.stringify(body)));
    const data = JSON.parse(runCurl(config.join('\n') + '\n'));
    if (data.code) throw new Error('Tripo rejected request; code ' + Number(data.code));
    return data.data ?? data;
}

function select(ids) {
    return ids.map(id => {
        const item = catalog.find(entry => entry.id === id);
        if (!item) throw new Error('Unknown asset ' + id);
        return item;
    });
}

function submit(asset) {
    const dir = path.join(records, asset.id);
    const marker = path.join(dir, 'request.json');
    const submitted = path.join(dir, 'submission.json');
    if (fs.existsSync(submitted)) {
        console.log(JSON.stringify({id: asset.id, state: 'already_submitted'}));
        return;
    }
    if (fs.existsSync(marker)) throw new Error('Ambiguous prior submission; inspect account tasks before any retry: ' + asset.id);
    let request = {model: 'v3.1-20260211', geometry_quality: 'detailed', face_limit: asset.face_limit,
        texture: true, pbr: true, texture_quality: 'detailed', auto_size: true, model_seed: asset.seed};
    let endpoint = '/generation/text-to-model';
    let sourceHash;
    if (asset.operation) {
        if (!['rig-check', 'rig'].includes(asset.operation)) throw new Error('Unsupported operation');
        const parent = JSON.parse(fs.readFileSync(path.join(records, asset.source, 'submission.json'), 'utf8'));
        const parentStatus = JSON.parse(fs.readFileSync(path.join(records, asset.source, 'status.json'), 'utf8'));
        if (parentStatus.status !== 'success') throw new Error('Source is not complete');
        request = {input: parent.task_id};
        endpoint = '/animations/' + asset.operation;
        if (asset.operation === 'rig') {
            const check = JSON.parse(fs.readFileSync(path.join(records, asset.source + '_rigcheck', 'result.json'), 'utf8'));
            if (!check.riggable) throw new Error('Model did not pass rig check');
            Object.assign(request, {model: 'v1.0-20240301', rig_type: 'biped', spec: 'mixamo', out_format: 'glb'});
        }
    } else if (asset.image) {
        const file = path.join(root, asset.image);
        sourceHash = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
        request.input = api('/files', null, file).file_token;
        if (!request.input) throw new Error('Upload missing file token');
        endpoint = '/generation/image-to-model';
    } else {
        request.prompt = asset.prompt;
        request.negative_prompt = 'cartoon, toy, pedestal, text, watermark, fused limbs, extra limbs, melted shapes';
    }
    save(marker, {base_url: base, endpoint, request, asset, source_sha256: sourceHash, created_at: new Date().toISOString()});
    const result = api(endpoint, request);
    if (!result.task_id) throw new Error('Missing task ID; reconcile account before retry');
    save(submitted, {task_id: result.task_id});
    console.log(JSON.stringify({id: asset.id, task_id: result.task_id, state: 'submitted'}));
}

function poll(asset) {
    const dir = path.join(records, asset.id);
    const sub = path.join(dir, 'submission.json');
    if (!fs.existsSync(sub)) return;
    const {task_id: taskId} = JSON.parse(fs.readFileSync(sub, 'utf8'));
    const task = api('/tasks/' + encodeURIComponent(taskId));
    const status = {id: asset.id, task_id: taskId, status: task.status, progress: task.progress,
        credits_consumed: task.credits_consumed, checked_at: new Date().toISOString()};
    save(path.join(dir, 'status.json'), status);
    if (task.status === 'success' && asset.operation === 'rig-check') {
        save(path.join(dir, 'result.json'), task.output);
        console.log(JSON.stringify({...status, output: task.output}));
        return;
    }
    if (task.status === 'success') {
        const output = path.join(root, 'assets/source', asset.id, 'model.glb');
        if (!fs.existsSync(output)) {
            const url = task.output?.model_url ?? task.output?.pbr_model ?? task.output?.model;
            if (!url || new URL(url).protocol !== 'https:') throw new Error('Missing HTTPS model output');
            fs.mkdirSync(path.dirname(output), {recursive: true});
            runCurl('url = ' + JSON.stringify(url) + '\noutput = ' + JSON.stringify(output + '.part') + '\n', true);
            const bytes = fs.readFileSync(output + '.part');
            if (bytes.toString('ascii', 0, 4) !== 'glTF' || bytes.readUInt32LE(4) !== 2 || bytes.readUInt32LE(8) !== bytes.length) throw new Error('Invalid GLB output');
            fs.renameSync(output + '.part', output);
            save(path.join(dir, 'artifact.json'), {path: path.relative(root, output), bytes: bytes.length,
                sha256: crypto.createHash('sha256').update(bytes).digest('hex'), status: 'source_pending_geometry_and_rig_review'});
        }
        status.downloaded = true;
        save(path.join(dir, 'status.json'), status);
    }
    console.log(JSON.stringify(status));
}

try {
    const [command, ...ids] = process.argv.slice(2);
    if (process.env.TRIPO_RESOLVE_IP) address = process.env.TRIPO_RESOLVE_IP;
    if (command === 'balance') console.log(JSON.stringify(api('/account/balance')));
    else if (command === 'inspect') {
        for (const asset of select(ids)) {
            const sub = JSON.parse(fs.readFileSync(path.join(records, asset.id, 'submission.json'), 'utf8'));
            const task = api('/tasks/' + encodeURIComponent(sub.task_id));
            const url = task.output?.model_url ?? task.output?.pbr_model ?? task.output?.model;
            console.log(JSON.stringify({id: asset.id, status: task.status, output_keys: Object.keys(task.output || {}), model_host: url ? new URL(url).hostname : null}));
        }
    }
    else if (command === 'submit') {
        if (!ids.length) throw new Error('Explicit asset IDs required to submit');
        for (const asset of select(ids)) submit(asset);
    } else if (command === 'poll') {
        for (const asset of ids.length ? select(ids) : catalog) poll(asset);
    } else throw new Error('Usage: produce.mjs balance | submit ID... | poll [ID...]');
} catch (error) {
    const message = error instanceof SyntaxError ? 'Unparseable response; raw content omitted' : String(error.message).replaceAll(key || '__NO_KEY__', '[REDACTED]');
    console.error(message.slice(0, 300));
    process.exitCode = 1;
}

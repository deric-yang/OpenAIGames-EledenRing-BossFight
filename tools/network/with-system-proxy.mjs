/** Respect the macOS PAC route without printing private routing identifiers. */
import {execFileSync, spawnSync} from 'node:child_process';
import vm from 'node:vm';
const config = execFileSync('scutil', ['--proxy'], {encoding: 'utf8'});
const url = config.match(/ProxyAutoConfigURLString : (\S+)/)?.[1];
if (!url) throw new Error('No system PAC configured');
const pac = execFileSync('curl', ['-q', '-fsS', '--max-time', '20', url], {encoding: 'utf8'});
const context = vm.createContext({
    dnsDomainIs: (host, domain) => host.endsWith(domain),
    isPlainHostName: host => !host.includes('.'),
    shExpMatch: (host, pattern) => new RegExp('^' + pattern.replaceAll('.', '\\.').replaceAll('*', '.*') + '$').test(host)
});
vm.runInContext(pac, context, {timeout: 1000});
const route = vm.runInContext('FindProxyForURL("https://openapi.tripo3d.ai", "openapi.tripo3d.ai")', context, {timeout: 1000});
const match = route.match(/^(HTTPS|PROXY) ([\w.:-]+)/);
if (!match) throw new Error('PAC did not supply an HTTP proxy route');
const proxy = (match[1] === 'HTTPS' ? 'https://' : 'http://') + match[2];
const [command, ...args] = process.argv.slice(2);
if (!command) throw new Error('A command is required');
const result = spawnSync(command, args, {stdio: 'inherit', env: {...process.env, HTTPS_PROXY: proxy, https_proxy: proxy}});
process.exitCode = result.status ?? 1;

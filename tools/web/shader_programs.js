// The web demo's shader programs (the load times on the web): serves an export locally, plays it in Chromium
// through Playwright from the title into City 1 (Play: the City's intro, then the level's load and its
// shader warm-up) and counts every shader program WebGL links on the way, with the ones linked more than
// once (the same source twice: a duplicate compile). A browser compiles each program while the game waits,
// and on Windows (ANGLE over Direct3D) one can take seconds, so the count is the web demo's load time.
//
//   node tools/web/shader_programs.js [--export=exports/web] [--quiet=60] [--out=build/browser]
//
// It stops once no program has been linked for `--quiet` seconds after the level's load began (the
// count is the same on a slow software renderer, only later). The programs, each with its time and source
// hash, go to <out>/shader_programs.json. Needs Node and Playwright with its Chromium, as browser_check.js.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const options = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith('--')).map((a) => {
	const [k, v] = a.slice(2).split('=');
	return [k, v === undefined ? true : v];
}));
const EXPORT = path.resolve(ROOT, options.export || 'exports/web');
const OUT = path.resolve(ROOT, options.out || 'build/browser');
const QUIET_MS = Number(options.quiet || 60) * 1000;
// A load this far apart from the last program is a new burst (one load, one long frame or a few).
const BURST_GAP_MS = 3000;

function loadPlaywright() {
	try {
		return require('playwright');
	} catch (e) {
		const root = require('child_process').execSync('npm root -g').toString().trim();
		return require(path.join(root, 'playwright'));
	}
}
const { chromium } = loadPlaywright();

function serve(dir) {
	const TYPES = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.png': 'image/png' };
	const server = http.createServer((req, res) => {
		const url = decodeURIComponent(req.url.split('?')[0]);
		const file = path.join(dir, url === '/' ? 'index.html' : url);
		if (!file.startsWith(dir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
			res.writeHead(404);
			res.end();
			return;
		}
		res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
		fs.createReadStream(file).pipe(res);
	});
	return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

// In the page before the engine starts: every linked program, with its time and its sources' hash. The
// material's own uniforms (Godot's MaterialUniforms block) say which look it is.
function hook() {
	const programs = (window.__programs = []);
	const proto = WebGL2RenderingContext.prototype;
	const sources = new WeakMap();
	const attached = new WeakMap();
	const hash = (s) => {
		let h = 0x811c9dc5;
		for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 0x01000193);
		return (h >>> 0).toString(16).padStart(8, '0');
	};
	const shaderSource = proto.shaderSource;
	const attachShader = proto.attachShader;
	const linkProgram = proto.linkProgram;
	proto.shaderSource = function (shader, code) {
		sources.set(shader, code);
		return shaderSource.call(this, shader, code);
	};
	proto.attachShader = function (program, shader) {
		if (!attached.has(program)) attached.set(program, []);
		attached.get(program).push(shader);
		return attachShader.call(this, program, shader);
	};
	proto.linkProgram = function (program) {
		const code = (attached.get(program) || []).map((s) => sources.get(s) || '').join('\u0000');
		const block = /MaterialUniforms[^{]*\{([^}]*)\}/.exec(code);
		const look = block ? block[1].replace(/\/\/[^\n]*/g, '').replace(/\s+/g, ' ').trim().slice(0, 120) : '';
		programs.push({ at: performance.now(), hash: hash(code), look });
		return linkProgram.call(this, program);
	};
}

(async () => {
	if (!fs.existsSync(path.join(EXPORT, 'index.html'))) {
		console.error(`No export at ${EXPORT}: tools/godot.sh web`);
		process.exit(1);
	}
	const server = await serve(EXPORT);
	const browser = await chromium.launch({
		executablePath: options.chromium || undefined,
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await browser.newPage({ viewport: { width: 640, height: 360 } });
	page.on('pageerror', (e) => console.log(`page error: ${e.message}`));
	await page.addInitScript(hook);
	await page.goto(`http://127.0.0.1:${server.address().port}/`);
	await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 600000 });
	await page.waitForTimeout(3000);
	const playAt = await page.evaluate(() => performance.now());
	await page.keyboard.press('Enter');
	console.log('Play pressed on the title; waiting for the intro and City 1 to load ...');
	// The intro's programs come first, then a pause while it plays, then the level's: done once quiet
	// after a second burst has begun.
	let programs = [];
	for (;;) {
		await page.waitForTimeout(5000);
		programs = await page.evaluate(() => window.__programs);
		const after = programs.filter((p) => p.at > playAt);
		const now = await page.evaluate(() => performance.now());
		const bursts = after.filter((p, i) => i > 0 && p.at - after[i - 1].at > BURST_GAP_MS).length + (after.length ? 1 : 0);
		if (after.length && bursts >= 2 && now - after[after.length - 1].at > QUIET_MS) break;
		if (now - playAt > 900000) {
			console.log('(stopped after 15 minutes)');
			break;
		}
	}
	await browser.close();
	server.close();

	const report = (label, list) => {
		const seen = {};
		for (const p of list) seen[p.hash] = (seen[p.hash] || 0) + 1;
		const extra = Object.values(seen).reduce((a, n) => a + n - 1, 0);
		console.log(`${label}: ${list.length} programs, ${Object.keys(seen).length} distinct, ${extra} compiled again`);
		return seen;
	};
	const before = programs.filter((p) => p.at <= playAt);
	const after = programs.filter((p) => p.at > playAt);
	report('Startup to the title', before);
	const bursts = [];
	for (const p of after) {
		if (!bursts.length || p.at - bursts[bursts.length - 1].slice(-1)[0].at > BURST_GAP_MS) bursts.push([]);
		bursts[bursts.length - 1].push(p);
	}
	// The intro's first frames come first; the level's load (its build and the warm-up) last.
	for (const b of bursts) {
		console.log(`  ${((b[0].at - playAt) / 1000).toFixed(1)} s after Play: ${b.length} programs`);
	}
	const seen = report('From Play to City 1', after);
	const twice = Object.entries(seen).filter(([, n]) => n > 1);
	for (const [h, n] of twice) {
		const look = after.find((p) => p.hash === h).look;
		console.log(`  ${n}x ${h}  ${look || '(no material uniforms)'}`);
	}
	fs.mkdirSync(OUT, { recursive: true });
	fs.writeFileSync(path.join(OUT, 'shader_programs.json'), JSON.stringify(programs.map((p) => ({
		after_play_s: +((p.at - playAt) / 1000).toFixed(2), hash: p.hash, look: p.look,
	})), null, 1));
	console.log(`Programs written to ${path.relative(ROOT, path.join(OUT, 'shader_programs.json'))}`);
})().catch((e) => {
	console.error(e);
	process.exit(1);
});

// The web demo's shader programs (the load times on the web): serves an export locally, plays it in Chromium
// through Playwright from the title into City 1 (Play: the City's intro, then the level's load and its
// shader warm-up) and counts every shader program WebGL links on the way, with the ones linked more than
// once (the same source twice: a duplicate compile). A browser compiles each program while the game waits,
// and on Windows (ANGLE over Direct3D) one can take seconds, so the count is the web demo's load time.
//
//   node tools/web/shader_programs.js [--export=exports/web] [--quiet=60] [--out=build/browser]
//   node tools/web/shader_programs.js --build --level=gangland/1 [--lanes=5] [--hold=S]
//   node tools/web/shader_programs.js --export=exports/web_debug --level=gangland/1
//   (any takes --sources: every program's GLSL goes to <out>/programs/<hash>.glsl)
//
// It stops once no program has been linked for `--quiet` seconds after the level's load began (the
// count is the same on a slow software renderer, only later). The programs, each with its time and source
// hash, go to <out>/shader_programs.json. Needs Node and Playwright with its Chromium, as browser_check.js.
//
// `--level=zone/n` (task I1) measures any campaign level, not only the demo's City 1: a debug export
// (`tools/godot.sh web --debug`, whose command-line options work) is opened on that level at once, with no
// title and no intro (as the full game's flavor, `--flavor=full_pc`: the demo's flavor sends any level
// past City 3 to its end screen), so the count is everything from the page's start to the level's load (the title
// screen's programs and the level introduction's among them). The demo's export filter leaves out the other
// zones' doodad pictures, which another zone's level needs, so `--build` exports a debug build of its own to
// exports/web_zones (needs the web export templates and an imported project: `tools/godot.sh import`; the
// Godot found by $GODOT, else godot4, `--godot=` names one): it takes those pictures out of the web preset's
// exclude_filter for that export only, and puts export_presets.cfg back as it was before anything else
// happens (also when the export fails or the run is stopped), so the file is never left edited.
// `--hold=S` keeps going S seconds after the load with the level started (the introduction's PLAY
// pressed): the programs its first moments of play compile.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const options = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith('--')).map((a) => {
	const [k, v] = a.slice(2).split('=');
	return [k, v === undefined ? true : v];
}));
const EXPORT = path.resolve(ROOT, options.build ? 'exports/web_zones' : (options.export || 'exports/web'));
const OUT =path.resolve(ROOT, options.out || 'build/browser');
const QUIET_MS = Number(options.quiet || 60) * 1000;
// A debug export opened on one level (see the header), instead of the demo played from its title.
const LEVEL = options.level || '';
const LANES = Number(options.lanes || 5);
const HOLD_MS = Number(options.hold || 0) * 1000;
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

function serve(dir, gameArgs) {
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
		if (gameArgs.length && path.basename(file) === 'index.html') {
			res.end(fs.readFileSync(file, 'utf8').replace('"args":[]', `"args":${JSON.stringify(['--', ...gameArgs])}`));
			return;
		}
		fs.createReadStream(file).pipe(res);
	});
	return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

// In the page before the engine starts: every linked program, with its time and its sources' hash. The
// material's own uniforms (Godot's MaterialUniforms block) say which look it is.
function hook(keepSources) {
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
	const records = new WeakMap();
	let current = null;
	// Time the game waits in the calls that block until a shader or program is built (compileShader and its
	// status query, linkProgram and its status query). A ROUGH figure: a browser defers compiles, so the wait is
	// charged to whichever call asks for the result first, including time spent on what was queued ahead of it,
	// and this browser's software WebGL is not a Windows machine's Direct3D. The program and character counts
	// are the solid numbers; the time needs a real Chrome or Edge on Windows.
	const shaderMs = new WeakMap();
	const timed = (name, after) => {
		const original = proto[name];
		proto[name] = function (...args) {
			const t0 = performance.now();
			const result = original.apply(this, args);
			after(args, performance.now() - t0);
			return result;
		};
	};
	timed('compileShader', ([shader], ms) => shaderMs.set(shader, (shaderMs.get(shader) || 0) + ms));
	timed('getShaderParameter', ([shader], ms) => shaderMs.set(shader, (shaderMs.get(shader) || 0) + ms));
	timed('getProgramParameter', ([program], ms) => {
		const record = records.get(program);
		if (record) record.ms += ms;
	});
	proto.linkProgram = function (program) {
		const shaders = attached.get(program) || [];
		const code = shaders.map((s) => sources.get(s) || '').join('\u0000');
		const block = /MaterialUniforms[^{]*\{([^}]*)\}/.exec(code);
		const look = block ? block[1].replace(/\/\/[^\n]*/g, '').replace(/\s+/g, ' ').trim().slice(0, 120) : '';
		const record = { at: performance.now(), hash: hash(code), look, size: code.length, draws: 0, firstDraw: 0, lastDraw: 0,
			ms: shaders.reduce((sum, s) => sum + (shaderMs.get(s) || 0), 0), code: keepSources ? code : undefined };
		programs.push(record);
		records.set(program, record);
		const t0 = performance.now();
		const result = linkProgram.call(this, program);
		record.ms += performance.now() - t0;
		return result;
	};
	// The draws each program makes (a program linked and never drawn was compiled for nothing).
	const useProgram = proto.useProgram;
	proto.useProgram = function (program) {
		current = records.get(program) || null;
		return useProgram.call(this, program);
	};
	for (const name of ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced', 'drawRangeElements']) {
		const original = proto[name];
		proto[name] = function (...args) {
			if (current) {
				const now = performance.now();
				current.draws++;
				if (!current.firstDraw) current.firstDraw = now;
				current.lastDraw = now;
			}
			return original.apply(this, args);
		};
	}
}

// --build: a debug export of the Web (demo) preset into EXPORT, the other zones' doodad pictures let through. The
// preset is edited for the export only: export_presets.cfg is put back whatever happens (the export failing, the
// run stopped with Ctrl+C), and checked to be back before the level is opened.
function buildExport() {
	const { execFileSync } = require('child_process');
	const presets = path.join(ROOT, 'export_presets.cfg');
	const original = fs.readFileSync(presets, 'utf8');
	const restore = () => {
		try {
			if (fs.readFileSync(presets, 'utf8') !== original) fs.writeFileSync(presets, original);
		} catch (e) {
			console.error(`export_presets.cfg COULD NOT BE PUT BACK: ${e.message} (git checkout export_presets.cfg)`);
		}
	};
	process.on('exit', restore);
	for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => process.exit(1));
	const edited = original.replace(/, assets\/sprites\/doodads\/\w+\.\*/g, '');
	fs.rmSync(EXPORT, { recursive: true, force: true });
	fs.mkdirSync(EXPORT, { recursive: true });
	fs.writeFileSync(presets, edited);
	console.log(`Exporting the Web (demo) preset, debug, with every zone's doodad pictures to ${path.relative(ROOT, EXPORT)} ...`);
	try {
		execFileSync(options.godot || process.env.GODOT || 'godot4',
			['--headless', '--path', ROOT, '--export-debug', 'Web (demo)', path.join(EXPORT, 'index.html')], { stdio: 'ignore' });
	} catch (e) {
		console.error(`The export failed (${e.message}). Are the web export templates installed and the project imported?`);
	} finally {
		restore();
	}
	if (fs.readFileSync(presets, 'utf8') !== original) {
		console.error('export_presets.cfg was not put back: git checkout export_presets.cfg');
		process.exit(1);
	}
}

(async () => {
	if (options.build) buildExport();
	if (!fs.existsSync(path.join(EXPORT, 'index.html'))) {
		console.error(`No export at ${EXPORT}: tools/godot.sh web`);
		process.exit(1);
	}
	// (The full game's flavor: the demo's sends every level past City 3 to its end screen.)
	const server = await serve(EXPORT, LEVEL ? [`--level=${LEVEL}`, `--lanes=${LANES}`, '--flavor=full_pc'] : []);
	const browser = await chromium.launch({
		executablePath: options.chromium || undefined,
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await browser.newPage({ viewport: { width: 640, height: 360 } });
	page.on('pageerror', (e) => console.log(`page error: ${e.message}`));
	await page.addInitScript(hook, !!options.sources);
	await page.goto(`http://127.0.0.1:${server.address().port}/`);
	await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 600000 });
	await page.waitForTimeout(3000);
	// A level opened at once has no title: everything from the page's start counts.
	const playAt = LEVEL ? -1 : await page.evaluate(() => performance.now());
	if (LEVEL) {
		console.log(`Opened on ${LEVEL} (${LANES} lanes); waiting for its load ...`);
	} else {
		await page.keyboard.press('Enter');
		console.log('Play pressed on the title; waiting for the intro and City 1 to load ...');
	}
	// The intro's programs come first, then a pause while it plays, then the level's: done once quiet
	// after a second burst has begun (a level opened at once has the one burst).
	let programs = [];
	for (;;) {
		await page.waitForTimeout(5000);
		programs = await page.evaluate(() => window.__programs);
		const after = programs.filter((p) => p.at > playAt);
		const now = await page.evaluate(() => performance.now());
		const bursts = after.filter((p, i) => i > 0 && p.at - after[i - 1].at > BURST_GAP_MS).length + (after.length ? 1 : 0);
		if (after.length && bursts >= (LEVEL ? 1 : 2) && now - after[after.length - 1].at > QUIET_MS) break;
		if (now - playAt > 900000) {
			console.log('(stopped after 15 minutes)');
			break;
		}
	}
	if (LEVEL && HOLD_MS > 0) {
		// The level started (the introduction's PLAY) and kept going: what its first moments compile.
		await page.keyboard.press('Enter');
		await page.waitForTimeout(HOLD_MS);
		programs = await page.evaluate(() => window.__programs);
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
	if (!LEVEL) report('Startup to the title', before);
	const bursts = [];
	for (const p of after) {
		if (!bursts.length || p.at - bursts[bursts.length - 1].slice(-1)[0].at > BURST_GAP_MS) bursts.push([]);
		bursts[bursts.length - 1].push(p);
	}
	// The intro's first frames come first; the level's load (its build and the warm-up) last.
	for (const b of bursts) {
		console.log(`  ${((b[0].at - playAt) / 1000).toFixed(1)} s after ${LEVEL ? 'the start' : 'Play'}: ${b.length} programs`);
	}
	const seen = report(LEVEL ? `From the start to ${LEVEL}` : 'From Play to City 1', after);
	const twice = Object.entries(seen).filter(([, n]) => n > 1);
	for (const [h, n] of twice) {
		const look = after.find((p) => p.hash === h).look;
		console.log(`  ${n}x ${h}  ${look || '(no material uniforms)'}`);
	}
	// A program that was linked and never drawn was compiled for nothing (draws are counted from the page's start).
	const idle = programs.filter((p) => p.draws === 0);
	console.log(`Never drawn: ${idle.length} of ${programs.length} programs${idle.length ? ' (' + idle.map((p) => p.hash).join(', ') + ')' : ''}`);
	const totalMs = programs.reduce((sum, p) => sum + (p.ms || 0), 0);
	const chars = programs.reduce((sum, p) => sum + p.size, 0);
	console.log(`Compiler wait: ${(totalMs / 1000).toFixed(1)} s in this browser (software WebGL; rough, see the hook's comment), ${(chars / 1e6).toFixed(1)} M characters of shader code linked`);
	fs.mkdirSync(OUT, { recursive: true });
	fs.writeFileSync(path.join(OUT, 'shader_programs.json'), JSON.stringify(programs.map((p) => ({
		after_play_s: +((p.at - playAt) / 1000).toFixed(2), hash: p.hash, look: p.look, size: p.size, draws: p.draws,
		ms: +(p.ms || 0).toFixed(1),
		first_draw_s: p.firstDraw ? +((p.firstDraw - playAt) / 1000).toFixed(2) : null,
		last_draw_s: p.lastDraw ? +((p.lastDraw - playAt) / 1000).toFixed(2) : null,
	})), null, 1));
	console.log(`Programs written to ${path.relative(ROOT, path.join(OUT, 'shader_programs.json'))}`);
	if (options.sources) {
		// --sources: each distinct program's GLSL, to find which Godot shader or material it is.
		const dir = path.join(OUT, 'programs');
		fs.mkdirSync(dir, { recursive: true });
		for (const p of programs) fs.writeFileSync(path.join(dir, `${p.hash}.glsl`), p.code.split('\u0000').join('\n//// next shader ////\n'));
		console.log(`Sources written to ${path.relative(ROOT, dir)}/`);
	}
})().catch((e) => {
	console.error(e);
	process.exit(1);
});

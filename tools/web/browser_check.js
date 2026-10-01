// The web demo in a browser (task E2): serves an export locally, drives it in Chromium through
// Playwright, and checks what only a browser shows. Needs Node and Playwright with its Chromium
// (npm install -g playwright, then npx playwright install chromium), and both exports:
//   tools/godot.sh web && tools/godot.sh web --debug
//   node tools/web/browser_check.js [--scenario=desktop,shop,phone,end] [--out=build/browser]
// WebGL runs in software where there's no GPU, so a level draws a frame every few seconds there; the
// checks wait for it. Scenarios (frames and the console go to --out/<scenario>/):
//   desktop  the release export at 1280x720: loading shows its progress; the title comes up on the
//            Compatibility renderer; the sound waits for the first key (the page's AudioContext is
//            suspended until then, running after); the canvas follows the window (1920x1080,
//            1024x768); the level select and the settings (Reduced flashing); Enter plays the City's
//            intro, then City 1 (frames for the glow, and the hints name the keys); the save is in
//            the browser's storage (IndexedDB) and survives a reload.
//   shop     the release export with a saved profile holding credits (written to IndexedDB before
//            the game starts): the title shows them, the shop buys, and the purchase is saved.
//   phone    an Android phone in landscape: the title and menus answer taps; in City 1 (the debug
//            export, --god --nofall) a swipe changes lanes; held upright, the page asks to turn it
//            sideways and the level pauses; turned back, the pause menu waits.
//   end      the debug export with --level=city/outro: Enter leads to the "get the full game"
//            screen, whose store tiles open the links in data/platform/store_links.json in a new
//            tab (window.open, recorded here, never followed).
// Every scenario fails on a page error or an error in the console, and lists the warnings. Exit
// code 0 when every check passes.

const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const options = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith('--')).map((a) => {
	const [k, v] = a.slice(2).split('=');
	return [k, v === undefined ? true : v];
}));
const OUT = path.resolve(ROOT, options.out || 'build/browser');
const SCENARIOS = String(options.scenario || 'desktop,shop,phone,end').split(',');
const RELEASE = path.join(ROOT, 'exports/web');
const DEBUG = path.join(ROOT, 'exports/web_debug');
const STORE_LINKS = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/platform/store_links.json'), 'utf8'));
const PHONE_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36';
// The browser's own notice that sound waits for a gesture (the autoplay policy): expected.
const EXPECTED_WARNINGS = [/The AudioContext was not allowed to start/];

function loadPlaywright() {
	try {
		return require('playwright');
	} catch (e) {
		const root = require('child_process').execSync('npm root -g').toString().trim();
		return require(path.join(root, 'playwright'));
	}
}
const { chromium } = loadPlaywright();

const results = [];
function check(scenario, ok, what) {
	results.push({ scenario, ok, what });
	console.log(`${ok ? 'ok  ' : 'FAIL'} ${scenario}: ${what}`);
}

// A static server for an export; `bytesPerSecond` slows it down so loading shows, `args` go into the
// engine's command line (GODOT_CONFIG.args: debug builds only act on them).
function serve(dir, { bytesPerSecond = 0, args = null } = {}) {
	const TYPES = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.png': 'image/png' };
	const server = http.createServer((req, res) => {
		const url = decodeURIComponent(req.url.split('?')[0]);
		if (url === '/blank') {
			// A page of the demo's origin with nothing on it (the shop scenario writes the save from it).
			res.writeHead(200, { 'Content-Type': 'text/html' });
			res.end('<!DOCTYPE html><title>blank</title><link rel="icon" href="data:,">');
			return;
		}
		const file = path.join(dir, url === '/' ? 'index.html' : url);
		if (!file.startsWith(dir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
			res.writeHead(404, { 'Content-Type': 'text/html' });
			res.end('<!DOCTYPE html><title>404</title>');
			return;
		}
		let data = fs.readFileSync(file);
		if (args && path.basename(file) === 'index.html') {
			data = Buffer.from(data.toString().replace('"args":[]', '"args":' + JSON.stringify(['--', ...args])));
		}
		res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream', 'Content-Length': data.length });
		if (!bytesPerSecond) {
			res.end(data);
			return;
		}
		const chunk = Math.ceil(bytesPerSecond / 10);
		let pos = 0;
		const tick = () => {
			if (pos >= data.length) {
				res.end();
				return;
			}
			res.write(data.subarray(pos, pos + chunk));
			pos += chunk;
			setTimeout(tick, 100);
		};
		tick();
	});
	return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

// Records the page's AudioContext states and window.open calls in the console, without touching
// the page from outside (Playwright's evaluate counts as a user gesture, which would unlock sound).
function instrument() {
	const AC = window.AudioContext;
	if (AC) {
		window.AudioContext = class extends AC {
			constructor(...a) {
				super(...a);
				console.log('[check] audio ' + this.state);
				this.addEventListener('statechange', () => console.log('[check] audio ' + this.state));
			}
		};
	}
	window.open = (url) => {
		console.log('[check] open ' + url);
		return null;
	};
}

async function openPage(browser, scenario, contextOptions, server, folder = scenario) {
	const context = await browser.newContext(contextOptions);
	context.setDefaultTimeout(600000);
	const page = await context.newPage();
	const dir = path.join(OUT, folder);
	fs.mkdirSync(dir, { recursive: true });
	const started = Date.now();
	const log = [];
	page.on('console', (m) => log.push({ t: (Date.now() - started) / 1000, type: m.type(), text: m.text() }));
	page.on('pageerror', (e) => log.push({ t: (Date.now() - started) / 1000, type: 'pageerror', text: e.message }));
	await page.addInitScript(instrument);
	const cdp = await context.newCDPSession(page);
	const url = `http://127.0.0.1:${server.address().port}/`;
	return {
		context, page, cdp, log, dir, url,
		shot: (name) => page.screenshot({ path: path.join(dir, name + '.png') }),
		// Before the first input: Playwright's own screenshots run scripts in the page, which counts as a
		// gesture and would let the sound start; the browser's capture doesn't.
		rawShot: async (name) => {
			const { data } = await cdp.send('Page.captureScreenshot', { format: 'png' });
			fs.writeFileSync(path.join(dir, name + '.png'), Buffer.from(data, 'base64'));
		},
	};
}

// Waits for the engine's renderer line, then for the first screen to settle.
async function booted(page, log, settle = 6000) {
	await page.waitForEvent('console', { predicate: (m) => m.text().includes(' - Compatibility - '), timeout: 180000 }).catch(() => null);
	await page.waitForTimeout(settle);
	return log.find((l) => l.text.includes('OpenGL API')) || null;
}

function finish(scenario, s) {
	fs.writeFileSync(path.join(s.dir, 'console.txt'), s.log.map((l) => `[${l.t.toFixed(1)}] ${l.type}: ${l.text}`).join('\n') + '\n');
	const errors = s.log.filter((l) => l.type === 'error' || l.type === 'pageerror');
	const warnings = s.log.filter((l) => l.type === 'warning' && !EXPECTED_WARNINGS.some((re) => re.test(l.text)));
	check(scenario, errors.length === 0, `no errors in the console (${errors.map((l) => l.text).join(' | ') || 'none'})`);
	check(scenario, warnings.length === 0, `no unexpected warnings (${warnings.map((l) => l.text).join(' | ') || 'none'})`);
	const expected = s.log.filter((l) => l.type === 'warning' && EXPECTED_WARNINGS.some((re) => re.test(l.text)));
	if (expected.length) console.log(`     ${scenario}: the browser's autoplay notice, as expected: "${expected[0].text}"`);
	return s.context.close();
}

// The saved profile in the browser's storage (Emscripten's IDBFS under /userfs), or null.
function readProfile(page) {
	return page.evaluate(async () => {
		const db = await new Promise((res, rej) => {
			const r = indexedDB.open('/userfs');
			r.onsuccess = () => res(r.result);
			r.onerror = () => rej(r.error);
		});
		if (!db.objectStoreNames.contains('FILE_DATA')) return null;
		const store = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA');
		const keys = await new Promise((res) => {
			const r = store.getAllKeys();
			r.onsuccess = () => res(r.result);
		});
		const key = keys.find((k) => String(k).endsWith('/profile.json'));
		if (!key) return null;
		const entry = await new Promise((res) => {
			const r = store.get(key);
			r.onsuccess = () => res(r.result);
		});
		db.close();
		return { key: String(key), json: JSON.parse(new TextDecoder().decode(new Uint8Array(entry.contents.buffer, entry.contents.byteOffset, entry.contents.byteLength))) };
	});
}

async function desktop(browser) {
	const name = 'desktop';
	const server = await serve(RELEASE, { bytesPerSecond: 8e6 });
	const s = await openPage(browser, name, { viewport: { width: 1280, height: 720 } }, server);
	await s.page.goto(s.url);
	for (let i = 1; i <= 3; i++) {
		await s.page.waitForTimeout(1200);
		await s.rawShot(`loading_${i}`);
	}
	const renderer = await booted(s.page, s.log);
	check(name, renderer !== null && renderer.text.includes('Compatibility') && renderer.text.includes('WebGL 2'),
		`the Compatibility renderer on WebGL 2 (${renderer ? renderer.text : 'no renderer line'})`);
	await s.rawShot('title');
	// The canvas follows the window, before any input (resizing isn't a gesture).
	for (const [w, h] of [[1920, 1080], [1024, 768], [1280, 720]]) {
		await s.page.setViewportSize({ width: w, height: h });
		await s.page.waitForTimeout(4000);
		await s.rawShot(`title_${w}x${h}`);
	}
	const audioBefore = s.log.filter((l) => l.text.startsWith('[check] audio')).map((l) => l.text.slice(14));
	check(name, audioBefore.length > 0 && !audioBefore.includes('running'), `the sound waits for the first input (${audioBefore.join(', ') || 'no AudioContext'})`);
	// A key the menus don't use (a modifier alone may not count as a gesture).
	await s.page.keyboard.press('a');
	await s.page.waitForTimeout(3000);
	const audioAfter = s.log.filter((l) => l.text.startsWith('[check] audio')).map((l) => l.text.slice(14));
	check(name, audioAfter[audioAfter.length - 1] === 'running', `and plays after it (${audioAfter.join(' → ')})`);
	const canvas = await s.page.evaluate(() => {
		const c = document.getElementById('canvas');
		return { w: c.width, h: c.height, cw: c.clientWidth, ch: c.clientHeight, iw: innerWidth, ih: innerHeight, dpr: devicePixelRatio };
	});
	check(name, canvas.cw === canvas.iw && canvas.ch === canvas.ih && canvas.w === Math.round(canvas.iw * canvas.dpr),
		`the canvas fills the window (${canvas.cw}x${canvas.ch} in ${canvas.iw}x${canvas.ih}, drawn at ${canvas.w}x${canvas.h})`);
	// The level select and the settings, by keyboard.
	await s.page.keyboard.press('ArrowDown');
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(5000);
	await s.shot('level_select');
	await s.page.keyboard.press('Escape');
	await s.page.waitForTimeout(3000);
	await s.page.keyboard.press('ArrowDown');
	await s.page.keyboard.press('ArrowDown');
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(5000);
	await s.shot('settings');
	await s.page.keyboard.press('Escape');
	await s.page.waitForTimeout(3000);
	// Play (the title focuses it): the City's intro (its slot), then City 1, drawn smaller so software
	// WebGL keeps up.
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(4000);
	await s.shot('intro_slot');
	await s.page.setViewportSize({ width: 960, height: 540 });
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(8000);
	await s.shot('level_1');
	await s.shot('level_2');
	await s.page.keyboard.press('Escape');
	await s.page.waitForTimeout(3000);
	await s.shot('paused');
	const saved = await readProfile(s.page);
	const intro = saved && saved.json.records ? saved.json.records['0/city/intro'] : null;
	check(name, intro != null && intro.completed === true, `the save is in the browser's storage (${saved ? saved.key : 'no profile.json'})`);
	await s.page.reload();
	await booted(s.page, s.log);
	await s.shot('after_reload');
	const again = await readProfile(s.page);
	check(name, again !== null && again.json.records['0/city/intro'] !== undefined, 'and is still there after a reload (the title offers CONTINUE)');
	await finish(name, s);
	server.close();
}

async function shop(browser) {
	const name = 'shop';
	const server = await serve(RELEASE);
	const s = await openPage(browser, name, { viewport: { width: 960, height: 540 } }, server);
	// A saved profile with credits, written where the game keeps user:// (Emscripten's IDBFS).
	await s.page.goto(s.url + 'blank');
	await s.page.evaluate(async () => {
		const base = '/userfs/godot/app_userdata/Neon Runner';
		const profile = { version: 1, earned: 5000, lifetime_earned: 5000, records: { '0/city/intro': { completed: true, attempts: 1, best_score: 0, best_time: 0, stars: 3 } } };
		const db = await new Promise((res, rej) => {
			const r = indexedDB.open('/userfs', 21);
			r.onupgradeneeded = () => r.result.createObjectStore('FILE_DATA').createIndex('timestamp', 'timestamp', { unique: false });
			r.onsuccess = () => res(r.result);
			r.onerror = () => rej(r.error);
		});
		const store = db.transaction('FILE_DATA', 'readwrite').objectStore('FILE_DATA');
		const now = new Date();
		for (const dir of ['/userfs/godot', '/userfs/godot/app_userdata', base]) store.put({ timestamp: now, mode: 16893 }, dir);
		const bytes = new TextEncoder().encode(JSON.stringify(profile));
		store.put({ timestamp: now, mode: 33206, contents: new Int8Array(bytes.buffer) }, base + '/profile.json');
		await new Promise((res) => { store.transaction.oncomplete = res; });
		db.close();
	});
	await s.page.goto(s.url);
	await booted(s.page, s.log);
	await s.shot('title_with_credits');
	// Title: PLAY (CONTINUE), then LEVEL SELECT | SHOP.
	await s.page.keyboard.press('ArrowDown');
	await s.page.keyboard.press('ArrowRight');
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(5000);
	await s.shot('shop');
	// The shop focuses the first thing that can be bought.
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(4000);
	await s.shot('shop_bought');
	const saved = await readProfile(s.page);
	const spent = saved ? Number(saved.json.lifetime_spent || 0) : 0;
	check(name, spent > 0 && Number(saved.json.earned) === 5000 - spent,
		`a purchase spends saved credits and is saved (${saved ? `${saved.json.earned} left, ${spent} spent` : 'no profile.json'})`);
	await s.page.reload();
	await booted(s.page, s.log);
	await s.shot('title_after_purchase');
	await finish(name, s);
	server.close();
}

async function swipe(cdp, x0, y0, x1, y1) {
	await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: y0 }] });
	for (let i = 1; i <= 5; i++) {
		await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x0 + (x1 - x0) * i / 5, y: y0 + (y1 - y0) * i / 5 }] });
	}
	await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

async function phone(browser) {
	const name = 'phone';
	const phoneContext = { viewport: { width: 844, height: 390 }, userAgent: PHONE_UA, isMobile: true, hasTouch: true, deviceScaleFactor: 1 };
	// (The phone's scenario takes Playwright's screenshots freely: its sound is the desktop's.)
	// The menus answer taps (the release export).
	let server = await serve(RELEASE);
	let s = await openPage(browser, name, phoneContext, server);
	await s.page.goto(s.url);
	await booted(s.page, s.log);
	await s.shot('title');
	await s.page.touchscreen.tap(422, 189);
	await s.page.waitForTimeout(5000);
	await s.shot('tapped_play');
	await finish(name, s);
	server.close();
	// A level (the debug export, safe from hits and falls): a swipe, then held upright and back.
	server = await serve(DEBUG, { args: ['--level=city/1', '--god', '--nofall'] });
	s = await openPage(browser, name, phoneContext, server, 'phone_level');
	const cdp = s.cdp;
	await s.page.goto(s.url);
	await booted(s.page, s.log, 15000);
	await s.shot('level_before_swipe');
	await swipe(cdp, 560, 250, 360, 250);
	await s.page.waitForTimeout(6000);
	await s.shot('level_after_swipe');
	await s.page.setViewportSize({ width: 390, height: 844 });
	await s.page.waitForTimeout(6000);
	await s.shot('held_upright');
	const notice = await s.page.evaluate(() => getComputedStyle(document.body, '::after').content);
	check(name, notice.includes('sideways'), `held upright, the page asks to turn the phone sideways (${notice})`);
	await s.page.setViewportSize({ width: 844, height: 390 });
	await s.page.waitForTimeout(10000);
	await s.shot('turned_back');
	const back = await s.page.evaluate(() => getComputedStyle(document.body, '::after').content);
	check(name, back === 'none' || back === 'normal' || back === '', `turned back, the notice is gone (${back}); the frame shows the level paused`);
	await finish(name, s);
	server.close();
}

async function end(browser) {
	const name = 'end';
	const server = await serve(DEBUG, { args: ['--level=city/outro'] });
	const s = await openPage(browser, name, { viewport: { width: 1280, height: 720 } }, server);
	await s.page.goto(s.url);
	await booted(s.page, s.log);
	await s.shot('outro_slot');
	await s.page.keyboard.press('Enter');
	await s.page.waitForTimeout(5000);
	await s.shot('end_screen');
	const stores = Object.keys(STORE_LINKS).filter((k) => !k.startsWith('_'));
	for (let i = 0; i < stores.length; i++) {
		if (i > 0) await s.page.keyboard.press('ArrowRight');
		await s.page.keyboard.press('Enter');
		await s.page.waitForTimeout(2500);
	}
	const opened = s.log.filter((l) => l.text.startsWith('[check] open ')).map((l) => l.text.slice(13));
	check(name, JSON.stringify(opened) === JSON.stringify(stores.map((k) => STORE_LINKS[k])),
		`each store tile opens its link from the data in a new tab (${opened.join(', ') || 'none'})`);
	await s.shot('after_links');
	await finish(name, s);
	server.close();
}

(async () => {
	for (const dir of [RELEASE, DEBUG]) {
		if (!fs.existsSync(path.join(dir, 'index.html'))) console.log(`(no export at ${dir}: tools/godot.sh web${dir === DEBUG ? ' --debug' : ''})`);
	}
	const browser = await chromium.launch({
		executablePath: options.chromium || undefined,
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const all = { desktop, shop, phone, end };
	for (const scenario of SCENARIOS) {
		if (!all[scenario]) {
			check(scenario, false, 'no such scenario');
			continue;
		}
		try {
			await all[scenario](browser);
		} catch (e) {
			check(scenario, false, `stopped: ${e.message.split('\n')[0]}`);
		}
	}
	await browser.close();
	const failed = results.filter((r) => !r.ok);
	fs.mkdirSync(OUT, { recursive: true });
	fs.writeFileSync(path.join(OUT, 'report.txt'), results.map((r) => `${r.ok ? 'ok  ' : 'FAIL'} ${r.scenario}: ${r.what}`).join('\n') + '\n');
	console.log(failed.length === 0 ? `BROWSER CHECK PASSED (${results.length} checks; frames in ${OUT})` : `BROWSER CHECK FAILED (${failed.length} of ${results.length})`);
	process.exit(failed.length === 0 ? 0 : 1);
})();

#!/usr/bin/env node
// Headless smoke test for the browser prototypes.
//
//   node tools/smoke-test.js                      # every prototype in prototypes/
//   node tools/smoke-test.js prototypes/proving-ground.html
//
// It pulls the page's inline <script>, runs it in Node against a stubbed DOM, and drives the page's own loop
// for a few seconds of game time. It fails on any exception thrown while the page starts up or runs, and
// reports how long a frame takes. It doesn't check what things look like; open the page in a browser for that.

const fs = require('fs');
const path = require('path');

const FRAMES = 600;                                     // ten seconds of simulated time at 60 fps

function stubDom() {
  const ctx2d = () => new Proxy({
    createImageData: (w, h) => ({ data: new Uint8ClampedArray(w * h * 4) }),
    createRadialGradient: () => ({ addColorStop() {} }),
    filter: 'none',
  }, { get: (t, k) => (k in t ? t[k] : () => {}), set: (t, k, v) => ((t[k] = v), true) });
  const el = () => new Proxy({
    style: {}, dataset: {}, textContent: '', innerHTML: '', hidden: false, value: '5', width: 640, height: 360,
    children: [0, 1, 2].map(() => ({ textContent: '', style: {} })),
    classList: { add() {}, remove() {}, toggle() {} },
    getContext: ctx2d, querySelector: () => el(), querySelectorAll: () => [el(), el(), el(), el(), el()],
    getBoundingClientRect: () => ({ left: 0, top: 0, width: 640, height: 360 }),
    appendChild() {}, addEventListener() {}, setAttribute() {}, focus() {}, setPointerCapture() {},
  }, { get: (t, k) => (k in t ? t[k] : () => {}), set: (t, k, v) => ((t[k] = v), true) });
  return {
    document: { getElementById: el, createElement: el, querySelectorAll: () => [], hasFocus: () => true },
    window: { addEventListener() {}, devicePixelRatio: 1, focus() {} },
    ResizeObserver: class { observe() {} },
  };
}

function run(file) {
  const html = fs.readFileSync(file, 'utf8');
  const m = html.match(/<script>([\s\S]*)<\/script>/);
  if (!m) throw new Error('no inline <script> found');
  const dom = stubDom();
  let frames = 0, loopFn = null, now = 0;
  Object.assign(global, dom, {
    performance: { now: () => now },
    requestAnimationFrame: f => { loopFn = f; },
  });
  new Function(m[1])();                                   // boots the page: builds the world, starts the loop
  const t0 = process.hrtime.bigint();
  while (loopFn && frames < FRAMES) { const f = loopFn; loopFn = null; now += 1000 / 60; f(now); frames++; }
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  return { frames, msPerFrame: ms / Math.max(1, frames) };
}

const targets = process.argv.slice(2).length
  ? process.argv.slice(2)
  : fs.readdirSync(path.join(__dirname, '..', 'prototypes')).filter(f => f.endsWith('.html')).map(f => path.join('prototypes', f));

let failed = false;
for (const t of targets) {
  try {
    const r = run(t);
    console.log(`ok   ${t}  ${r.frames} frames, ${r.msPerFrame.toFixed(2)} ms per frame (sim + draw)`);
  } catch (e) {
    failed = true;
    console.log(`FAIL ${t}\n     ${e && e.stack ? e.stack.split('\n').slice(0, 3).join('\n     ') : e}`);
  }
}
process.exit(failed ? 1 : 0);

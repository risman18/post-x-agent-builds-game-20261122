// Capture real gameplay frames from game.html via Chrome DevTools Protocol.
// Node 22+ stdlib only (global WebSocket). Usage:
//   node capture.mjs <seconds> <outdir>
// Chrome must already be running with --remote-debugging-port=9222 and the
// game page open. Saves screencast JPEG frames + prints the final game state.
import { writeFileSync, mkdirSync } from 'node:fs';

const seconds = Number(process.argv[2] ?? 13);
const outdir = process.argv[3] ?? 'frames';
mkdirSync(outdir, { recursive: true });

const list = await fetch('http://127.0.0.1:9222/json/list').then(r => r.json());
const page = list.find(t => t.type === 'page');
if (!page) { console.error('no page target'); process.exit(1); }
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

let id = 0;
const pending = new Map();
const frames = [];
let frameCount = 0;
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result); pending.delete(msg.id); }
  if (msg.method === 'Page.screencastFrame') {
    const { data, sessionId } = msg.params;
    frameCount++;
    writeFileSync(`${outdir}/frame-${String(frameCount).padStart(4, '0')}.jpg`, Buffer.from(data, 'base64'));
    ws.send(JSON.stringify({ id: ++id, method: 'Page.screencastFrameAck', params: { sessionId } }));
  }
};
function send(method, params = {}) {
  return new Promise((resolve) => {
    const mid = ++id;
    pending.set(mid, resolve);
    ws.send(JSON.stringify({ id: mid, method, params }));
  });
}

await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false });
await send('Page.reload', { ignoreCache: true });
await new Promise(r => setTimeout(r, 1500));
await send('Runtime.evaluate', { expression: `location.href.includes('game.html')` });
await send('Page.startScreencast', { format: 'jpeg', quality: 80, everyNthFrame: 1 });
console.log(`recording ${seconds}s of gameplay...`);
await new Promise(r => setTimeout(r, seconds * 1000));
await send('Page.stopScreencast');
const state = await send('Runtime.evaluate', {
  expression: `JSON.stringify({ score: window.__meteorDodge.score(), stars: window.__meteorDodge.stars(), lives: window.__meteorDodge.lives(), timeLeft: Math.round(window.__meteorDodge.timeLeft()), over: window.__meteorDodge.over() })`,
  returnByValue: true,
});
console.log('frames:', frameCount);
console.log('game state at end:', state?.result?.value);
ws.close();
process.exit(0);

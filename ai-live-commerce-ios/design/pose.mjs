// 花奈(VRM)にポーズを付けて、透過 PNG に書き出す。使い方: node pose.mjs pose.json out.png
import { chromium } from 'playwright-core';
import fs from 'node:fs';
const [poseFile, out] = process.argv.slice(2);
const pose = JSON.parse(fs.readFileSync(poseFile, 'utf8'));
const BASE = process.env.BASE || 'http://127.0.0.1:8000';
setTimeout(() => { console.log('HARD TIMEOUT'); process.exit(2); }, 150000);
const html = `<!doctype html><html><head><meta charset="utf-8">
<script type="importmap">{"imports":{"three":"/static/vendor/three/build/three.module.js","three/addons/":"/static/vendor/three/examples/jsm/","@pixiv/three-vrm":"/static/vendor/three-vrm/three-vrm.module.js"}}</script>
</head><body style="margin:0;background:transparent"><canvas id="c" width="1024" height="1024" style="width:1024px;height:1024px"></canvas>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { VRMLoaderPlugin, VRMUtils } from '@pixiv/three-vrm';
const P = ${JSON.stringify(pose)};
const renderer = new THREE.WebGLRenderer({ canvas: document.getElementById('c'), alpha: true, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(2); renderer.setSize(1024, 1024, false);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(P.camera.fov, 1, 0.1, 20);
scene.add(new THREE.AmbientLight(0xfffaf3, 1.25));
const key = new THREE.DirectionalLight(0xfff1e2, 1.35); key.position.set(0.8, 1.8, 2.4); scene.add(key);
const rim = new THREE.DirectionalLight(0xf3f0ea, 0.5); rim.position.set(-1.6, 1.4, -1.6); scene.add(rim);
const loader = new GLTFLoader(); loader.register(p => new VRMLoaderPlugin(p));
loader.load('/static/models/hana.vrm', (gltf) => {
  const vrm = gltf.userData.vrm;
  if (vrm.meta && (vrm.meta.metaVersion === '0' || vrm.meta.metaVersion === 0)) VRMUtils.rotateVRM0(vrm);
  vrm.scene.traverse(o => { o.frustumCulled = false; });
  scene.add(vrm.scene);
  const H = vrm.humanoid; const missing = [];
  for (const [name, r] of Object.entries(P.bones)) {
    const n = H.getNormalizedBoneNode(name);
    if (!n) { missing.push(name); continue; }
    n.rotation.set(r[0], r[1], r[2]);
  }
  for (const [k, v] of Object.entries(P.expressions || {})) vrm.expressionManager && vrm.expressionManager.setValue(k, v);
  if (P.sceneRotY) vrm.scene.rotation.y = P.sceneRotY;
  for (let i = 0; i < 90; i++) vrm.update(1 / 30);          // 揺れもの(髪)を落ち着かせる
  const head = H.getNormalizedBoneNode('head'); const hp = new THREE.Vector3(); head.getWorldPosition(hp);
  const ty = hp.y + P.camera.dy;
  camera.position.set(P.camera.x, ty + P.camera.up, P.camera.dist);
  camera.lookAt(P.camera.tx || 0, ty, 0);
  renderer.render(scene, camera);
  window.__missing = missing; window.__done = true;
}, undefined, (e) => { window.__error = String(e); });
</script></body></html>`;
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1024, height: 1100 }, deviceScaleFactor: 2 });
page.on('pageerror', e => console.log('PAGEERROR', String(e)));
await page.route('**/__pose.html', r => r.fulfill({ contentType: 'text/html', body: html }));
await page.goto(BASE + '/__pose.html', { waitUntil: 'commit' });
await page.waitForFunction(() => window.__done || window.__error, null, { timeout: 120000 });
console.log('missing bones:', JSON.stringify(await page.evaluate(() => window.__missing)), 'error:', await page.evaluate(() => window.__error || null));
await page.locator('#c').screenshot({ path: out, omitBackground: true });
await browser.close(); process.exit(0);

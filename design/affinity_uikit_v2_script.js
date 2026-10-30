// Arrow Crush UI kit v2 - generated in Affinity. (lib.js is prepended.)
const { ArtTextNodeDefinition } = require('/nodes.js');
const { StoryBuilder } = require('/storybuilder.js');
const { StoryDelta } = require('/storydelta.js');
const { Font, FontWeight, FontWidth, FontField } = require('/fonts.js');
const { GlyphAttDoubleType } = require('affinity:story');
const { DocumentCommand } = require('/commands.js');

const W = 1600, H = 2240;
const opts = NewDocumentOptions.createDefault();
opts.units = UnitType.Pixel; opts.width = W; opts.height = H; opts.dpi = 72; opts.createArtboard = true;
const doc = Document.create(opts);
const NONE = FillDescriptor.createNone();
const NOLINE = LineStyleDescriptor.createDefault(0);
let count = 0;

// ---------- primitives ----------
const { NodeChildType } = require('/nodes.js');
function add(def) { const b = AddChildNodesCommandBuilder.create(); b.addNode(def); const c = b.createCommand(true, NodeChildType.Main); doc.executeCommand(c); count++; return c; }
function fillShape(pc, color, a = 255) { return add(PolyCurveNodeDefinition.create(pc, FillDescriptor.createSolid(hex(color, a)), NONE, NOLINE, NONE)); }
function strokePath(pts, w, color, a = 255, dx = 0, dy = 0) {
  const p = pts.map(q => [q[0] + dx, q[1] + dy]);
  const ls = LineStyleDescriptor.create(LineStyle.create({ weight: w, cap: LineCap.Round, join: LineJoin.Round }));
  return add(PolyCurveNodeDefinition.create(curveOf(p, false), NONE, FillDescriptor.createSolid(hex(color, a)), ls, NONE));
}
function poly(pts, color, a = 255, dx = 0, dy = 0) { return fillShape(curveOf(pts.map(q => [q[0] + dx, q[1] + dy]), true), color, a); }
const K = 0.5523;
function rrectCurve(x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  return curveFromBuilder(cb => {
    cb.beginXY(x + r, y); cb.lineToXY(x + w - r, y);
    cb.addBezierXY(x + w - r + r * K, y, x + w, y + r - r * K, x + w, y + r);
    cb.lineToXY(x + w, y + h - r);
    cb.addBezierXY(x + w, y + h - r + r * K, x + w - r + r * K, y + h, x + w - r, y + h);
    cb.lineToXY(x + r, y + h);
    cb.addBezierXY(x + r - r * K, y + h, x, y + h - r + r * K, x, y + h - r);
    cb.lineToXY(x, y + r);
    cb.addBezierXY(x, y + r - r * K, x + r - r * K, y, x + r, y);
    cb.close();
  });
}
function rrect(x, y, w, h, r, color, a = 255) { return fillShape(rrectCurve(x, y, w, h, r), color, a); }
function circleCurve(cx, cy, r) { return rrectCurve(cx - r, cy - r, r * 2, r * 2, r); }
function circle(cx, cy, r, color, a = 255) { return fillShape(circleCurve(cx, cy, r), color, a); }
function starPts(cx, cy, r, inner = 0.45) { const P = []; for (let i = 0; i < 10; i++) { const ang = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * inner : r; P.push([cx + Math.cos(ang) * rr, cy + Math.sin(ang) * rr]); } return P; }

// ---------- text ----------
function text(str, x, baseline, size, color, opt = {}) {
  const sb = StoryBuilder.create();
  sb.setToArtisticTextDefaultStyle(doc.dpi, doc.format);
  const font = Font.create(opt.family || 'Segoe UI', opt.weight ?? FontWeight.Black, false, FontWidth.Normal);
  sb.applyGlyphDelta(StoryDelta.createFont(FontField.FamilyName.value | FontField.Weight.value, font));
  sb.applyGlyphDelta(StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, size));
  if (opt.spacing) sb.applyGlyphDelta(StoryDelta.createGlyphDouble(GlyphAttDoubleType.CharacterSpacing, opt.spacing));
  sb.applyGlyphDelta(StoryDelta.createBrushFill(FillDescriptor.createSolid(hex(color))));
  sb.addText(str);
  const cmd = add(ArtTextNodeDefinition.createFromStoryBuilder({ x, y: baseline }, sb));
  if (opt.center != null) {
    try {
      const node = cmd.newNodes[0];
      const bb = node.getSpreadBaseBox();
      const dx = opt.center - (bb.x + bb.width / 2);
      doc.executeCommand(DocumentCommand.createTransform(Selection.create(doc, node), Transform.createTranslate(dx, 0)));
    } catch (e) { console.log('center fail', e.message); }
  }
  return cmd;
}

// ---------- palette ----------
const P = { ruby: '#e11d48', blue: '#2563eb', emerald: '#059669', amber: '#d97706', violet: '#7c3aed', teal: '#0891b2', gold: '#eab308' };
function mix(h, to, t) {
  const n = parseInt(h.slice(1), 16), a = [n >> 16 & 255, n >> 8 & 255, n & 255];
  const b = to === 'w' ? [255, 255, 255] : [25, 10, 60];
  return '#' + a.map((v, i) => Math.round(v + (b[i] - v) * t).toString(16).padStart(2, '0')).join('');
}

// ---------- the arrow ----------
// cells: centres tail -> head in px. state: rest | press | flash
function arrow(cells, color, cell, o = {}) {
  const w = cell * 0.27 * (o.state === 'press' ? 0.92 : 1);
  const base = o.state === 'press' ? mix(color, 'w', 0.12) : color;
  const t0 = cells[0], t1 = cells[1];
  const tl = Math.hypot(t1[0] - t0[0], t1[1] - t0[1]);
  const td = [(t1[0] - t0[0]) / tl, (t1[1] - t0[1]) / tl], tn = [-td[1], td[0]];
  const pts = [[t0[0] - td[0] * cell * 0.32 + (o.shift?.[0] || 0) * 0, t0[1] - td[1] * cell * 0.32]].concat(cells.slice());
  const hN = cells.length - 1, hp = cells[hN], pp = cells[hN - 1];
  const hl = Math.hypot(hp[0] - pp[0], hp[1] - pp[1]); const d = [(hp[0] - pp[0]) / hl, (hp[1] - pp[1]) / hl], n = [-d[1], d[0]];
  const end = [hp[0] + d[0] * cell * 0.1, hp[1] + d[1] * cell * 0.1];
  pts[pts.length - 1] = end;
  const head = (sc) => {
    const hw = cell * 0.3 * sc, len = cell * 0.44 * sc;
    const tip = [end[0] + d[0] * len * 0.72, end[1] + d[1] * len * 0.72];
    const back = [end[0] - d[0] * len * 0.28, end[1] - d[1] * len * 0.28];
    const notch = [end[0] - d[0] * len * 0.08, end[1] - d[1] * len * 0.08];
    return [tip, [back[0] + n[0] * hw, back[1] + n[1] * hw], notch, [back[0] - n[0] * hw, back[1] - n[1] * hw]];
  };
  const sx = cell * 0.035, sy = cell * 0.08;
  // shadow on the tray
  strokePath(pts, w + cell * 0.06, '#28146e', 52, sx, sy);
  poly(head(1.1), '#28146e', 52, sx, sy);
  // fletching
  const tail = pts[0];
  for (const s of [1, -1]) {
    const f = [
      [tail[0] + td[0] * cell * 0.34 + tn[0] * s * w * 0.45, tail[1] + td[1] * cell * 0.34 + tn[1] * s * w * 0.45],
      [tail[0] + td[0] * cell * 0.12 + tn[0] * s * w * 1.4, tail[1] + td[1] * cell * 0.12 + tn[1] * s * w * 1.4],
      [tail[0] - td[0] * cell * 0.1 + tn[0] * s * w * 1.3, tail[1] - td[1] * cell * 0.1 + tn[1] * s * w * 1.3],
      [tail[0] + td[0] * cell * 0.06 + tn[0] * s * w * 0.3, tail[1] + td[1] * cell * 0.06 + tn[1] * s * w * 0.3],
    ];
    poly(f, mix(color, 'k', 0.35));
    poly(f, mix(color, 'w', 0.38), 255, 0, -cell * 0.02);
  }
  // flash ring under everything coloured
  if (o.state === 'flash') { strokePath(pts, w + cell * 0.2, '#ef4444', 230); poly(head(1.3), '#ef4444', 230); }
  // rim, body, underside, gloss
  strokePath(pts, w + cell * 0.07, mix(color, 'k', 0.4));
  strokePath(pts, w, base);
  strokePath(pts, w * 0.45, mix(color, 'k', 0.14), 255, 0, w * 0.2);
  strokePath(pts, w * 0.26, '#ffffff', 150, -w * 0.06, -w * 0.21);
  // head
  poly(head(1.14), mix(color, 'k', 0.4));
  poly(head(0.94), base);
  const h2 = head(0.94);
  strokePath([h2[0], h2[1]], cell * 0.04, '#ffffff', 160);
  // glint
  if (o.glint) { const g0 = pts[Math.max(1, pts.length - 2)]; const g1 = end; const gx = [g0[0] + (g1[0] - g0[0]) * 0.35, g0[1] + (g1[1] - g0[1]) * 0.35], gy = [g0[0] + (g1[0] - g0[0]) * 0.75, g0[1] + (g1[1] - g0[1]) * 0.75]; strokePath([gx, gy], w * 0.36, '#ffffff', 235, -w * 0.06, -w * 0.21); }
  // golden star / bonus coin
  if (o.golden) { const m = cells[Math.floor(cells.length / 2)]; poly(starPts(m[0], m[1], cell * 0.25), '#a16207'); poly(starPts(m[0], m[1], cell * 0.2), '#fde047'); }
  if (o.bonus) {
    const m = cells[0], r = cell * 0.21;
    circle(m[0], m[1] + cell * 0.03, r, '#000000', 60); circle(m[0], m[1], r, '#ffffff'); circle(m[0], m[1], r * 0.84, '#f59e0b');
    text(String(o.bonus), m[0], m[1] + r * 0.42, r * 1.2, '#ffffff', { center: m[0] });
  }
  return { end, d };
}
const cellsFrom = (ox, oy, cell, list) => list.map(([c, r]) => [ox + (c + 0.5) * cell, oy + (r + 0.5) * cell]);

// ---------- tray ----------
function tray(x, y, w, h, cols, rows, cell, ox, oy) {
  rrect(x, y + 8, w, h, 28, '#d9cff9');
  rrect(x, y, w, h, 28, '#efeaff');
  rrect(x, y, w, 22, 22, '#5b21b6', 18);
  if (cols) for (let c = 0; c < cols; c++) for (let r = 0; r < rows; r++) circle(ox + (c + 0.5) * cell, oy + (r + 0.5) * cell, cell * 0.055, '#cfc3f5');
}

// ---------- 3D button ----------
function button(x, y, w, h, face, lip, label, ink, size, icon) {
  rrect(x, y + 10, w, h, h * 0.42, '#1a0b4d', 70);
  rrect(x, y, w, h, h * 0.42, lip);
  rrect(x, y, w, h - 9, h * 0.42, face);
  rrect(x + h * 0.25, y + 6, w - h * 0.5, (h - 9) * 0.32, (h - 9) * 0.16, '#ffffff', 60);
  let cx = x + w / 2;
  if (icon === 'play') { const ix = x + w / 2 - size * 2.6, iy = y + (h - 9) / 2; rrect(ix - size * 0.55, iy - size * 0.42, size * 1.1, size * 0.84, size * 0.2, '#ffffff'); poly([[ix - size * 0.15, iy - size * 0.24], [ix + size * 0.28, iy], [ix - size * 0.15, iy + size * 0.24]], face); cx += size * 0.4; }
  text(label, x + w / 2, y + (h - 9) / 2 + size * 0.36, size, ink, { center: cx });
}
function roundBtn(cx, cy, r, drawIcon, badge) {
  circle(cx, cy + 6, r, '#1a0b4d', 50);
  circle(cx, cy, r, '#c4b5fd');
  circle(cx, cy - 4, r - 2, '#f5f3ff');
  circle(cx - r * 0.25, cy - r * 0.4, r * 0.35, '#ffffff', 120);
  drawIcon(cx, cy - 4, r);
  if (badge) { circle(cx + r * 0.72, cy - r * 0.72, r * 0.36, '#ffffff'); circle(cx + r * 0.72, cy - r * 0.72, r * 0.3, '#ef4444'); text(String(badge), cx + r * 0.72, cy - r * 0.72 + r * 0.14, r * 0.38, '#ffffff', { center: cx + r * 0.72 }); }
}
function heart(cx, cy, s, on = true) {
  const pc = curveFromBuilder(cb => {
    cb.beginXY(cx, cy + s * 0.9);
    cb.addBezierXY(cx - s * 0.2, cy + s * 0.75, cx - s * 1.05, cy + s * 0.25, cx - s * 0.95, cy - s * 0.25);
    cb.addBezierXY(cx - s * 0.85, cy - s * 0.8, cx - s * 0.15, cy - s * 0.85, cx, cy - s * 0.38);
    cb.addBezierXY(cx + s * 0.15, cy - s * 0.85, cx + s * 0.85, cy - s * 0.8, cx + s * 0.95, cy - s * 0.25);
    cb.addBezierXY(cx + s * 1.05, cy + s * 0.25, cx + s * 0.2, cy + s * 0.75, cx, cy + s * 0.9);
    cb.close();
  });
  fillShape(pc, on ? '#991b1b' : '#8b84b8');
  const pc2 = curveFromBuilder(cb => {
    const k = 0.84; cb.beginXY(cx, cy + s * 0.9 * k - s * 0.05);
    cb.addBezierXY(cx - s * 0.2 * k, cy + s * 0.75 * k, cx - s * 1.05 * k, cy + s * 0.25 * k, cx - s * 0.95 * k, cy - s * 0.25 * k - s * 0.04);
    cb.addBezierXY(cx - s * 0.85 * k, cy - s * 0.8 * k, cx - s * 0.15 * k, cy - s * 0.85 * k, cx, cy - s * 0.38 * k - s * 0.06);
    cb.addBezierXY(cx + s * 0.15 * k, cy - s * 0.85 * k, cx + s * 0.85 * k, cy - s * 0.8 * k, cx + s * 0.95 * k, cy - s * 0.25 * k - s * 0.04);
    cb.addBezierXY(cx + s * 1.05 * k, cy + s * 0.25 * k, cx + s * 0.2 * k, cy + s * 0.75 * k, cx, cy + s * 0.9 * k - s * 0.05);
    cb.close();
  });
  fillShape(pc2, on ? '#ef4444' : '#c9c3ea');
  strokePath([[cx - s * 0.62, cy - s * 0.32], [cx - s * 0.4, cy - s * 0.52]], s * 0.2, '#ffffff', on ? 170 : 90);
}
function coin(cx, cy, r) { circle(cx, cy, r, '#b45309'); circle(cx, cy - r * 0.08, r * 0.92, '#fbbf24'); circle(cx, cy - r * 0.08, r * 0.6, '#f59e0b'); circle(cx, cy - r * 0.08, r * 0.48, '#fcd34d'); strokePath([[cx - r * 0.45, cy - r * 0.5], [cx - r * 0.2, cy - r * 0.7]], r * 0.18, '#ffffff', 180); }

// =====================================================================
// Background + header
rrect(0, 0, W, H, 0, '#170f3a');
circle(260, 120, 520, '#3a1f8a', 90);
circle(1500, 600, 460, '#2a1470', 110);
text('ARROW CRUSH / UI KIT v2', 80, 92, 22, '#fbbf24', { spacing: 0.12 });
text('In-hand feel: arrows, taps and screens', 80, 150, 50, '#f5f2ff');

// ---------- Section 1: board ----------
text('1 / ON THE BOARD', 80, 236, 20, '#c4b5fd', { spacing: 0.1 });
{
  const cell = 84, cols = 8, rows = 6, ox = 120, oy = 300;
  tray(ox - 40, oy - 40, cols * cell + 80, rows * cell + 80, cols, rows, cell, ox, oy);
  const L = [
    [P.ruby, [[0, 0], [1, 0], [2, 0]], {}],
    [P.blue, [[0, 3], [0, 2], [0, 1]], { glint: true }],
    [P.emerald, [[2, 2], [3, 2], [4, 2]], {}],
    [P.blue, [[6, 4], [6, 3], [6, 2], [6, 1]], {}],
    [P.amber, [[1, 5], [1, 4], [2, 4], [3, 4]], {}],
    [P.amber, [[5, 5], [5, 4]], {}],
    [P.gold, [[3, 1], [4, 1], [5, 1]], { golden: true }],
    [P.teal, [[2, 5], [3, 5], [4, 5]], { bonus: 6 }],
    [P.violet, [[7, 0], [7, 1], [7, 2], [7, 3]], {}],
    [P.ruby, [[4, 3], [5, 3]], {}],
    [P.emerald, [[7, 5], [6, 5]], {}],
  ];
  for (const [col, cl, o] of L) arrow(cellsFrom(ox, oy, cell, cl), col, cell, o);
  // side notes
  const nx = ox + cols * cell + 90;
  text('Chunky glossy arrows', nx, 330, 30, '#f5f2ff');
  const notes = ['Dark rim + soft shadow lift every arrow', 'off the tray, so it reads as an object.', '', 'Light stripe on top, darker belly', 'below: one light source, top-left.', '', 'Fletching at the tail, notched head:', 'it looks like an arrow, not a line.', '', 'Golden = star, Bonus = coin badge.', 'Same 6 colours, crush rules unchanged.'];
  notes.forEach((s, i) => s && text(s, nx, 380 + i * 34, 22, '#b9b1de', { weight: FontWeight.SemiBold }));
}

// ---------- Section 2: colour set ----------
text('2 / COLOUR SET', 80, 900, 20, '#c4b5fd', { spacing: 0.1 });
{
  const names = [['Ruby', P.ruby], ['Blue', P.blue], ['Emerald', P.emerald], ['Amber', P.amber], ['Violet', P.violet], ['Teal', P.teal], ['Golden', P.gold]];
  const cw = 196, y0 = 930;
  names.forEach(([nm, col], i) => {
    const x = 80 + i * (cw + 10);
    rrect(x, y0 + 6, cw, 150, 22, '#d9cff9'); rrect(x, y0, cw, 150, 22, '#efeaff');
    arrow([[x + 44, y0 + 62], [x + 98, y0 + 62], [x + 150, y0 + 62]], col, 64, { golden: nm === 'Golden' });
    text(nm, x + cw / 2, y0 + 130, 22, '#3b2a78', { center: x + cw / 2 });
  });
}

// ---------- Section 3: tap storyboard ----------
text('3 / WHAT ONE TAP LOOKS LIKE', 80, 1150, 20, '#c4b5fd', { spacing: 0.1 });
{
  const fw = 276, fh = 230, y0 = 1180, cell = 64;
  const frames = ['Finger down', 'Wind-up', 'Fly out', 'Bump', 'Crush!'];
  const times = ['60 ms dip', '80 ms pull back', '260 ms + streak', '70 ms freeze + wobble', '55 ms freeze + shards'];
  frames.forEach((nm, i) => {
    const x = 80 + i * (fw + 12);
    rrect(x, y0 + 6, fw, fh, 24, '#d9cff9'); rrect(x, y0, fw, fh, 24, '#efeaff');
    const cy = y0 + 92;
    for (let k = 0; k < 4; k++) circle(x + 42 + k * cell, cy + 64, 4, '#cfc3f5');
    if (i === 0) { arrow([[x + 46, cy], [x + 110, cy], [x + 174, cy]], P.blue, cell, { state: 'press' }); circle(x + 120, cy + 6, 26, '#ffffff', 90); circle(x + 120, cy + 6, 16, '#ffffff', 140); }
    if (i === 1) { arrow([[x + 30, cy], [x + 94, cy], [x + 158, cy]], P.blue, cell, {}); strokePath([[x + 206, cy - 24], [x + 226, cy - 24]], 5, '#7c3aed', 160); strokePath([[x + 206, cy + 24], [x + 226, cy + 24]], 5, '#7c3aed', 160); }
    if (i === 2) {
      for (let k = 0; k < 6; k++) strokePath([[x + 40 + k * 18, cy], [x + 58 + k * 18, cy]], 4 + k * 2.4, '#9db8f5', 40 + k * 22);
      arrow([[x + 130, cy], [x + 190, cy], [x + 236, cy]], P.blue, cell, {});
      for (let k = 0; k < 3; k++) strokePath([[x + 70, cy - 30 + k * 30], [x + 110, cy - 30 + k * 30]], 3, '#9db8f5', 120);
    }
    if (i === 3) {
      arrow([[x + 232, cy - 60], [x + 232, cy], [x + 232, cy + 60]], P.amber, cell, {});
      strokePath([[x + 256, cy - 50], [x + 262, cy - 30]], 4, '#3b2a78', 120); strokePath([[x + 256, cy + 30], [x + 262, cy + 50]], 4, '#3b2a78', 120);
      arrow([[x + 36, cy], [x + 94, cy], [x + 150, cy]], P.blue, cell, { state: 'flash' });
      poly(starPts(x + 205, cy, 20, 0.4), '#ffffff', 230);
    }
    if (i === 4) {
      const cx = x + fw / 2;
      circle(cx, cy, 70, '#fde68a', 120); circle(cx, cy, 52, '#efeaff');
      const shard = (ax, ay, s, rot, col) => { const c = Math.cos(rot), sn = Math.sin(rot); poly([[-1, -0.5], [1, -0.2], [0.2, 0.7]].map(([u, v]) => [ax + (u * c - v * sn) * s, ay + (u * sn + v * c) * s]), col); };
      const cols = [P.emerald, mix(P.emerald, 'w', 0.3), mix(P.emerald, 'k', 0.3)];
      for (let k = 0; k < 16; k++) { const a = k / 16 * Math.PI * 2 + 0.3, rr = 40 + (k % 3) * 22; shard(cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * 0.8, 9 + (k % 4) * 3, a * 2, cols[k % 3]); }
      for (let k = 0; k < 6; k++) { const a = k / 6 * Math.PI * 2; circle(cx + Math.cos(a) * 30, cy + Math.sin(a) * 26, 4, '#ffffff'); }
      text('CRUSH!', cx, cy + 14, 32, '#3b0764', { center: cx });
      text('CRUSH!', cx, cy + 11, 32, '#ffffff', { center: cx - 1 });
    }
    text(nm, x + 20, y0 + fh - 46, 24, '#3b2a78');
    text(times[i], x + 20, y0 + fh - 18, 17, '#6b6a8a', { weight: FontWeight.Bold });
  });
}

// ---------- Section 4: HUD + buttons + cards ----------
text('4 / HUD, BUTTONS AND CARDS', 80, 1500, 20, '#c4b5fd', { spacing: 0.1 });
{
  // HUD band
  const x = 80, y = 1530, w = 640, h = 190;
  rrect(x, y + 12, w, h, 34, '#3f1a8a');
  rrect(x, y, w, h, 34, '#6d28d9');
  rrect(x, y + h * 0.5, w, h * 0.5, 34, '#5b21b6');
  rrect(x, y, w, h * 0.55, 34, '#6d28d9');
  roundBtn(x + 52, y + 50, 28, (cx, cy, r) => strokePath([[cx + 6, cy - 12], [cx - 6, cy], [cx + 6, cy + 12]], 6, '#5b21b6'));
  roundBtn(x + w - 52, y + 50, 28, (cx, cy, r) => { rrect(cx - 11, cy - 12, 8, 24, 3, '#5b21b6'); rrect(cx + 3, cy - 12, 8, 24, 3, '#5b21b6'); });
  rrect(x + w / 2 - 110, y + 26 + 6, 220, 52, 26, '#b45309'); rrect(x + w / 2 - 110, y + 26, 220, 48, 24, '#fbbf24'); rrect(x + w / 2 - 90, y + 30, 180, 14, 7, '#ffffff', 70);
  text('Level 24', x + w / 2, y + 62, 30, '#6b2a0a', { center: x + w / 2 });
  for (let i = 0; i < 3; i++) heart(x + 46 + i * 44, y + 140, 17, i < 2);
  rrect(x + 200, y + 118, 120, 44, 22, '#ffffff', 36); poly(starPts(x + 226, y + 140, 14), '#a16207'); poly(starPts(x + 226, y + 140, 11), '#fde047'); text('0/1', x + 248, y + 150, 24, '#ffffff');
  rrect(x + 332, y + 118, 120, 44, 22, '#ffffff', 36); strokePath([[x + 348, y + 140], [x + 366, y + 140]], 5, '#ffffff'); poly([[x + 364, y + 131], [x + 376, y + 140], [x + 364, y + 149]], '#ffffff'); text('12', x + 386, y + 150, 24, '#ffffff');
  text('22', x + w - 80, y + 150, 44, '#ffffff', { center: x + w - 80 }); text('MOVES', x + w - 80, y + 174, 13, '#ddd6fe', { center: x + w - 80, spacing: 0.12 });

  // booster dock
  const dy = 1780;
  const icons = [
    (cx, cy) => { strokePath([[cx - 10, cy - 12], [cx - 14, cy - 2], [cx - 4, cy]], 5, '#5b21b6'); strokePath([[cx - 12, cy - 4], [cx - 2, cy - 12], [cx + 10, cy - 8], [cx + 13, cy + 4], [cx + 4, cy + 13], [cx - 8, cy + 10]], 5, '#5b21b6'); },
    (cx, cy) => poly([[cx + 4, cy - 18], [cx - 12, cy + 3], [cx - 1, cy + 3], [cx - 5, cy + 18], [cx + 12, cy - 4], [cx + 1, cy - 4]], '#f59e0b'),
    (cx, cy) => { circle(cx - 2, cy + 3, 14, '#334155'); circle(cx - 7, cy - 2, 4, '#94a3b8'); strokePath([[cx + 7, cy - 8], [cx + 13, cy - 14]], 4, '#334155'); circle(cx + 15, cy - 16, 4, '#f97316'); },
    (cx, cy) => { circle(cx, cy - 4, 13, '#a16207'); circle(cx, cy - 5, 11, '#fde047'); rrect(cx - 7, cy + 9, 14, 6, 3, '#64748b'); },
  ];
  rrect(80, dy - 50, 640, 112, 40, '#efeaff');
  icons.forEach((ic, i) => roundBtn(170 + i * 152, dy + 4, 40, ic, [2, 1, 0, 1][i]));

  // buttons
  const bx = 80, by = 1900;
  button(bx, by, 640, 96, '#fbbf24', '#b45309', 'PLAY', '#6b2a0a', 46);
  button(bx, by + 120, 310, 84, '#22c55e', '#15803d', 'Resume', '#ffffff', 30);
  button(bx + 330, by + 120, 310, 84, '#ede9fe', '#c4b5fd', 'Restart', '#7c3aed', 30);

  // Pause card
  const px = 790, py = 1530, pw = 340, ph = 470;
  rrect(px, py + 16, pw, ph, 40, '#0b0626', 110);
  rrect(px, py, pw, ph, 40, '#c4b5fd');
  rrect(px, py, pw, ph - 10, 40, '#ffffff');
  circle(px + pw / 2, py + 86, 52, '#c4b5fd'); circle(px + pw / 2, py + 82, 50, '#f5f3ff');
  rrect(px + pw / 2 - 20, py + 58, 14, 48, 5, '#7c3aed'); rrect(px + pw / 2 + 6, py + 58, 14, 48, 5, '#7c3aed');
  text('Paused', px + pw / 2, py + 200, 44, '#4c1d95', { center: px + pw / 2 });
  text('Your timer is stopped.', px + pw / 2, py + 240, 20, '#6b6a8a', { center: px + pw / 2, weight: FontWeight.Bold });
  button(px + 30, py + 280, pw - 60, 76, '#22c55e', '#15803d', 'Resume', '#ffffff', 28);
  button(px + 30, py + 372, pw - 60, 68, '#ede9fe', '#c4b5fd', 'Restart', '#7c3aed', 24);

  // Win card
  const wx = 1160, wy = 1530, ww = 360, wh = 470;
  rrect(wx, wy + 16, ww, wh, 40, '#0b0626', 110);
  rrect(wx, wy, ww, wh, 40, '#c4b5fd');
  rrect(wx, wy, ww, wh - 10, 40, '#ffffff');
  circle(wx + ww / 2, wy + 96, 92, '#fef3c7');
  const st = (cx, cy, r, lit) => { poly(starPts(cx, cy + 4, r * 1.12), lit ? '#b45309' : '#cbd5e1'); poly(starPts(cx, cy, r), lit ? '#fbbf24' : '#e2e8f0'); poly(starPts(cx - r * 0.12, cy - r * 0.15, r * 0.45), '#ffffff', lit ? 90 : 120); };
  st(wx + ww / 2 - 92, wy + 110, 40, true); st(wx + ww / 2 + 92, wy + 110, 40, false); st(wx + ww / 2, wy + 88, 54, true);
  text('Level Complete!', wx + ww / 2, wy + 228, 38, '#4c1d95', { center: wx + ww / 2 });
  rrect(wx + ww / 2 - 86, wy + 254, 172, 52, 26, '#fef3c7'); coin(wx + ww / 2 - 52, wy + 280, 17); text('+65', wx + ww / 2 + 16, wy + 292, 30, '#92400e', { center: wx + ww / 2 + 18 });
  button(wx + 30, wy + 340, ww - 60, 84, '#fbbf24', '#b45309', 'Next Level', '#6b2a0a', 30);

  // coin + quiver pills
  rrect(790, 2040, 200, 62, 31, '#241a58'); coin(826, 2071, 20); text('1,250', 856, 2083, 30, '#ffffff');
  rrect(1010, 2040, 160, 62, 31, '#241a58'); for (let i = 0; i < 3; i++) strokePath([[1036 + i * 9, 2090], [1046 + i * 9, 2054]], 5, ['#e11d48', '#f59e0b', '#2563eb'][i]); text('5', 1080, 2083, 30, '#ffffff');
  text('Buttons: thick lip that squashes on press.', 1196, 2062, 18, '#b9b1de', { weight: FontWeight.SemiBold });
  text('Cards spring in, stars land one by one.', 1196, 2090, 18, '#b9b1de', { weight: FontWeight.SemiBold });
}
text('Made in Affinity 3 by script / Arrow Crush', 80, 2200, 18, '#6f64a8', { weight: FontWeight.Bold });
console.log('DOC', doc.sessionUuid, 'nodes', count);

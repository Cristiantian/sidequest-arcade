// SideQuest Arcade (Windows/Electron port of ../mac/main.swift).
// A frameless always-on-top window: a thin bar (bar.html) above a WebContentsView showing the real
// crazygames.com game page, where theater.js stretches the game iframe over the whole view.
// Nothing touches the game underneath; WoW must run in "Windowed (Fullscreen)" for any overlay to show.
const { app, BrowserWindow, WebContentsView, globalShortcut, ipcMain, Menu, Tray, nativeImage, screen, shell } = require('electron');
const fs = require('fs');
const path = require('path');

const GAMES = [
  ['Lumen', 'lumen-vne'],            // ours (Shadow Games): first in the list, first launch
  ['Smash Karts', 'smash-karts'],
  ['Crazy Roll 3D', 'crazy-roll-3d'],
  ['Ragdoll Archers', 'ragdoll-archers'],
  ['Paper.io 2', 'paper-io-2'],
  ['Helix Jump', 'helix-jump'],
  ['Basketball Stars', 'basketball-stars'],
  ['8 Ball Billiards', '8-ball-billiards-classic'],
  ['Classic Solitaire', 'classic-solitaire'],
];
const HOME = 'https://www.crazygames.com/';
const BAR = 30;
const SIZES = [360, 480, 640, 800];
const MOD = 'Control+Alt';
const KEYNAME = process.platform === 'darwin' ? '⌃⌥' : 'Ctrl+Alt+';

if (!app.requestSingleInstanceLock()) app.quit();

// ---- settings --------------------------------------------------------------
const settingsFile = () => path.join(app.getPath('userData'), 'settings.json');
let S = { muted: false, size: 1, side: 'right', opacity: 1, lastURL: null, bounds: null };
function loadSettings() { try { Object.assign(S, JSON.parse(fs.readFileSync(settingsFile(), 'utf8'))); } catch {} }
let saveTimer;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => { try { fs.writeFileSync(settingsFile(), JSON.stringify(S, null, 1)); } catch {} }, 300);
}

let win, game, tray;

// ---- window ----------------------------------------------------------------
function create() {
  win = new BrowserWindow({
    width: 480, height: 300, minWidth: 280, minHeight: 200,
    frame: false, resizable: true, skipTaskbar: false, show: false,
    backgroundColor: '#09090b', title: 'SideQuest Arcade',
    webPreferences: { preload: path.join(__dirname, 'bar-preload.js') },
  });
  win.setAlwaysOnTop(true, 'screen-saver');       // above borderless-fullscreen games
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  win.setOpacity(S.opacity);
  win.loadFile(path.join(__dirname, 'bar.html'));

  game = new WebContentsView({
    webPreferences: { preload: path.join(__dirname, 'theater.js'), backgroundThrottling: false },
  });
  game.setBackgroundColor('#000000');
  win.contentView.addChildView(game);
  const wc = game.webContents;
  wc.setAudioMuted(S.muted);
  // A plain desktop browser UA, so the site serves its normal desktop game page.
  wc.setUserAgent(wc.getUserAgent().replace(/\s*(Electron|sidequest-arcade)\/\S+/gi, ''));
  wc.setWindowOpenHandler(({ url }) => {
    const slug = slugOf(url);
    if (slug) play(slug); else if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  wc.on('did-navigate', (_e, url) => { S.lastURL = url; save(); });
  wc.on('did-navigate-in-page', (_e, url) => { S.lastURL = url; save(); });

  if (S.bounds && screen.getDisplayMatching(S.bounds)) win.setBounds(S.bounds); else dock(S.side, false);
  layout();
  win.on('resize', () => { layout(); remember(); });
  win.on('move', remember);
  win.on('focus', status);
  win.on('blur', status);
  win.once('ready-to-show', () => { win.showInactive(); status(); });

  if (S.lastURL) wc.loadURL(S.lastURL); else play(GAMES[0][1]);
}

function layout() {
  const [w, h] = win.getContentSize();
  game.setBounds({ x: 0, y: BAR, width: w, height: Math.max(0, h - BAR) });
}
function remember() { if (!win.isMinimized()) { S.bounds = win.getBounds(); save(); } }

function dock(side, animate = true) {
  S.side = side;
  const d = screen.getDisplayMatching(win.getBounds()).workArea;
  const w = Math.round(Math.min(SIZES[S.size], d.width * 0.6));
  const h = Math.round(Math.min(w * 9 / 16 + BAR, d.height - 24));
  const x = side === 'left' ? d.x + 12 : d.x + d.width - w - 12;
  // A little above centre: the game's action bars and chat live along the bottom.
  const y = d.y + Math.round((d.height - h) * 0.4);
  win.setBounds({ x, y, width: w, height: h }, animate);
  remember(); menu();
}
function resize(step) { S.size = Math.max(0, Math.min(SIZES.length - 1, S.size + step)); dock(S.side); }
function cycleSize() { S.size = (S.size + 1) % SIZES.length; dock(S.side); }

// ---- games -----------------------------------------------------------------
function slugOf(url) {
  try {
    const u = new URL(url);
    if (!u.hostname.endsWith('crazygames.com')) return null;
    const m = u.pathname.match(/^\/(game|embed)\/([^/]+)/);
    return m ? m[2] : null;
  } catch { return null; }
}
function play(slug) { game.webContents.loadURL(`https://www.crazygames.com/game/${slug}`); }
function browse() { game.webContents.loadURL(HOME); grab(); }

// ---- focus: the keyboard goes to the game or to whatever you were in, never both ----
const playing = () => win.isVisible() && win.isFocused();
function grab() {
  if (!win.isVisible()) win.showInactive();
  win.show(); win.focus(); game.webContents.focus();
  game.webContents.executeJavaScript("(document.getElementById('game-iframe')||document.body).focus()").catch(() => {});
  status();
}
function giveBack() {
  // On Windows, blur() hands the foreground to the next window in z-order: the game you came from.
  win.blur();
  if (process.platform === 'darwin') app.hide();
  setTimeout(() => { if (!win.isVisible()) win.showInactive(); status(); }, 50);
}
function swap() { playing() ? giveBack() : grab(); }
function toggleShown() {
  if (win.isVisible()) { const was = playing(); win.hide(); if (was) giveBack(); }
  else win.showInactive();
  menu();
}
function toggleMute() { S.muted = !S.muted; game.webContents.setAudioMuted(S.muted); save(); status(); menu(); }
function setOpacity(o) { S.opacity = o; win.setOpacity(o); save(); menu(); }

function status() {
  if (!win || win.isDestroyed()) return;
  win.webContents.send('state', { playing: playing(), muted: S.muted, key: KEYNAME, games: GAMES.map(g => g[0]) });
}

// ---- bar actions -----------------------------------------------------------
const ACTIONS = {
  swap, browse, toggleShown, toggleMute, cycleSize,
  reload: () => game.webContents.reload(),
  dockLeft: () => dock('left'), dockRight: () => dock('right'),
  game: (i) => { play(GAMES[i][1]); grab(); },
  ready: status,
};
ipcMain.on('act', (_e, name, arg) => ACTIONS[name] && ACTIONS[name](arg));

// ---- hotkeys (system-wide) -------------------------------------------------
function hotkeys() {
  const map = {
    Space: swap, G: toggleShown, Left: () => dock('left'), Right: () => dock('right'),
    M: toggleMute, R: ACTIONS.reload, '=': () => resize(1), '-': () => resize(-1), B: browse,
  };
  GAMES.forEach((_, i) => { map[String(i + 1)] = () => ACTIONS.game(i); });
  for (const [k, fn] of Object.entries(map)) {
    if (!globalShortcut.register(`${MOD}+${k}`, fn)) console.warn('hotkey taken:', k);
  }
}

// ---- tray ------------------------------------------------------------------
function trayIcon() {
  // 16x16 violet controller, drawn so no image file has to ship.
  const n = 16, buf = Buffer.alloc(n * n * 4);
  const on = (x, y) => {
    const body = y >= 5 && y <= 11 && x >= 1 && x <= 14 && !((x <= 2 || x >= 13) && (y <= 5 || y >= 11));
    const grip = y >= 10 && y <= 13 && ((x >= 2 && x <= 5) || (x >= 10 && x <= 13));
    const hole = (y === 8 && x >= 3 && x <= 5) || (x === 4 && y >= 7 && y <= 9) || ((x === 11 || x === 12) && (y === 7 || y === 9));
    return (body || grip) && !hole;
  };
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const i = (y * n + x) * 4;
    if (on(x, y)) { buf[i] = 255; buf[i + 1] = 92; buf[i + 2] = 124; buf[i + 3] = 255; } // BGRA #7C5CFF
  }
  return nativeImage.createFromBitmap(buf, { width: n, height: n });
}

function menu() {
  if (!tray) return;
  const k = (s) => `${KEYNAME}${s}`;
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: `Play / back to your game   ${k('Space')}`, click: swap },
    { label: `${win.isVisible() ? 'Hide' : 'Show'} screen   ${k('G')}`, click: toggleShown },
    { type: 'separator' },
    ...GAMES.map(([name], i) => ({ label: `${name}   ${k(i + 1)}`, click: () => ACTIONS.game(i) })),
    { label: `Browse all CrazyGames…   ${k('B')}`, click: browse },
    { type: 'separator' },
    { label: `Dock left   ${k('Left')}`, type: 'radio', checked: S.side === 'left', click: () => dock('left') },
    { label: `Dock right   ${k('Right')}`, type: 'radio', checked: S.side === 'right', click: () => dock('right') },
    { label: `Bigger / smaller   ${k('= / -')}`, click: cycleSize },
    { label: `Mute   ${k('M')}`, type: 'checkbox', checked: S.muted, click: toggleMute },
    { label: 'Opacity', submenu: [1, 0.9, 0.75, 0.6, 0.45].map(o => ({
      label: `${Math.round(o * 100)}%`, type: 'radio', checked: Math.abs(S.opacity - o) < 0.01, click: () => setOpacity(o) })) },
    { label: 'Start with Windows', type: 'checkbox', visible: process.platform === 'win32',
      checked: app.getLoginItemSettings().openAtLogin,
      click: (it) => app.setLoginItemSettings({ openAtLogin: it.checked }) },
    { type: 'separator' },
    { label: 'Quit SideQuest', click: () => app.quit() },
  ]));
}

app.on('second-instance', () => { if (win) grab(); });
app.whenReady().then(() => {
  loadSettings();
  if (process.platform === 'darwin') app.dock?.hide();
  create();
  hotkeys();
  tray = new Tray(trayIcon());
  tray.setToolTip('SideQuest Arcade');
  tray.on('click', swap);
  menu();
  if (process.env.SIDEQUEST_SNAP) debugSnap(process.env.SIDEQUEST_SNAP);
});

// Debug: SIDEQUEST_SNAP=/path/out.png [SIDEQUEST_PLAY=slug] — capture bar + game after load, then quit.
async function debugSnap(out) {
  if (process.env.SIDEQUEST_PLAY) play(process.env.SIDEQUEST_PLAY);
  await new Promise(r => setTimeout(r, +(process.env.SIDEQUEST_WAIT || 25000)));
  // Hide whatever covers the centre (e.g. the consent dialog) for this capture only.
  await game.webContents.executeJavaScript(`(()=>{let e=document.elementFromPoint(innerWidth/2,innerHeight/2);
    while(e&&e.parentElement&&e.parentElement!==document.body)e=e.parentElement;
    if(e&&e.id!=='game-iframe'&&!e.querySelector('#game-iframe'))e.style.visibility='hidden'})()`).catch(() => {});
  await new Promise(r => setTimeout(r, 400));
  const [barImg, gameImg] = await Promise.all([win.webContents.capturePage(), game.webContents.capturePage()]);
  const info = await game.webContents.executeJavaScript(
    "JSON.stringify({url:location.href,theater:document.documentElement.classList.contains('sq'),w:innerWidth,h:innerHeight})").catch(e => String(e));
  fs.writeFileSync(out, barImg.toPNG());
  fs.writeFileSync(out.replace(/\.png$/, '-game.png'), gameImg.toPNG());
  fs.writeFileSync(out.replace(/\.png$/, '.txt'), `${info}\nmuted=${game.webContents.isAudioMuted()}\n`);
  app.quit();
}
app.on('will-quit', () => globalShortcut.unregisterAll());
app.on('window-all-closed', () => app.quit());

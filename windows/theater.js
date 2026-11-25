// Preload for the game view (same idea as THEATER in ../mac/main.swift): on a crazygames.com game page,
// the game's own iframe is stretched over the whole view and the site around it is covered. The game stays
// inside crazygames.com, so its SDK, saves and login behave exactly as on the site.
const css = `html.sq, html.sq body { overflow: hidden !important; background: #000 !important; }
html.sq #game-iframe { position: fixed !important; left: 0 !important; top: 0 !important;
  width: 100vw !important; height: 100vh !important; max-width: none !important; max-height: none !important;
  margin: 0 !important; border: 0 !important; transform: none !important; background: #000 !important;
  z-index: 2147483000 !important; }`;
function fix() {
  const root = document.documentElement;
  if (!root) return;
  const f = document.getElementById('game-iframe');
  if (!f) { root.classList.remove('sq'); return; }
  if (!document.getElementById('sq-style')) {
    const s = document.createElement('style'); s.id = 'sq-style'; s.textContent = css;
    (document.head || root).appendChild(s);
  }
  root.classList.add('sq');
  // position:fixed is trapped by any ancestor with a transform/filter/contain; release them.
  for (let p = f.parentElement; p && p !== document.body; p = p.parentElement) {
    const cs = getComputedStyle(p);
    if (cs.transform !== 'none' || cs.filter !== 'none' || cs.contain !== 'none' || cs.containerType !== 'normal')
      p.style.cssText += ';transform:none!important;filter:none!important;contain:none!important;container-type:normal!important';
  }
}
setInterval(fix, 500);
window.addEventListener('DOMContentLoaded', fix);

#!/usr/bin/env python3
"""Builds the shadowgames.shop SideQuest landing pages (EN + DE) as WordPress custom-HTML blocks.
Same visual system as the Lumen page (Barlow / Barlow Condensed, dark hero, pale bands).
Usage: python3 build.py OWNER HERO_IMAGE_URL  -> writes sidequest-en.html, sidequest-de.html
"""
import sys, pathlib

OWNER, HERO = sys.argv[1], sys.argv[2]
REL = f"https://github.com/{OWNER}/sidequest-arcade/releases/latest/download"
REPO = f"https://github.com/{OWNER}/sidequest-arcade"
WIN, MAC = f"{REL}/SideQuest-Windows-x64.zip", f"{REL}/SideQuest-Mac.zip"

CSS = """
@font-face{font-family:Barlow;src:url(https://fonts.gstatic.com/s/barlow/v13/7cHpv4kjgoGqM7EPCw.ttf) format("truetype");font-weight:400;font-display:swap}
@font-face{font-family:Barlow;src:url(https://fonts.gstatic.com/s/barlow/v13/7cHqv4kjgoGqM7E3t-4c4A.ttf) format("truetype");font-weight:700;font-display:swap}
@font-face{font-family:"Barlow Condensed";src:url(https://fonts.gstatic.com/s/barlowcondensed/v13/HTxwL3I-JCGChYJ8VI-L6OO_au7B47b1_3E.ttf) format("truetype");font-weight:800;font-display:swap}
body:has(.sg-sq) #content,body:has(.sg-sq) #primary{background:#fff}
body:has(.sg-sq) #content>.ast-container{display:block;width:100%;max-width:none!important;padding:0!important}
body:has(.sg-sq) #primary,body:has(.sg-sq) article:has(.sg-sq),body:has(.sg-sq) .entry-content:has(.sg-sq){width:100%;margin:0;padding:0;max-width:none}
article:has(.sg-sq)>.entry-header,article:has(.sg-sq)>.ast-article-featured-section{display:none}
.sg-sq .hero,.sg-sq .facts,.sg-sq .closing{box-shadow:0 0 0 100vmax var(--band);clip-path:inset(0 -100vmax)}
.sg-sq .hero{--band:#100a23}
.sg-sq .facts,.sg-sq .closing{--band:#f6f4fc}
.sg-sq{--ink:#15121f;--muted:#585569;--purple:#5636d8;--line:#e8e5ef;--pale:#f6f4fc;color:var(--ink);font:400 18px/1.55 Barlow,Arial,sans-serif;background:#fff}
.sg-sq,.sg-sq *{box-sizing:border-box}
.sg-sq :where(h1,h2,h3,p,dl,dd,ol,ul,figure){margin:0}
.sg-sq .wrap{max-width:1280px;margin:auto;padding-inline:clamp(22px,5vw,68px)}
.sg-sq a:focus-visible,.sg-sq summary:focus-visible{outline:3px solid #977fff;outline-offset:5px}
.sg-sq h1,.sg-sq h2,.sg-sq h3{font:800 clamp(38px,5vw,64px)/.98 "Barlow Condensed",Impact,sans-serif;text-transform:uppercase;color:inherit}
.sg-sq h1{font-size:clamp(64px,9.5vw,136px);letter-spacing:-.03em}
.sg-sq h2 span{color:var(--purple)}
.sg-sq h3{font-size:26px}
.sg-sq .eyebrow{font-size:12px;font-weight:700;letter-spacing:.14em;text-transform:uppercase}
.sg-sq .hero{color:#fff;background:#100a23;padding-block:clamp(42px,7vw,96px)}
.sg-sq .hero .wrap{display:grid;grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr);align-items:center;gap:clamp(24px,5vw,66px)}
.sg-sq .hero .eyebrow{color:#c6b7f8}
.sg-sq .lead{font-size:clamp(19px,2.1vw,23px);max-width:34ch;margin-block:12px 24px;color:#efecfb}
.sg-sq .ctas{display:flex;flex-wrap:wrap;gap:12px}
.sg-sq .cta{display:inline-flex;justify-content:center;align-items:center;gap:10px;min-height:52px;padding:11px 20px;border-radius:7px;background:var(--purple);color:#fff;font-weight:700;text-decoration:none;line-height:1.25}
.sg-sq .cta:hover{background:#4325b8;color:#fff}
.sg-sq .cta.alt{background:#e7ddff;color:#241554}
.sg-sq .cta.alt:hover{background:#fff;color:#241554}
.sg-sq .cta svg{width:20px;height:20px;fill:currentColor}
.sg-sq .small{color:#d4cbe5;font-size:14px;margin-top:14px}
.sg-sq .small a{color:#e7ddff}
.sg-sq .shot{position:relative}
.sg-sq .shot img{display:block;width:100%;height:auto;border-radius:12px;box-shadow:0 0 0 2px #7c5cff,0 18px 48px #070311}
.sg-sq .shot figcaption{color:#a99fc4;font-size:13px;margin-top:10px;text-align:center}
.sg-sq .facts{background:var(--pale)}
.sg-sq .facts dl{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));padding-block:20px;text-align:center}
.sg-sq .facts dl div+div{border-left:1px solid var(--line)}
.sg-sq dt{font-weight:700}
.sg-sq dd{color:var(--muted)}
.sg-sq .part{padding-block:clamp(46px,7vw,88px)}
.sg-sq .part+.part{border-top:1px solid var(--line)}
.sg-sq .intro{max-width:65ch;margin-top:16px;color:var(--muted)}
.sg-sq .tips{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px;margin-top:26px}
.sg-sq .tip{background:var(--pale);border-radius:10px;padding:22px}
.sg-sq .tip p{margin-top:8px;color:var(--muted)}
.sg-sq .guide{display:grid;grid-template-columns:minmax(0,1.15fr) minmax(0,1fr);gap:clamp(24px,6vw,76px)}
.sg-sq .guide ol{padding-left:23px;margin-top:16px}
.sg-sq .guide li+li{margin-top:10px}
.sg-sq .keys{padding:24px;background:var(--pale);border-radius:10px;align-self:start}
.sg-sq .keys p{color:var(--muted);font-size:15px;margin-top:6px}
.sg-sq .keys dl{margin-top:12px}
.sg-sq .keys dl div{display:grid;grid-template-columns:8.5em 1fr;gap:12px;padding-block:9px;border-top:1px solid var(--line)}
.sg-sq .keys dd{font-size:16px}
.sg-sq kbd{font:700 14px/1 Barlow,Arial,sans-serif;background:#fff;border:1px solid var(--line);border-bottom-width:2px;border-radius:5px;padding:4px 7px;white-space:nowrap}
.sg-sq details{border-bottom:1px solid var(--line);padding-block:13px}
.sg-sq details p{margin-top:8px;color:var(--muted)}
.sg-sq details a{color:var(--purple);font-weight:700}
.sg-sq summary{cursor:pointer;font-weight:700}
.sg-sq .faq{max-width:760px}
.sg-sq .faq h2{margin-bottom:14px}
.sg-sq .closing{background:var(--pale);padding-block:clamp(34px,6vw,66px)}
.sg-sq .closing .wrap{display:flex;justify-content:space-between;align-items:center;gap:24px;flex-wrap:wrap}
.sg-sq .closing p{margin-top:8px;color:var(--muted)}
.sg-sq .closing p a{color:var(--purple);font-weight:700}
@media(max-width:760px){
.sg-sq .hero .wrap,.sg-sq .guide,.sg-sq .tips{grid-template-columns:1fr}
.sg-sq .hero{padding-block:34px}
.sg-sq .facts dl{font-size:14px}
.sg-sq .facts dl div{padding-inline:4px}
.sg-sq .keys dl div{grid-template-columns:1fr;gap:4px}
}
"""

WIN_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 5.5 10.5 4.4v7.1H3zm8.5-1.2L21 3v8.5h-9.5zM3 12.5h7.5v7.1L3 18.5zm8.5 0H21V21l-9.5-1.3z"/></svg>'
MAC_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16.37 12.73c-.02-2.4 1.96-3.56 2.05-3.62-1.12-1.63-2.86-1.86-3.48-1.88-1.48-.15-2.89.87-3.64.87-.76 0-1.91-.85-3.14-.83-1.61.02-3.1.94-3.930 2.38-1.680 2.910-.430 7.210 1.200 9.570.800 1.150 1.750 2.450 2.990 2.400 1.200-.050 1.660-.780 3.110-.780 1.450 0 1.860.780 3.130.750 1.290-.020 2.110-1.170 2.900-2.330.910-1.340 1.290-2.630 1.310-2.700-.030-.010-2.510-.960-2.500-3.830zM13.980 5.680c.660-.800 1.110-1.920.990-3.030-.950.040-2.110.640-2.790 1.440-.610.710-1.150 1.840-1 2.930 1.060.080 2.140-.540 2.800-1.340z"/></svg>'

T = {
 "en": dict(
  lang="en", eyebrow="A free app by Shadow Games", title="SideQuest Arcade",
  lead="Play CrazyGames on a small screen on top of World of Warcraft. Queue timer, flight path, waiting for the raid: flip to a quick game without alt-tabbing.",
  win="Download for Windows", mac="Download for Mac",
  small=f'Free · Windows 10/11 and macOS 13+ · <a href="{REPO}">Open source on GitHub</a>',
  cap="Lumen, our own game, running in SideQuest.",
  shot_alt="SideQuest Arcade window playing Lumen",
  facts=[("Works with","WoW & any windowed game"),("Games","Thousands on CrazyGames"),("Price","Free, no account needed")],
  h_how='Your game. <span>Plus a side quest.</span>',
  intro="SideQuest is a small window that stays on top of your game. Inside it runs the real CrazyGames site, cropped down to just the game, so saves, logins and multiplayer work exactly as on the website.",
  tips=[("Always on top","Dock it left or right, resize it, make it see-through. It stays above WoW until you hide it."),
        ("One key to swap","Ctrl+Alt+Space moves your keyboard between the mini game and WoW. No alt-tab, no lost focus."),
        ("Any CrazyGames game","Nine quick picks are one hotkey away, starting with our own Lumen, and Browse opens the whole CrazyGames library.")],
  h_setup='Set it up in <span>a minute.</span>',
  steps=[("In WoW, use Windowed (Fullscreen).","Options → Graphics → Display Mode. Plain Fullscreen hides every overlay, including this one."),
         ("Download and unzip.","On Windows, run SideQuest.exe. If you see “Windows protected your PC”, click More info → Run anyway."),
         ("On a Mac, drag SideQuest.app into Applications.","The first time, open System Settings → Privacy & Security → Open Anyway."),
         ("Press Ctrl+Alt+Space to play.","The purple line means the game has your keyboard. Press it again to get back to WoW.")],
  keys_h="Hotkeys", keys_p="Windows: Ctrl+Alt · Mac: Control+Option. They work while you’re in WoW.",
  keys=[("+ Space","Swap your keyboard: game ↔ WoW"),("+ G","Show / hide the screen"),("+ ← / →","Dock left / right"),
        ("+ = / -","Bigger / smaller"),("+ 1 … 9","Jump to a game"),("+ B","Browse all of CrazyGames"),("+ M","Mute")],
  h_faq='SideQuest <span>FAQ.</span>',
  faq=[("Can this get my WoW account banned?","SideQuest never touches WoW. It’s a separate window on your desktop, the same kind of thing as the Discord or OBS overlays. It doesn’t read WoW’s memory, inject anything or change game files."),
       ("Why isn’t it a WoW addon?","WoW addons can’t show web pages. The Pokémon addons rebuilt a whole Game Boy inside WoW’s scripting language, which works for one console but not for thousands of web games. A separate window can run any of them."),
       ("Why does Windows or macOS warn me?","The app isn’t code-signed yet, so your system can’t check who made it. The code is public on GitHub, and the warning goes away once we sign it."),
       ("Does it work with other games?",f"Yes. Anything that runs in a window or in borderless fullscreen works, not just WoW."),
       ("I play on a Mac. Is that a different app?","It’s a native Mac version with the same features and the same hotkeys, using Control+Option instead of Ctrl+Alt.")],
  close_h='Made by <span>Shadow Games.</span>', close_p='We make browser games like <a href="/lumen/">Lumen</a> and tabletop games in Switzerland.',
  more="Explore our games →", more_href="/games/",
 ),
 "de": dict(
  lang="de", eyebrow="Eine Gratis-App von Shadow Games", title="SideQuest Arcade",
  lead="Spiele CrazyGames in einem kleinen Fenster über World of Warcraft. Warteschlange, Flugroute, warten auf den Raid: schnell eine Runde spielen, ohne Alt+Tab.",
  win="Für Windows herunterladen", mac="Für Mac herunterladen",
  small=f'Gratis · Windows 10/11 und macOS 13+ · <a href="{REPO}">Open Source auf GitHub</a>',
  cap="Lumen, unser eigenes Spiel, in SideQuest.",
  shot_alt="SideQuest-Arcade-Fenster mit Lumen",
  facts=[("Läuft mit","WoW & jedem Spiel im Fenstermodus"),("Spiele","Tausende auf CrazyGames"),("Preis","Gratis, ohne Konto")],
  h_how='Dein Spiel. <span>Plus eine Side Quest.</span>',
  intro="SideQuest ist ein kleines Fenster, das immer über deinem Spiel bleibt. Darin läuft die echte CrazyGames-Seite, auf das Spiel zugeschnitten. Spielstände, Logins und Multiplayer funktionieren also genau wie auf der Website.",
  tips=[("Immer im Vordergrund","Links oder rechts andocken, Grösse ändern, transparent machen. Es bleibt über WoW, bis du es ausblendest."),
        ("Eine Taste zum Wechseln","Ctrl+Alt+Leertaste schickt deine Tastatur zwischen Minispiel und WoW hin und her. Kein Alt+Tab, kein Fokusverlust."),
        ("Jedes CrazyGames-Spiel","Neun schnelle Favoriten liegen auf Hotkeys, allen voran unser eigenes Lumen, und Browse öffnet die ganze CrazyGames-Bibliothek.")],
  h_setup='In einer Minute <span>eingerichtet.</span>',
  steps=[("Stelle WoW auf Fenstermodus (Vollbild).","Optionen → Grafik → Anzeigemodus. Normales Vollbild versteckt jedes Overlay, auch dieses."),
         ("Herunterladen und entpacken.","Unter Windows SideQuest.exe starten. Kommt «Der Computer wurde durch Windows geschützt», auf Weitere Informationen → Trotzdem ausführen klicken."),
         ("Auf dem Mac SideQuest.app in den Programme-Ordner ziehen.","Beim ersten Start Systemeinstellungen → Datenschutz & Sicherheit → Trotzdem öffnen."),
         ("Mit Ctrl+Alt+Leertaste spielen.","Die violette Linie heisst: Das Spiel hat deine Tastatur. Nochmals drücken, und du bist zurück in WoW.")],
  keys_h="Hotkeys", keys_p="Windows: Ctrl+Alt · Mac: Control+Option. Sie funktionieren, während du in WoW bist.",
  keys=[("+ Leertaste","Tastatur wechseln: Spiel ↔ WoW"),("+ G","Fenster ein-/ausblenden"),("+ ← / →","Links / rechts andocken"),
        ("+ = / -","Grösser / kleiner"),("+ 1 … 9","Direkt zu einem Spiel"),("+ B","Ganz CrazyGames durchstöbern"),("+ M","Ton aus")],
  h_faq='SideQuest <span>FAQ.</span>',
  faq=[("Kann mein WoW-Konto deswegen gesperrt werden?","SideQuest greift nie auf WoW zu. Es ist ein separates Fenster auf deinem Desktop, wie die Overlays von Discord oder OBS. Es liest keinen WoW-Speicher, schleust nichts ein und ändert keine Spieldateien."),
       ("Warum ist es kein WoW-Addon?","WoW-Addons können keine Webseiten anzeigen. Die Pokémon-Addons haben einen ganzen Game Boy in WoWs Skriptsprache nachgebaut. Das klappt für eine Konsole, aber nicht für Tausende Browsergames. Ein eigenes Fenster kann sie alle zeigen."),
       ("Warum warnt mich Windows oder macOS?","Die App ist noch nicht signiert, darum kann dein System nicht prüfen, wer sie gemacht hat. Der Code ist öffentlich auf GitHub, und die Warnung verschwindet, sobald wir sie signieren."),
       ("Funktioniert es auch mit anderen Spielen?","Ja. Alles, was im Fenster oder im randlosen Vollbild läuft, funktioniert, nicht nur WoW."),
       ("Ich spiele auf dem Mac. Ist das eine andere App?","Es ist eine native Mac-Version mit denselben Funktionen und Hotkeys, einfach mit Control+Option statt Ctrl+Alt.")],
  close_h='Gemacht von <span>Shadow Games.</span>', close_p='Wir machen Browsergames wie <a href="/lumen/">Lumen</a> und Brettspiele in der Schweiz.',
  more="Unsere Spiele entdecken →", more_href="/de/spiele/",
 ),
}

def page(t):
    tips = "".join(f'<div class="tip"><h3>{h}</h3><p>{p}</p></div>' for h, p in t["tips"])
    steps = "".join(f"<li><strong>{h}</strong> {p}</li>" for h, p in t["steps"])
    keys = "".join(f"<div><dt><kbd>{k}</kbd></dt><dd>{d}</dd></div>" for k, d in t["keys"])
    faq = "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in t["faq"])
    facts = "".join(f"<div><dt>{a}</dt><dd>{b}</dd></div>" for a, b in t["facts"])
    btns = (f'<a class="cta" href="{WIN}">{WIN_ICON}{t["win"]}</a>'
            f'<a class="cta alt" href="{MAC}">{MAC_ICON}{t["mac"]}</a>')
    return f"""<!-- wp:html -->
<style>{CSS}</style>
<div class="sg-sq" lang="{t['lang']}">
  <section class="hero" aria-labelledby="sq-title">
    <div class="wrap">
      <div>
        <p class="eyebrow">{t['eyebrow']}</p>
        <h1 id="sq-title">{t['title']}</h1>
        <p class="lead">{t['lead']}</p>
        <div class="ctas">{btns}</div>
        <p class="small">{t['small']}</p>
      </div>
      <figure class="shot"><img src="{HERO}" alt="{t['shot_alt']}" width="1204" height="950" fetchpriority="high" decoding="async"><figcaption>{t['cap']}</figcaption></figure>
    </div>
  </section>
  <div class="facts"><dl class="wrap">{facts}</dl></div>
  <div class="wrap">
    <section class="part" aria-labelledby="sq-how"><h2 id="sq-how">{t['h_how']}</h2><p class="intro">{t['intro']}</p><div class="tips">{tips}</div></section>
    <section class="part guide" aria-labelledby="sq-setup">
      <div><h2 id="sq-setup">{t['h_setup']}</h2><ol>{steps}</ol></div>
      <div class="keys"><h3>{t['keys_h']}</h3><p>{t['keys_p']}</p><dl>{keys}</dl></div>
    </section>
    <section class="part" aria-labelledby="sq-faq"><div class="faq"><h2 id="sq-faq">{t['h_faq']}</h2>{faq}</div></section>
  </div>
  <section class="closing" aria-labelledby="sq-studio">
    <div class="wrap">
      <div><h2 id="sq-studio">{t['close_h']}</h2><p>{t['close_p']}</p><p><a href="{t['more_href']}">{t['more']}</a></p></div>
      <div class="ctas">{btns}</div>
    </div>
  </section>
</div>
<!-- /wp:html -->
"""

out = pathlib.Path(__file__).parent
for k, t in T.items():
    (out / f"sidequest-{k}.html").write_text(page(t), encoding="utf-8")
    print("wrote", out / f"sidequest-{k}.html")

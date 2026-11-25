# Developing SideQuest

- **Theater mode**: both apps inject a script into crazygames.com game pages that makes `#game-iframe`
  `position: fixed` over the whole view (and releases ancestors with transform/contain). The bare
  `/embed/<slug>` URLs are not used: loaded on their own they break the CrazyGames SDK, and many
  games refuse embedding (401).
- **Focus**: macOS activates the app / re-activates the last frontmost app. Windows uses
  `win.focus()` / `win.blur()` (blur hands the foreground to the next window in z-order).
- **Mac URL hooks**: `sidequest://play/<slug>`, `sidequest://swap`, `sidequest://toggle`,
  `sidequest://snap[/peek]` (debug: writes `~/Library/Caches/SideQuest-snap.png`; `peek` hides a
  covering dialog for the capture only).
- **Electron debug capture**: `SIDEQUEST_SNAP=/tmp/s.png SIDEQUEST_PLAY=helix-jump npm start`
  writes the bar + game captures and quits.
- **Settings**: macOS `defaults read games.shadow.sidequest`; Windows `%APPDATA%/SideQuest Arcade/settings.json`.
- **Release**: `./build.sh zip` → `SideQuest-Mac.zip`; `cd windows && npm run pack:win`, then zip
  `windows/dist/SideQuest-win32-x64` as `SideQuest-Windows-x64.zip`; attach both to a GitHub release
  (the README links to `releases/latest/download/<file>`, so names must stay the same).

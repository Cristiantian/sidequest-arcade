const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('sq', {
  act: (name, arg) => ipcRenderer.send('act', name, arg),
  onState: (fn) => ipcRenderer.on('state', (_e, s) => fn(s)),
});

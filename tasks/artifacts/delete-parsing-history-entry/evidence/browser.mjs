import fs from 'node:fs';
const root = '/tmp/moepeek-delete-smoke.hgfW1y';
const pages = await (await fetch('http://127.0.0.1:19222/json')).json();
const socket = new WebSocket(pages.find(page => page.type === 'page').webSocketDebuggerUrl);
await new Promise(resolve => socket.addEventListener('open', resolve, { once: true }));
let next = 0;
const pending = new Map();
let dialogResolve;
socket.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const {resolve, reject} = pending.get(message.id);
    pending.delete(message.id);
    message.error ? reject(message.error) : resolve(message.result);
  } else if (message.method === 'Page.javascriptDialogOpening') {
    console.log('confirmation:', message.params.message);
    dialogResolve?.();
  }
});
function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++next;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const result = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
await call('Page.enable');
await call('Page.navigate', {url: fs.readFileSync(root + '/url', 'utf8')});
await evaluate(`new Promise(resolve => {
  const timer = setInterval(() => {
    if (document.querySelectorAll('.delete-entry').length === 2 && !document.querySelector('#refresh').disabled) {
      clearInterval(timer); resolve();
    }
  }, 50);
})`);
console.log('loaded:', await evaluate(`({cards:document.querySelectorAll('.entry').length,deleteIcons:document.querySelectorAll('.delete-entry svg').length,labels:[...document.querySelectorAll('.delete-entry')].map(b=>b.getAttribute('aria-label'))})`));
const dialog = new Promise(resolve => { dialogResolve = resolve; });
const click = evaluate(`[...document.querySelectorAll('.entry')].find(e=>e.querySelector('.source').textContent==='delete synthetic skip').querySelector('.delete-entry').click()`);
await dialog;
await call('Page.handleJavaScriptDialog', {accept: false});
await click;
console.log('after cancel cards:', await evaluate(`document.querySelectorAll('.entry').length`));
const secondDialog = new Promise(resolve => { dialogResolve = resolve; });
const secondClick = evaluate(`[...document.querySelectorAll('.entry')].find(e=>e.querySelector('.source').textContent==='delete synthetic skip').querySelector('.delete-entry').click()`);
await secondDialog;
await call('Page.handleJavaScriptDialog', {accept: true});
await secondClick;
await evaluate(`new Promise(resolve => {
 const timer=setInterval(()=>{
  if(document.querySelectorAll('.entry').length===1 && !document.querySelector('#refresh').disabled){clearInterval(timer);resolve();}
 },50);
})`);
console.log('after delete:',await evaluate(`({cards:document.querySelectorAll('.entry').length,source:document.querySelector('.source').textContent,status:document.querySelector('#status').textContent})`));
const shot = await call('Page.captureScreenshot', {format:'png'});
fs.writeFileSync(root+'/after-delete.png',Buffer.from(shot.data,'base64'));
await call('Browser.close');
socket.close();

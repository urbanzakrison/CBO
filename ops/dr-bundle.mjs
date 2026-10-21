// Offline QA building blocks, NOT a production exporter or automatic restorer.
import {createHash} from 'node:crypto';
export const sha256=bytes=>createHash('sha256').update(bytes).digest('hex');
export function manifest(files) {
 return Object.fromEntries(Object.entries(files).sort(([a],[b])=>a.localeCompare(b)).map(([name,data])=>{
  if(!/^[a-z0-9][a-z0-9._-]*$/.test(name)||!Buffer.isBuffer(data))throw Error('INVALID_BUNDLE_ENTRY');
  return [name,{bytes:data.length,sha256:sha256(data)}];
 }));
}
export function verify(files,expected) {
 if(JSON.stringify(manifest(files))!==JSON.stringify(expected))throw Error('BUNDLE_INTEGRITY_FAILED');
}
// Send the secret through an anonymous pipe, never through argv or environment.
export async function crypt(input,passphrase,home,decrypt=false) {
 if(!Buffer.isBuffer(input)||typeof passphrase!=='string'||passphrase.length<32||/[\r\n\0]/.test(passphrase)||!home)throw Error('INVALID_ENCRYPTION_INPUT');
 const {spawn}=await import('node:child_process');
 return new Promise((resolve,reject)=>{
  const args=['--homedir',home,'--batch','--no-tty','--pinentry-mode','loopback','--passphrase-fd','3','--no-symkey-cache',...(decrypt?['--decrypt']:['--symmetric','--cipher-algo','AES256','--compress-algo','none'])];
  const child=spawn('gpg',args,{stdio:['pipe','pipe','ignore','pipe']});const chunks=[];let bytes=0,settled=false;
  const fail=()=>{if(!settled){settled=true;child.kill('SIGKILL');reject(Error('ENCRYPTION_OR_DECRYPTION_FAILED'));}};
  const timer=setTimeout(fail,60000);
  for(const stream of [child.stdin,child.stdio[3]])stream.on('error',fail);
  child.on('error',fail);child.stdout.on('data',b=>{bytes+=b.length;if(bytes>512*1024*1024)fail();else chunks.push(b);});
  child.on('close',code=>{clearTimeout(timer);if(settled)return;if(code!==0)return fail();settled=true;resolve(Buffer.concat(chunks));});
  child.stdio[3].end(passphrase+'\n');child.stdin.end(input);
 });
}

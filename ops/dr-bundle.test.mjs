import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,chmod,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomBytes} from 'node:crypto';
import {manifest,verify,crypt,sha256} from './dr-bundle.mjs';
test('manifest detects changed, missing and extra files and rejects unsafe entry names',()=>{
 const files={'schema.sql':Buffer.from('synthetic schema'),'image.png':Buffer.from('synthetic binary')},m=manifest(files);
 verify(files,m);for(const bad of [{...files,'schema.sql':Buffer.from('changed')},{'schema.sql':files['schema.sql']},{...files,extra:Buffer.from('x')}])assert.throws(()=>verify(bad,m));
 assert.throws(()=>manifest({'../escape':Buffer.from('x')}));
});
test('GnuPG authenticated encrypted round trip, two private copies, wrong key and corruption',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'cbo-dr-unit-'));await chmod(dir,0o700);
 try{
  const key=randomBytes(32).toString('base64url'),plain=Buffer.from('SYNTHETIC_AUTH_AND_PRIVATE_IMAGE');
  const encrypted=await crypt(plain,key,dir);assert.ok(!encrypted.includes(plain));
  const a=join(dir,'private-a.gpg'),b=join(dir,'private-b.gpg');await writeFile(a,encrypted,{mode:0o600,flag:'wx'});await writeFile(b,encrypted,{mode:0o600,flag:'wx'});
  assert.equal(sha256(await readFile(a)),sha256(await readFile(b)));assert.deepEqual(await crypt(await readFile(b),key,dir,true),plain);
  await assert.rejects(()=>crypt(encrypted,randomBytes(32).toString('hex'),dir,true));
  const corrupt=Buffer.from(encrypted);corrupt[corrupt.length-10]^=1;await assert.rejects(()=>crypt(corrupt,key,dir,true));
  await assert.rejects(()=>crypt(plain,'short',dir));
 }finally{await rm(dir,{recursive:true,force:true});}
});

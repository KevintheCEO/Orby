import { randomBytes, createHash, createCipheriv, createDecipheriv } from 'node:crypto';
export const token=()=>randomBytes(32).toString('base64url');
export const digest=value=>createHash('sha256').update(String(value)).digest('hex');
export function fail(condition,status,message){if(!condition)throw Object.assign(new Error(message),{status});}
export function codec(key){
  fail(key.length===32,500,'A 32-byte storage key is required');
  return {
    seal(value){const iv=randomBytes(12),c=createCipheriv('aes-256-gcm',key,iv);const data=Buffer.concat([c.update(JSON.stringify(value)),c.final()]);return Buffer.concat([iv,c.getAuthTag(),data]).toString('base64');},
    open(value){const b=Buffer.from(value,'base64'),c=createDecipheriv('aes-256-gcm',key,b.subarray(0,12));c.setAuthTag(b.subarray(12,28));return JSON.parse(Buffer.concat([c.update(b.subarray(28)),c.final()]).toString());}
  };
}
export function safeOrigin(value,{development=false}={}){
  const u=new URL(value);
  fail(!u.username&&!u.password&&!u.search&&!u.hash&&u.pathname==='/',400,'Use the service origin only');
  fail(u.protocol==='https:'||(development&&u.protocol==='http:'&&['localhost','127.0.0.1','[::1]'].includes(u.hostname)),400,'HTTPS is required outside loopback tests');
  return u.origin;
}

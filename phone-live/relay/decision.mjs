import {z} from 'zod';
import {digest,fail} from './security.mjs';
export const decisionFields={revision:z.string().regex(/^[a-f0-9]{64}$/),decision:z.string().regex(/^(allow|deny|stop|choice:[0-7]|reply:[a-f0-9]{64})$/),nonce:z.string().uuid(),expiresAt:z.number().int(),answer:z.string().min(1).max(2000).optional()};
export function validateDecision(r,b){
 if(r.kind==='stop'){fail(b.decision==='stop'&&b.answer===undefined,400,'Confirm Stop this task');return;}
 if((r.kind||'permission')==='permission'){fail(['allow','deny'].includes(b.decision)&&b.answer===undefined,400,'Choose Allow once or Deny');return;}
 fail(r.kind==='question',400,'Unsupported request type');
 const choice=/^choice:([0-7])$/.exec(b.decision);
 if(choice){fail(b.answer===undefined&&Number(choice[1])<(r.choices||[]).length,400,'Choose one current answer');return;}
 fail(r.canReply&&b.answer?.trim()&&b.decision==='reply:'+digest(b.answer),400,'The current question cannot accept this response');
}

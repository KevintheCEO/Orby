export function phoneSummary(state,presence){
 const groups=new Map();
 for(const t of state.tasks||[]){
  const project=t.title.trim().slice(0,100)||'Current project',key=t.provider+'\n'+project;
  let step=t.state==='attention'?'Needs your attention':t.state==='error'?'Needs a check':t.state==='idle'?'Ready':'Working';
  const d=t.detail||'';
  if(/waiting.*(input|you)|needs.*input/i.test(d))step='Waiting for you';
  else if(/test|verify|check/i.test(d))step='Checking the work';
  else if(/edit|writing|implement/i.test(d))step='Making changes';
  else if(/research|search|brows/i.test(d))step='Researching';
  else if(/think|reason/i.test(d))step='Thinking';
  const old=groups.get(key);if(old)old.taskCount++;else groups.set(key,{id:t.id,provider:t.provider,project,state:t.state,step,taskCount:1});
 }
 return {away:presence?.away===true,presenceKnown:!!presence,projects:[...groups.values()],pendingCount:state.requests?.filter(r=>r.kind!=='stop').length||0};
}

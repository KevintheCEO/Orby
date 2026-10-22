using System;
using System.Collections.Generic;
public sealed class OrbyProviderLife {
 public string State, Detail; public bool Sleeping;
}
public sealed class OrbyProviderLifecycle {
 readonly Dictionary<string,DateTime> idle=new Dictionary<string,DateTime>();
 public OrbyProviderLife Evaluate(string id,bool fresh,bool open,bool readable,string state,DateTime now) {
  if(!fresh){idle.Remove(id);return new OrbyProviderLife{State="unknown",Detail="Waiting for activity"};}
  if(!open){idle.Remove(id);return new OrbyProviderLife{State="sleep",Detail="Sleeping · app closed",Sleeping=true};}
  if(!readable){idle.Remove(id);return new OrbyProviderLife{State="unknown",Detail="App open · waiting for activity"};}
  if(state=="working" || state=="attention" || state=="error"){idle.Remove(id);return new OrbyProviderLife{State=state,Detail=state=="working"?"Working":state=="attention"?"Needs your input":"Task error"};}
  DateTime since;if(!idle.TryGetValue(id,out since)){since=now;idle[id]=since;}
  bool sleeping=(now-since).TotalMinutes>=10;
  return new OrbyProviderLife{State=sleeping?"sleep":"idle",Sleeping=sleeping,Detail=sleeping?"Sleeping · idle for 10 minutes":"Ready for your next chat"};
 }
}

using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
public static class OrbyFeedWorker {
 public static Task<object[]> Poll(Type feed,string db){return Task.Run(()=>{
  var list=feed.GetMethod("List");var read=feed.GetMethod("Read");var result=new List<object>();
  foreach(object meta in (IEnumerable)list.Invoke(null,new object[]{db})){try{result.Add(read.Invoke(null,new object[]{meta}));}catch{}}
  return result.ToArray();
 });}
}

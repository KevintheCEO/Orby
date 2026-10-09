using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
public sealed class OrbyLogPath {public string Path;public long Length;}
public static class OrbyLogDiscovery {
 public static Task<OrbyLogPath[]> Poll(string[] roots,DateTime floor){return Task.Run(()=>{
  var result=new List<OrbyLogPath>();var visited=new HashSet<string>(StringComparer.OrdinalIgnoreCase);var stack=new Stack<string>(roots);
  while(stack.Count>0){var dir=stack.Pop();if(!visited.Add(dir))continue;
   try{foreach(var file in Directory.GetFiles(dir,"*.log")){var info=new FileInfo(file);if(info.LastWriteTimeUtc>floor)result.Add(new OrbyLogPath{Path=info.FullName,Length=info.Length});}}catch{}
   try{foreach(var child in Directory.GetDirectories(dir)){if((File.GetAttributes(child)&FileAttributes.ReparsePoint)==0)stack.Push(child);}}catch{}
  }
  return result.ToArray();
 });}
}

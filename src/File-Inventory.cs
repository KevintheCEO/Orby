using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
public sealed class OrbyFileRow {public string FullName,Name;public long Length;public DateTime LastWriteTimeUtc;}
public sealed class OrbyFileInventory {
 public bool Valid;public OrbyFileRow[] Files=new OrbyFileRow[0];public HashSet<string> Paths=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
 public static Task<OrbyFileInventory> Poll(string folder,int maximum){return Task.Run(()=>{
  var result=new OrbyFileInventory();try{
   var rows=new List<OrbyFileRow>();foreach(var file in new DirectoryInfo(folder).GetFiles()){
    try{rows.Add(new OrbyFileRow{FullName=file.FullName,Name=file.Name,Length=file.Length,LastWriteTimeUtc=file.LastWriteTimeUtc});result.Paths.Add(file.FullName);}catch{}
   }
   result.Files=rows.OrderByDescending(x=>x.LastWriteTimeUtc).Take(maximum).ToArray();result.Valid=true;
  }catch{}return result;
 });}
}

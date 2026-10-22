// Adapted from Louis-CFM/coucou windows/src-tauri/src/files.rs (MIT).
// Copyright (c) 2026 Louis Raille. See third-party/Coucou-LICENSE.txt.
using System;
using System.IO;
using System.Threading.Tasks;
public sealed class OrbyFileResult {public string Path;public string Name;public long Size;}
public static class OrbyFileInbox {
 public static Task<OrbyFileResult> CopyAsync(string source,string inbox){return Task.Run(()=>Copy(source,inbox));}
 public static OrbyFileResult Copy(string source,string inbox){
  var info=new FileInfo(source);if(!info.Exists)throw new IOException("Drop a file, rather than a folder.");
  if(info.Length>100*1024*1024)throw new IOException("Use files under 100 MB for the shelf.");
  Directory.CreateDirectory(inbox);string name=info.Name,stem=System.IO.Path.GetFileNameWithoutExtension(name),ext=info.Extension;
  for(int i=1;i<10000;i++){
   string path=System.IO.Path.Combine(inbox,i==1?name:stem+" ("+i+")"+ext);
   FileStream dest;
   try{dest=new FileStream(path,FileMode.CreateNew,FileAccess.Write);}catch(IOException){if(File.Exists(path))continue;throw;}
   try{using(dest)using(var src=File.OpenRead(source)){src.CopyTo(dest);}
    File.SetLastWriteTimeUtc(path,DateTime.UtcNow);return new OrbyFileResult{Path=path,Name=System.IO.Path.GetFileName(path),Size=info.Length};
   }catch{dest.Dispose();File.Delete(path);throw;}

  }throw new IOException("Could not create a unique file copy.");
 }
}

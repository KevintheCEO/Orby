using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
public sealed class OrbyUsageSnapshot {
 public string ErrorKind="";public bool Connected; public string Plan="",Status="Not connected",LimitsJson="",UsageJson="";
 public DateTime At=DateTime.UtcNow;
}
public static class OrbyUsageWorker {
 public static Task<OrbyUsageSnapshot> PollAvailable(string stateDirectory){return Task.Run(()=>{
  string executable=FindExecutable();
  if(executable==null)return new OrbyUsageSnapshot{Status="Install or open Codex to show account usage"};
  var result=Read(executable,stateDirectory);
  if(result.Connected){try{File.WriteAllText(Path.Combine(stateDirectory,"usage-cache.json"),new JavaScriptSerializer().Serialize(result));}catch{}}
  return result;
 });}
 static string FindExecutable(){
  try{string root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"OpenAI","Codex","bin");if(Directory.Exists(root)){var files=Directory.GetFiles(root,"codex.exe",SearchOption.AllDirectories);if(files.Length>0)return files[0];}}catch{}
  return null;
 }
 public static OrbyUsageSnapshot Cached(string stateDirectory){try{var value=new JavaScriptSerializer().Deserialize<OrbyUsageSnapshot>(File.ReadAllText(Path.Combine(stateDirectory,"usage-cache.json")));if(value!=null&&value.Connected&&value.At<=DateTime.UtcNow&&(DateTime.UtcNow-value.At).TotalSeconds<180)return value;}catch{}return null;}
 public static Task<OrbyUsageSnapshot> Poll(string executable,string stateDirectory){return Task.Run(()=>Read(executable,stateDirectory));}
 static Dictionary<string,object> Map(object value){return value as Dictionary<string,object>;}
 static object Get(Dictionary<string,object> value,string key){object result;return value!=null&&value.TryGetValue(key,out result)?result:null;}
 public static OrbyUsageSnapshot Read(string executable,string stateDirectory){
  var result=new OrbyUsageSnapshot(); Process process=null;var json=new JavaScriptSerializer();
  try {
   Directory.CreateDirectory(stateDirectory);
   string directory=stateDirectory.Replace('\\','/');
   string arguments="app-server -c \"sqlite_home=\\\""+directory+"\\\"\" -c \"log_dir=\\\""+directory+"\\\"\"";
   var start=new ProcessStartInfo(executable,arguments){UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true};
   process=Process.Start(start);process.ErrorDataReceived+=(s,e)=>{};process.BeginErrorReadLine();
   process.StandardInput.WriteLine("{\"id\":0,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"orby_companion\",\"version\":\"5.5\"}}}");process.StandardInput.Flush();
   bool sent=false;int responses=0;var watch=Stopwatch.StartNew();
   while(watch.Elapsed.TotalSeconds<18 && !process.HasExited){
    var read=process.StandardOutput.ReadLineAsync();if(!read.Wait(Math.Max(1,18000-(int)watch.ElapsedMilliseconds)))break;
    var line=read.Result;if(line==null)break;Dictionary<string,object> message;
    try{message=json.Deserialize<Dictionary<string,object>>(line);}catch{continue;}
    var id=Get(message,"id");if(id==null)continue;int number; if(!int.TryParse(id.ToString(),out number))continue;
    var body=Map(Get(message,"result"));
    if(number==0 && !sent && body!=null){
     sent=true;process.StandardInput.WriteLine("{\"method\":\"initialized\",\"params\":{}}");
     process.StandardInput.WriteLine("{\"id\":1,\"method\":\"account/read\",\"params\":{\"refreshToken\":false}}");
     process.StandardInput.WriteLine("{\"id\":2,\"method\":\"account/rateLimits/read\"}");
     process.StandardInput.WriteLine("{\"id\":3,\"method\":\"account/usage/read\"}");process.StandardInput.Flush();
    }else if(number>=1 && number<=3){
     responses++;
     if(number==1){var account=Map(Get(body,"account"));var type=Convert.ToString(Get(account,"type"));result.Connected=type=="chatgpt"||type=="chatgptAuthTokens";result.Plan=Convert.ToString(Get(account,"planType"));}
     if(number==2 && body!=null)result.LimitsJson=json.Serialize(body);
     if(number==3 && body!=null)result.UsageJson=json.Serialize(body);
     if(responses==3)break;
    }
   }
   result.Status=result.Connected?(result.LimitsJson.Length>0?"Live account data":"Quota not provided"):(sent?"Sign in to Codex to show account usage":"Account service could not be reached");
  }catch(Exception error){result.ErrorKind=error.GetType().Name;result.Status="Account service could not be reached";}
  finally{if(process!=null){try{if(!process.HasExited)process.Kill();}catch{}process.Dispose();}result.At=DateTime.UtcNow;}
  return result;
 }
}



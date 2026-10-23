using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

public sealed class OrbyPhoneClient : IDisposable {
 readonly HttpClient http; readonly Uri origin; readonly string credential; string session="";
 public OrbyPhoneClient(string address,string secret,bool localTest){
  origin=new Uri(address);if(!String.IsNullOrEmpty(origin.UserInfo)||origin.AbsolutePath!="/"||!String.IsNullOrEmpty(origin.Query)||!String.IsNullOrEmpty(origin.Fragment)||!(origin.Scheme=="https"||(localTest&&origin.Scheme=="http"&&origin.IsLoopback)))throw new ArgumentException("Use an HTTPS relay address without a path.");
  if(secret.Length<32||secret.Length>100)throw new ArgumentException("A valid PC connection code is required.");credential=secret;
  http=new HttpClient(new HttpClientHandler{AllowAutoRedirect=false});http.Timeout=TimeSpan.FromSeconds(8);http.MaxResponseContentBufferSize=98304;
 }
 async Task<string> Call(string method,string path,string json){
  if(!path.StartsWith("/desktop/",StringComparison.Ordinal)||path.Contains(".."))throw new ArgumentException("Invalid phone endpoint");
  using(var request=new HttpRequestMessage(new HttpMethod(method),new Uri(origin,path))){request.Headers.Authorization=new AuthenticationHeaderValue("Bearer",credential);if(!String.IsNullOrEmpty(json))request.Content=new StringContent(json,Encoding.UTF8,"application/json");
   using(var response=await http.SendAsync(request).ConfigureAwait(false)){if(!response.IsSuccessStatusCode)throw new InvalidOperationException("Phone service returned "+(int)response.StatusCode+". Reconnect or refresh; nothing was automatically approved.");return await response.Content.ReadAsStringAsync().ConfigureAwait(false);}
  }
 }
 public Task<string> Request(string method,string path,string json){return Task.Run(()=>Call(method,path,json));}
 public Task<string> Exchange(string instance,string json){return Task.Run(async()=>{if(session!=instance){await Call("POST","/desktop/session",new JavaScriptSerializer().Serialize(new {instance=instance})).ConfigureAwait(false);session=instance;}return await Call("POST","/desktop/sync",json).ConfigureAwait(false);});}
 public void Dispose(){http.Dispose();}
 public static string Hash(string text){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(text))).Replace("-","").ToLowerInvariant();}
 public static string Fingerprint(string key){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(Convert.FromBase64String(key))).Replace("-","").Substring(0,12);}
 public static void Save(string path,string value){
  if(value.Length>32768)throw new ArgumentException("Phone configuration too large");Directory.CreateDirectory(Path.GetDirectoryName(path));
  byte[] data=ProtectedData.Protect(Encoding.UTF8.GetBytes(value),Encoding.UTF8.GetBytes("Orby.Phone.v1"),DataProtectionScope.CurrentUser);string temporary=path+".new";
  File.WriteAllBytes(temporary,data);if(File.Exists(path))File.Replace(temporary,path,null);else File.Move(temporary,path);
 }
 public static string Load(string path){if(!File.Exists(path))return "";if(new FileInfo(path).Length>65536)throw new InvalidDataException("Invalid phone configuration");return Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(path),Encoding.UTF8.GetBytes("Orby.Phone.v1"),DataProtectionScope.CurrentUser));}
 static byte[] Signature(string encoded){
  byte[] d=Convert.FromBase64String(encoded);if(d.Length<8||d.Length>72||d[0]!=48||d[1]!=d.Length-2)throw new InvalidDataException("Invalid signature");var result=new byte[64];int p=2;
  for(int half=0;half<2;half++){if(d[p++]!=2)throw new InvalidDataException();int length=d[p++];if(length<1||length>33||p+length>d.Length)throw new InvalidDataException();if(length==33){if(d[p++]!=0)throw new InvalidDataException();length--;}Buffer.BlockCopy(d,p,result,half*32+32-length,length);p+=length;}
  if(p!=d.Length)throw new InvalidDataException();return result;
 }
 public static bool Verify(string key,string deviceId,string requestId,string revision,string decision,string nonce,long expiresAt,string signature){
  try{
   Guid parsed;if(!Guid.TryParse(deviceId,out parsed)||!Guid.TryParse(requestId,out parsed)||!Guid.TryParse(nonce,out parsed)||revision.Length!=64||(decision!="allow"&&decision!="deny"))return false;
   byte[] raw=Convert.FromBase64String(key);if(raw.Length!=65||raw[0]!=4)return false;var blob=new byte[72];blob[0]=0x45;blob[1]=0x43;blob[2]=0x53;blob[3]=0x31;blob[4]=32;Buffer.BlockCopy(raw,1,blob,8,64);
   using(var cng=CngKey.Import(blob,CngKeyBlobFormat.EccPublicBlob))using(var ec=new ECDsaCng(cng)){ec.HashAlgorithm=CngAlgorithm.Sha256;
    string text="OrbyPhone.v1\n"+deviceId+"\n"+requestId+"\n"+revision+"\n"+decision+"\n"+nonce+"\n"+expiresAt;return ec.VerifyData(Encoding.UTF8.GetBytes(text),Signature(signature));
   }
  }catch{return false;}
 }
}

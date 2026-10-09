using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Windows.Forms;
using System.Drawing;
using System.Reflection;
[assembly: AssemblyVersion("10.0.0.0")]
[assembly: AssemblyProduct("Orby")]
internal class OrbySetup : Form {
 Button install; Label status; string target;
 OrbySetup(){Text="Install Orby 10.0 beta";ClientSize=new Size(480,260);FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;BackColor=Color.FromArgb(15,15,21);ForeColor=Color.White;Font=new Font("Segoe UI",10);Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
  var title=new Label{Text="Your AI. Your Orby.",Font=new Font("Segoe UI",20,FontStyle.Bold),Bounds=new Rectangle(24,24,430,45)};
  var detail=new Label{Text="Install • open Orby • connect your AI\nChatGPT, Claude and Gemini. No API keys.\nClaude/Gemini status adapters are beta.",Bounds=new Rectangle(24,78,430,82)};
  status=new Label{Text="Installs for your Windows account. No automatic startup.",Bounds=new Rectangle(24,174,430,35)};
  install=new Button{Text="Install Orby",Bounds=new Rectangle(24,216,190,32),BackColor=Color.FromArgb(44,44,56),ForeColor=Color.White};install.Click+=Install;
  Controls.AddRange(new Control[]{title,detail,status,install});
 }
 void Install(object sender,EventArgs args){install.Enabled=false;try{
  target=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Orby","App","10.0-beta");Directory.CreateDirectory(target);
  using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("Orby.Payload"))using(var zip=new ZipArchive(stream,ZipArchiveMode.Read))foreach(var entry in zip.Entries){
   string path=Path.GetFullPath(Path.Combine(target,entry.FullName));if(!path.StartsWith(target+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Invalid package path");
   if(entry.Name.Length==0){Directory.CreateDirectory(path);continue;}Directory.CreateDirectory(Path.GetDirectoryName(path));using(var input=entry.Open())using(var output=File.Create(path))input.CopyTo(output);
  }
  status.Text="Installed. Your settings stay in your account's Orby folder.";install.Text="Open Orby";install.Click-=Install;install.Click+=delegate {Process.Start(new ProcessStartInfo(Path.Combine(target,"Orby.exe")){UseShellExecute=true,WorkingDirectory=target});Close();};
 }catch(Exception ex){status.Text="Install failed: "+ex.Message;}finally{install.Enabled=true;}}
 [STAThread] static void Main(){Application.EnableVisualStyles();Application.Run(new OrbySetup());}
}

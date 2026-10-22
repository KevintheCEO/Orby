using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyVersion("10.40.0.0")]
[assembly: AssemblyProduct("Orby")]

public static class OrbyInstall
{
    const string Marker = "Orby.Managed.Install.v1";
    public const string Release = "10.40";
    public static string DefaultDirectory
    {
        get
        {
            // Reuse a managed installation reached by the user's existing desktop
            // shortcut, including a workspace install. New users get the normal path.
            object shell=null,link=null;
            try
            {
                string shortcut=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),"Orby.lnk");
                if(File.Exists(shortcut))
                {
                    Type type=Type.GetTypeFromProgID("WScript.Shell");shell=Activator.CreateInstance(type);
                    link=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{shortcut});
                    string file=(string)link.GetType().InvokeMember("TargetPath",BindingFlags.GetProperty,null,link,null);
                    string folder=Path.GetDirectoryName(file);
                    if(String.Equals(Path.GetFileName(file),"Orby.exe",StringComparison.OrdinalIgnoreCase) &&
                       String.Equals(Path.GetFileName(folder),"Orby",StringComparison.OrdinalIgnoreCase) &&
                       File.Exists(Path.Combine(folder,".orby-install")) && File.ReadAllText(Path.Combine(folder,".orby-install")).StartsWith(Marker+"\n",StringComparison.Ordinal)) return folder;
                }
            }
            catch { }
            finally
            {
                if(link!=null)System.Runtime.InteropServices.Marshal.FinalReleaseComObject(link);
                if(shell!=null)System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
            }
            string workspaceHome=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Documents","Codex","Orby");
            if(File.Exists(Path.Combine(workspaceHome,".orby-install")) && File.ReadAllText(Path.Combine(workspaceHome,".orby-install")).StartsWith(Marker+"\n",StringComparison.Ordinal)) return workspaceHome;
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","Orby");
        }
    }
    static string Hash(Stream stream) { using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","").ToLowerInvariant(); }
    static string Full(string path) { return Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar); }
    public static string FileInside(string root, string relative)
    {
        if(String.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative) || relative.IndexOf(':')>=0 || relative.IndexOf('\\')>=0)
            throw new InvalidDataException("Invalid package path.");
        if(relative.Split('/').Any(p=>p==".." || p=="." || p.EndsWith(" ") || p.EndsWith("."))) throw new InvalidDataException("Invalid package path.");
        string path=Path.GetFullPath(Path.Combine(root,relative.Replace('/',Path.DirectorySeparatorChar)));
        if(!path.StartsWith(Full(root)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Package path escapes the Orby folder.");
        return path;
    }
    public static void InstallTo(string directory)
    {
        string root=Full(directory),parent=Path.GetDirectoryName(root);
        if(String.IsNullOrEmpty(parent) || Path.GetFileName(root)!="Orby") throw new InvalidOperationException("Install into a dedicated folder named Orby.");
        Directory.CreateDirectory(parent);
        // Never follow a directory junction or overwrite an unrelated existing folder.
        for(string p=root;!String.IsNullOrEmpty(p);p=Path.GetDirectoryName(p))
            if(Directory.Exists(p) && (File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0) throw new IOException("The installation path contains a directory link. Choose a regular local folder.");
        if(Directory.Exists(root) && Directory.EnumerateFileSystemEntries(root).Any() &&
            (!File.Exists(Path.Combine(root,".orby-install")) || !File.ReadAllText(Path.Combine(root,".orby-install")).StartsWith(Marker+"\n",StringComparison.Ordinal)))
            throw new IOException("This folder is not managed by Orby Setup. Its files have been left untouched.");
        if(File.Exists(Path.Combine(root,".orby-install")))
        {
            string[] lines=File.ReadAllLines(Path.Combine(root,".orby-install"));Version installed;
            if(lines.Length>1 && Version.TryParse(lines[1],out installed) && installed>new Version(Release))
                throw new IOException("A newer Orby is already installed. Use the newest setup file.");
        }
        string key;using(var bytes=new MemoryStream(Encoding.UTF8.GetBytes(root.ToUpperInvariant()))) key=Hash(bytes);
        using(var mutex=new Mutex(false,"Local\\OrbySetup-"+key))
        {
            bool locked=false;
            try { try { locked=mutex.WaitOne(0); } catch(AbandonedMutexException) { locked=true; }
                if(!locked) throw new IOException("Another Orby update is already running.");
                InstallLocked(root,parent);
            } finally { if(locked)mutex.ReleaseMutex(); }
        }
    }
    static void InstallLocked(string root,string parent)
    {
        string stage=Path.Combine(parent,".Orby-stage-"+Guid.NewGuid().ToString("N"));
        string backup=Path.Combine(parent,".Orby-backup-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stage);bool moved=false,committed=false;
        try
        {
            var asm=Assembly.GetExecutingAssembly();var expected=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            using(var reader=new StreamReader(asm.GetManifestResourceStream("Orby.Hashes")))
            { string line;while((line=reader.ReadLine())!=null) { if(line.Length<67)throw new InvalidDataException("Invalid file manifest.");string name=line.Substring(66);FileInside(stage,name);expected.Add(name,line.Substring(0,64)); } }
            var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using(var payload=asm.GetManifestResourceStream("Orby.Payload"))
            using(var zip=new ZipArchive(payload,ZipArchiveMode.Read))
                foreach(var entry in zip.Entries)
                {
                    string dest=FileInside(stage,entry.FullName),hash;
                    if(!expected.TryGetValue(entry.FullName,out hash) || !seen.Add(entry.FullName))throw new InvalidDataException("Unexpected or duplicate package file.");
                    Directory.CreateDirectory(Path.GetDirectoryName(dest));
                    using(var input=entry.Open())using(var output=new FileStream(dest,FileMode.CreateNew,FileAccess.Write))input.CopyTo(output);
                    using(var file=File.OpenRead(dest))if(Hash(file)!=hash)throw new InvalidDataException("Package verification failed: "+entry.FullName);
                }
            if(seen.Count!=expected.Count || !seen.Contains("Orby.exe") || !seen.Contains("Orby.ps1"))throw new InvalidDataException("The package is incomplete.");
            // Personal additions are local to the user and never in the shared payload.
            string personal=Path.Combine(root,"Personal");
            if(Directory.Exists(personal))CopyPersonal(personal,Path.Combine(stage,"Personal"));
            File.WriteAllText(Path.Combine(stage,".orby-install"),Marker+"\n"+Release+"\n",new UTF8Encoding(false));
            CloseInstalledOrby(root);
            if(Directory.Exists(root)){Directory.Move(root,backup);moved=true;}
            try { Directory.Move(stage,root);committed=true; }
            catch { if(moved && !Directory.Exists(root))Directory.Move(backup,root);throw; }
            // Backup/stage are unique paths created by this install, confined to the same parent.
            if(moved)Cleanup(backup,parent,".Orby-backup-");
        }
        finally { if(!committed)Cleanup(stage,parent,".Orby-stage-"); }
    }
    static void CopyPersonal(string source,string target)
    {
        if((File.GetAttributes(source)&FileAttributes.ReparsePoint)!=0)throw new IOException("Personal additions must be regular local files.");
        Directory.CreateDirectory(target);
        foreach(string file in Directory.GetFiles(source))
        {
            if((File.GetAttributes(file)&FileAttributes.ReparsePoint)!=0)throw new IOException("Personal additions cannot contain file links.");
            File.Copy(file,Path.Combine(target,Path.GetFileName(file)),false);
        }
        foreach(string directory in Directory.GetDirectories(source))CopyPersonal(directory,Path.Combine(target,Path.GetFileName(directory)));
    }
    static void Cleanup(string path,string parent,string prefix)
    {
        if(Full(Path.GetDirectoryName(path))!=Full(parent) || !Path.GetFileName(path).StartsWith(prefix,StringComparison.Ordinal))throw new IOException("Unexpected cleanup path.");
        if(Directory.Exists(path) && (File.GetAttributes(path)&FileAttributes.ReparsePoint)==0)
            try { Directory.Delete(path,true); } catch(IOException) {} catch(UnauthorizedAccessException) {}
    }
    static void CloseInstalledOrby(string root)
    {
        foreach(var process in Process.GetProcessesByName("Orby")) using(process)
        {
            string file;
            try { file=process.MainModule.FileName; } catch { throw new IOException("Please quit other copies of Orby before updating."); }
            if(!String.Equals(Full(file),Full(Path.Combine(root,"Orby.exe")),StringComparison.OrdinalIgnoreCase))continue;
            process.CloseMainWindow();
            if(!process.WaitForExit(8000))throw new IOException("Quit Orby, then press Update again. No app files were changed.");
        }
    }
    public static void CreateShortcuts(string root,string desktop,string programs)
    {
        string exe=Path.Combine(Full(root),"Orby.exe");if(!File.Exists(exe))throw new FileNotFoundException("Orby is not installed.");
        foreach(string folder in new[]{desktop,Path.Combine(programs,"Orby")})
        {
            Directory.CreateDirectory(folder);
            Type type=Type.GetTypeFromProgID("WScript.Shell");object shell=Activator.CreateInstance(type);object shortcut=null;
            try {
                shortcut=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{Path.Combine(folder,"Orby.lnk")});
                Type t=shortcut.GetType();
                t.InvokeMember("TargetPath",BindingFlags.SetProperty,null,shortcut,new object[]{exe});
                t.InvokeMember("WorkingDirectory",BindingFlags.SetProperty,null,shortcut,new object[]{Full(root)});
                t.InvokeMember("Description",BindingFlags.SetProperty,null,shortcut,new object[]{"Open Orby"});
                t.InvokeMember("IconLocation",BindingFlags.SetProperty,null,shortcut,new object[]{Path.Combine(root,"Orby.ico")+",0"});
                t.InvokeMember("Save",BindingFlags.InvokeMethod,null,shortcut,null);
            } finally {
                if(shortcut!=null)System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shortcut);
                System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
            }
        }
    }
}

internal sealed class OrbySetupCentral : Form
{
    readonly Label status=new Label();readonly Button install=new Button();readonly string root=OrbyInstall.DefaultDirectory;
    bool done;
    OrbySetupCentral()
    {
        Text="Orby Setup";ClientSize=new Size(540,330);AutoScaleMode=AutoScaleMode.Dpi;FormBorderStyle=FormBorderStyle.FixedDialog;
        MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;BackColor=Color.FromArgb(15,16,20);ForeColor=Color.White;Font=new Font("Segoe UI",10);
        Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        var title=new Label{Text="One home for Orby.",Font=new Font("Segoe UI",22,FontStyle.Bold),Bounds=new Rectangle(24,22,490,48)};
        var info=new Label{Text="Install once. Open Orby from your desktop.\nFuture setup files update this same folder.\nYour settings and AI connections stay in your account.",Bounds=new Rectangle(24,84,490,76)};
        var location=new Label{Text="App folder: "+root,ForeColor=Color.Silver,Bounds=new Rectangle(24,167,490,46)};
        status.SetBounds(24,221,490,43);status.Text="Desktop and Start menu shortcuts included. No admin needed.";
        install.SetBounds(24,278,190,34);install.Text=Directory.Exists(root)?"Update Orby":"Install Orby";install.FlatStyle=FlatStyle.Flat;install.Click+=Install;
        var folder=new Button{Text="Open app folder",Bounds=new Rectangle(230,278,170,34),FlatStyle=FlatStyle.Flat};folder.Click+=delegate{if(Directory.Exists(root))Process.Start(new ProcessStartInfo(root){UseShellExecute=true});};
        Controls.AddRange(new Control[]{title,info,location,status,install,folder});
    }
    async void Install(object sender,EventArgs e)
    {
        if(done){Process.Start(new ProcessStartInfo(Path.Combine(root,"Orby.exe")){UseShellExecute=true,WorkingDirectory=root});Close();return;}
        install.Enabled=false;status.Text="Verifying and installing Orby...";
        try {
            await Task.Run(()=>OrbyInstall.InstallTo(root));
            try { OrbyInstall.CreateShortcuts(root,Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),Environment.GetFolderPath(Environment.SpecialFolder.Programs));status.Text="Ready. Use the Orby shortcut on your desktop anytime."; }
            catch { status.Text="Orby installed. Shortcut creation failed; use Open app folder."; }
            done=true;install.Text="Open Orby";
        } catch(Exception error){status.Text=error.Message;MessageBox.Show(error.Message,"Orby setup",MessageBoxButtons.OK,MessageBoxIcon.Error);}
        finally { install.Enabled=true; }
    }
    protected override void OnFormClosing(FormClosingEventArgs e){if(!install.Enabled)e.Cancel=true;base.OnFormClosing(e);}
    [STAThread]static void Main(){Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new OrbySetupCentral());}
}

using System;
using System.IO;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

// Hosts the installed Windows PowerShell engine directly. File invocation keeps
// the machine's execution policy and normal PowerShell security checks in place.
internal sealed class OrbyHost : PSHost
{
    readonly Guid id = Guid.NewGuid();
    internal int ExitCode;
    public override Guid InstanceId { get { return id; } }
    public override string Name { get { return "Orby"; } }
    public override Version Version { get { return new Version(10,40); } }
    public override CultureInfo CurrentCulture { get { return CultureInfo.CurrentCulture; } }
    public override CultureInfo CurrentUICulture { get { return CultureInfo.CurrentUICulture; } }
    public override PSHostUserInterface UI { get { return null; } }
    public override void SetShouldExit(int code) { ExitCode = code; }
    public override void EnterNestedPrompt() { throw new NotSupportedException(); }
    public override void ExitNestedPrompt() { throw new NotSupportedException(); }
    public override void NotifyBeginApplication() { }
    public override void NotifyEndApplication() { }

    [STAThread]
    static int Main(string[] args)
    {
        bool check = args.Length == 2 && args[0] == "--check";
        string data = check ? Path.GetFullPath(args[1]) : Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Orby");
        try
        {
            if(args.Length != 0 && !check) throw new ArgumentException("Use Orby.exe without arguments to open Orby.");
            string folder = AppDomain.CurrentDomain.BaseDirectory;
            if(File.Exists(Path.Combine(folder,"SECURITY-REVIEW-PENDING.txt")))
                throw new InvalidOperationException("This package is on hold for security review.");
            string script = Path.Combine(folder,"Orby.ps1");
            if(!File.Exists(script)) throw new FileNotFoundException("Extract the complete Orby folder before opening Orby.exe.");
            Directory.SetCurrentDirectory(folder);
            var host = new OrbyHost();
            using(var runspace = RunspaceFactory.CreateRunspace(host))
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using(var shell = PowerShell.Create())
                {
                    shell.Runspace = runspace;
                    shell.AddCommand(script).AddParameter("DataDirectory",data);
                    if(check) shell.AddParameter("PerformanceCheck");
                    shell.Invoke();
                    if(shell.HadErrors)
                    {
                        Directory.CreateDirectory(data);
                        using(var writer = new StreamWriter(Path.Combine(data,"launch-errors.log"),true))
                            foreach(var error in shell.Streams.Error) writer.WriteLine(error.ToString());
                        if(shell.InvocationStateInfo.State == PSInvocationState.Failed && host.ExitCode == 0) host.ExitCode = 1;
                    }
                }
            }
            return host.ExitCode;
        }
        catch(Exception error)
        {
            Directory.CreateDirectory(data);
            File.AppendAllText(Path.Combine(data,"launch-errors.log"),error.ToString()+Environment.NewLine);
            if(!check) MessageBox.Show(error.Message+"\n\nDetails: "+Path.Combine(data,"launch-errors.log"),"Orby could not open",MessageBoxButtons.OK,MessageBoxIcon.Error);
            return 1;
        }
    }
}

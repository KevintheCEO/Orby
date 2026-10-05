using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class OrbyLauncher
{
    [STAThread]
    private static void Main()
    {
        string folder = AppDomain.CurrentDomain.BaseDirectory;
        string script = Path.Combine(folder, "Orby.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show("Orby.ps1 was not found beside Orby.exe.", "Orby", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        string powershell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows),
            "System32\\WindowsPowerShell\\v1.0\\powershell.exe");
        if (!File.Exists(powershell)) powershell = "powershell.exe";

        var start = new ProcessStartInfo
        {
            FileName = powershell,
            Arguments = "-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File \"" + script + "\"",
            WorkingDirectory = folder,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        Process.Start(start);
    }
}

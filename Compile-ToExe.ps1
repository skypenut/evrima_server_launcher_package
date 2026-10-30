# ==============================================================================
# Native Zero-Dependency EXE Compiler for EvrimaServerGUI.ps1
# Uses built-in Windows .NET Framework C# Compiler (No external modules needed)
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Ps1File   = Join-Path $ScriptDir "EvrimaServerGUI.ps1"
$OutputExe = Join-Path $ScriptDir "EvrimaServerLauncher.exe"

if (-not (Test-Path $Ps1File)) {
    Write-Error "Could not find EvrimaServerGUI.ps1 in $ScriptDir"
    exit 1
}

Write-Host "[1/3] Reading and encoding EvrimaServerGUI.ps1..." -ForegroundColor Cyan
$Ps1Bytes  = [System.IO.File]::ReadAllBytes($Ps1File)
$Base64Ps1 = [Convert]::ToBase64String($Ps1Bytes)

# Embed an Application Manifest requiring Administrator privileges (for Process Affinity/Priority)
$ManifestXml = @"
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="EvrimaServerLauncher.app"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
"@
$ManifestFile = Join-Path $ScriptDir "app.manifest"
Set-Content -Path $ManifestFile -Value $ManifestXml -Encoding UTF8

$CSharpSource = @"
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Windows.Forms;

namespace EvrimaLauncher {
    static class Program {
        [STAThread]
        static void Main() {
            try {
                string b64 = "$Base64Ps1";
                byte[] scriptBytes = Convert.FromBase64String(b64);
                string tempScript = Path.Combine(Path.GetTempPath(), "EvrimaServerGUI_Runtime.ps1");
                File.WriteAllBytes(tempScript, scriptBytes);

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File \"" + tempScript + "\"";
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;

                Process proc = Process.Start(psi);
                proc.WaitForExit();

                try { File.Delete(tempScript); } catch { }
            }
            catch (Exception ex) {
                MessageBox.Show("Failed to start Evrima Server Launcher:\n" + ex.Message, "Launcher Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
"@

Write-Host "[2/3] Compiling standalone Windows executable (EvrimaServerLauncher.exe)..." -ForegroundColor Cyan

$Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
$Params   = New-Object System.CodeDom.Compiler.CompilerParameters
$Params.GenerateExecutable = $true
$Params.OutputAssembly     = $OutputExe
$Params.CompilerOptions    = "/target:winexe /optimize+ /win32manifest:`"$ManifestFile`""
[void]$Params.ReferencedAssemblies.Add("System.dll")
[void]$Params.ReferencedAssemblies.Add("System.Windows.Forms.dll")

$Results = $Provider.CompileAssemblyFromSource($Params, $CSharpSource)
Remove-Item -Path $ManifestFile -Force -ErrorAction SilentlyContinue

if ($Results.Errors.HasErrors) {
    foreach ($Err in $Results.Errors) {
        Write-Host $Err.ToString() -ForegroundColor Red
    }
    exit 1
}

Write-Host "[3/3] SUCCESS! Created standalone executable:" -ForegroundColor Green
Write-Host "      -> $OutputExe" -ForegroundColor Yellow

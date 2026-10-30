# ==============================================================================
# The Isle: Evrima High-Performance GUI Server Manager + Engine.ini Updater
# Run as Administrator to allow Process Priority, Affinity & EcoQoS elevation
# ==============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- HARDWARE THREAD CALCULATION ---
$script:LogicalCores = [Environment]::ProcessorCount
$script:AllCoresMask = [IntPtr]([Math]::Pow(2, $script:LogicalCores) - 1)
$script:IsRunning    = $false
$script:ManualStop   = $false
$script:OptimizedPID = 0

# --- MAIN WINDOW SETUP ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "The Isle: Evrima Server Optimizer ($($script:LogicalCores) Threads Unlocked)"
$Form.Size = New-Object System.Drawing.Size(720, 690)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 34)
$Form.ForeColor = [System.Drawing.Color]::White
$FontRegular = New-Object System.Drawing.Font("Segoe UI", 9)
$FontBold    = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$FontConsole = New-Object System.Drawing.Font("Consolas", 9)
$Form.Font   = $FontRegular

function Add-LabeledInput($Parent, $LabelText, $DefaultValue, $XLabel, $XInput, $YPos, $LabelWidth = 120, $InputWidth = 420) {
    $Lbl = New-Object System.Windows.Forms.Label
    $Lbl.Text = $LabelText
    $Lbl.Location = New-Object System.Drawing.Point($XLabel, ($YPos + 3))
    $Lbl.Size = New-Object System.Drawing.Size($LabelWidth, 20)
    $Parent.Controls.Add($Lbl)

    $Txt = New-Object System.Windows.Forms.TextBox
    $Txt.Text = $DefaultValue
    $Txt.Location = New-Object System.Drawing.Point($XInput, $YPos)
    $Txt.Size = New-Object System.Drawing.Size($InputWidth, 24)
    $Txt.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 50)
    $Txt.ForeColor = [System.Drawing.Color]::White
    $Txt.BorderStyle = "FixedSingle"
    $Parent.Controls.Add($Txt)
    return $Txt
}

# --- CONFIGURATION INPUTS ---
$TxtServerDir = Add-LabeledInput $Form "Server Directory:" "C:\Server\TheIsleServer" 20 145 18 120 535
$TxtSteamCMD  = Add-LabeledInput $Form "SteamCMD Path:" "C:\steamcmd\steamcmd.exe" 20 145 48 120 535
$TxtMapPath   = Add-LabeledInput $Form "Gateway Map Path:" "/Game/TheIsle/Maps/Game/Gateway/Gateway" 20 145 78 120 380
$TxtPort      = Add-LabeledInput $Form "Port:" "7777" 535 580 78 40 100

# --- CHECKBOXES (OPTIMIZATION & AUTOMATION) ---
$ChkAllCores = New-Object System.Windows.Forms.CheckBox
$ChkAllCores.Text = "Unlock All Threads (-USEALLAVAILABLECORES + Affinity 0x$($script:AllCoresMask.ToString('X')))"
$ChkAllCores.Location = New-Object System.Drawing.Point(20, 112)
$ChkAllCores.Size = New-Object System.Drawing.Size(440, 22)
$ChkAllCores.Checked = $true
$Form.Controls.Add($ChkAllCores)

$ChkNoVerifyGC = New-Object System.Windows.Forms.CheckBox
$ChkNoVerifyGC.Text = "Reduce GC Spikes (-NoVerifyGC)"
$ChkNoVerifyGC.Location = New-Object System.Drawing.Point(470, 112)
$ChkNoVerifyGC.Size = New-Object System.Drawing.Size(215, 22)
$ChkNoVerifyGC.Checked = $true
$Form.Controls.Add($ChkNoVerifyGC)

$ChkHighPrio = New-Object System.Windows.Forms.CheckBox
$ChkHighPrio.Text = "Force High CPU Priority & Disable Windows Power Throttling"
$ChkHighPrio.Location = New-Object System.Drawing.Point(20, 136)
$ChkHighPrio.Size = New-Object System.Drawing.Size(440, 22)
$ChkHighPrio.Checked = $true
$Form.Controls.Add($ChkHighPrio)

$ChkAutoRestart = New-Object System.Windows.Forms.CheckBox
$ChkAutoRestart.Text = "Auto-Restart on Crash"
$ChkAutoRestart.Location = New-Object System.Drawing.Point(470, 136)
$ChkAutoRestart.Size = New-Object System.Drawing.Size(215, 22)
$ChkAutoRestart.Checked = $true
$Form.Controls.Add($ChkAutoRestart)

# --- ENGINE.INI UPDATER & BACKUP PANEL ---
$EngineBox = New-Object System.Windows.Forms.GroupBox
$EngineBox.Text = "Engine.ini Performance Updater & Backup Manager"
$EngineBox.ForeColor = [System.Drawing.Color]::LightSkyBlue
$EngineBox.Location = New-Object System.Drawing.Point(20, 166)
$EngineBox.Size = New-Object System.Drawing.Size(660, 118)
$Form.Controls.Add($EngineBox)

$TxtTickRate   = Add-LabeledInput $EngineBox "Max Tick Rate:" "30" 15 115 24 95 60
$TxtClientRate = Add-LabeledInput $EngineBox "Max Client Rate:" "100000" 190 300 24 105 85

$ChkSmoothFPS = New-Object System.Windows.Forms.CheckBox
$ChkSmoothFPS.Text = "Disable SmoothFrameRate (bSmoothFrameRate=false)"
$ChkSmoothFPS.ForeColor = [System.Drawing.Color]::White
$ChkSmoothFPS.Location = New-Object System.Drawing.Point(400, 25)
$ChkSmoothFPS.Size = New-Object System.Drawing.Size(250, 22)
$ChkSmoothFPS.Checked = $true
$EngineBox.Controls.Add($ChkSmoothFPS)

$ChkAutoPatchOnStart = New-Object System.Windows.Forms.CheckBox
$ChkAutoPatchOnStart.Text = "Auto-Backup & Patch Engine.ini before Server Start"
$ChkAutoPatchOnStart.ForeColor = [System.Drawing.Color]::Khaki
$ChkAutoPatchOnStart.Location = New-Object System.Drawing.Point(15, 56)
$ChkAutoPatchOnStart.Size = New-Object System.Drawing.Size(350, 22)
$ChkAutoPatchOnStart.Checked = $true
$EngineBox.Controls.Add($ChkAutoPatchOnStart)

function New-StyledButton($Parent, $Text, $X, $Y, $Width, $Height, $BackColor) {
    $Btn = New-Object System.Windows.Forms.Button
    $Btn.Text = $Text
    $Btn.Font = $FontBold
    $Btn.Location = New-Object System.Drawing.Point($X, $Y)
    $Btn.Size = New-Object System.Drawing.Size($Width, $Height)
    $Btn.BackColor = $BackColor
    $Btn.ForeColor = [System.Drawing.Color]::White
    $Btn.FlatStyle = "Flat"
    $Parent.Controls.Add($Btn)
    return $Btn
}

$BtnPatchEngine   = New-StyledButton $EngineBox "Backup & Update Engine.ini" 15 82 220 28 ([System.Drawing.Color]::FromArgb(45, 115, 165))
$BtnRestoreEngine = New-StyledButton $EngineBox "Restore Latest Backup" 245 82 195 28 ([System.Drawing.Color]::FromArgb(140, 95, 40))
$BtnViewBackups   = New-StyledButton $EngineBox "Open Backups Folder" 450 82 195 28 ([System.Drawing.Color]::FromArgb(70, 70, 80))

# --- LIVE TELEMETRY PANEL ---
$StatusBox = New-Object System.Windows.Forms.GroupBox
$StatusBox.Text = "Live Process Telemetry"
$StatusBox.ForeColor = [System.Drawing.Color]::LightGray
$StatusBox.Location = New-Object System.Drawing.Point(20, 292)
$StatusBox.Size = New-Object System.Drawing.Size(660, 52)
$Form.Controls.Add($StatusBox)

$LblStatus = New-Object System.Windows.Forms.Label
$LblStatus.Text = "Status: OFFLINE"
$LblStatus.Font = $FontBold
$LblStatus.ForeColor = [System.Drawing.Color]::Salmon
$LblStatus.Location = New-Object System.Drawing.Point(15, 20)
$LblStatus.Size = New-Object System.Drawing.Size(170, 20)
$StatusBox.Controls.Add($LblStatus)

$LblPID = New-Object System.Windows.Forms.Label
$LblPID.Text = "Shipping PID: N/A"
$LblPID.Location = New-Object System.Drawing.Point(195, 20)
$LblPID.Size = New-Object System.Drawing.Size(145, 20)
$StatusBox.Controls.Add($LblPID)

$LblRAM = New-Object System.Windows.Forms.Label
$LblRAM.Text = "Memory: 0.00 GB"
$LblRAM.Location = New-Object System.Drawing.Point(350, 20)
$LblRAM.Size = New-Object System.Drawing.Size(145, 20)
$StatusBox.Controls.Add($LblRAM)

$LblThreads = New-Object System.Windows.Forms.Label
$LblThreads.Text = "Active Threads: 0"
$LblThreads.Location = New-Object System.Drawing.Point(500, 20)
$LblThreads.Size = New-Object System.Drawing.Size(145, 20)
$StatusBox.Controls.Add($LblThreads)

# --- SERVER ACTION BUTTONS ---
$BtnStart  = New-StyledButton $Form "Start Server" 20 354 158 36 ([System.Drawing.Color]::FromArgb(40, 140, 70))
$BtnStop   = New-StyledButton $Form "Stop Server" 187 354 158 36 ([System.Drawing.Color]::FromArgb(180, 50, 50))
$BtnUpdate = New-StyledButton $Form "SteamCMD Update" 354 354 158 36 ([System.Drawing.Color]::FromArgb(50, 110, 170))
$BtnConfig = New-StyledButton $Form "Open Config Dir" 522 354 158 36 ([System.Drawing.Color]::FromArgb(75, 75, 85))
$BtnStop.Enabled = $false

# --- LOG OUTPUT CONSOLE ---
$LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.Location = New-Object System.Drawing.Point(20, 402)
$LogBox.Size = New-Object System.Drawing.Size(660, 230)
$LogBox.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 20)
$LogBox.ForeColor = [System.Drawing.Color]::LightGreen
$LogBox.Font = $FontConsole
$LogBox.ReadOnly = $true
$Form.Controls.Add($LogBox)

function Write-GuiLog($Message) {
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $LogBox.AppendText("[$Timestamp] $Message`r`n")
    $LogBox.ScrollToCaret()
}

# --- INI PARSER & SECTION UPDATER ---
function Set-IniKeyValue([string]$Content, [string]$Section, [string]$Key, [string]$Value) {
    $EscapedSection = [Regex]::Escape($Section)
    $SectionPattern = "(?m)^\[$EscapedSection\]\r?\n"
    if ($Content -match $SectionPattern) {
        # Check if key exists within this section before next section header
        $KeyPattern = "(?ms)(\[$EscapedSection\]\r?\n(?:(?!^\[).)*?)^$([Regex]::Escape($Key))=[^\r\n]*"
        if ($Content -match $KeyPattern) {
            $Content = [Regex]::Replace($Content, $KeyPattern, "`${1}$Key=$Value")
        } else {
            $Content = [Regex]::Replace($Content, $SectionPattern, "[$Section]`r`n$Key=$Value`r`n")
        }
    } else {
        if ($Content.Length -gt 0 -and -not $Content.EndsWith("`n")) {
            $Content += "`r`n"
        }
        $Content += "`r`n[$Section]`r`n$Key=$Value`r`n"
    }
    return $Content
}

function Update-EngineIni {
    $ConfigDir = Join-Path $TxtServerDir.Text "TheIsle\Saved\Config\WindowsServer"
    $EngineIni = Join-Path $ConfigDir "Engine.ini"
    $BackupDir = Join-Path $ConfigDir "Backups"

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    # 1. Create Timestamped Backup if Engine.ini exists
    if (Test-Path $EngineIni) {
        $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath = Join-Path $BackupDir "Engine_$Stamp.ini.bak"
        Copy-Item -Path $EngineIni -Destination $BackupPath -Force
        Write-GuiLog "BACKUP CREATED: Engine_$Stamp.ini.bak"
        $RawIni = Get-Content -Path $EngineIni -Raw
        if ($null -eq $RawIni) { $RawIni = "" }
    } else {
        Write-GuiLog "Engine.ini not found. Generating fresh optimized Engine.ini..."
        $RawIni = ""
    }

    # 2. Safely patch target sections while preserving EOS / custom blocks
    $TickRate   = $TxtTickRate.Text.Trim()
    $ClientRate = $TxtClientRate.Text.Trim()
    $SmoothStr  = if ($ChkSmoothFPS.Checked) { "false" } else { "true" }

    $RawIni = Set-IniKeyValue $RawIni "/Script/OnlineSubsystemUtils.IpNetDriver" "NetServerMaxTickRate" $TickRate
    $RawIni = Set-IniKeyValue $RawIni "/Script/OnlineSubsystemUtils.IpNetDriver" "MaxInternetClientRate" $ClientRate
    $RawIni = Set-IniKeyValue $RawIni "/Script/OnlineSubsystemUtils.IpNetDriver" "MaxClientRate" $ClientRate
    $RawIni = Set-IniKeyValue $RawIni "/Script/Engine.Engine" "bSmoothFrameRate" $SmoothStr

    Set-Content -Path $EngineIni -Value $RawIni.TrimStart() -Encoding UTF8
    Write-GuiLog "UPDATED Engine.ini -> TickRate=$TickRate, MaxClientRate=$ClientRate, bSmoothFrameRate=$SmoothStr"
}

function Restore-LatestEngineBackup {
    $ConfigDir = Join-Path $TxtServerDir.Text "TheIsle\Saved\Config\WindowsServer"
    $EngineIni = Join-Path $ConfigDir "Engine.ini"
    $BackupDir = Join-Path $ConfigDir "Backups"

    if (-not (Test-Path $BackupDir)) {
        Write-GuiLog "WARNING: No Backups directory found at $BackupDir"
        return
    }

    $LatestBackup = Get-ChildItem -Path $BackupDir -Filter "Engine_*.ini.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $LatestBackup) {
        Write-GuiLog "WARNING: No Engine.ini backup files found to restore."
        return
    }

    Copy-Item -Path $LatestBackup.FullName -Destination $EngineIni -Force
    Write-GuiLog "RESTORED Engine.ini from $($LatestBackup.Name)"
}

# --- CORE SERVER FUNCTIONS ---
function Start-EvrimaServer {
    $WrapperExe = Join-Path $TxtServerDir.Text "TheIsleServer.exe"
    if (-not (Test-Path $WrapperExe)) {
        Write-GuiLog "ERROR: Executable not found at $WrapperExe"
        return
    }

    if ($ChkAutoPatchOnStart.Checked) {
        Update-EngineIni
    }

    $ArgsList = @("$($TxtMapPath.Text)?Port=$($TxtPort.Text)", "-log")
    if ($ChkAllCores.Checked)   { $ArgsList += "-USEALLAVAILABLECORES" }
    if ($ChkNoVerifyGC.Checked) { $ArgsList += "-NoVerifyGC" }
    $LaunchString = $ArgsList -join " "

    Write-GuiLog "Launching Evrima Server with arguments: $LaunchString"
    Start-Process -FilePath $WrapperExe -WorkingDirectory $TxtServerDir.Text -ArgumentList $LaunchString | Out-Null

    $script:IsRunning    = $true
    $script:ManualStop   = $false
    $script:OptimizedPID = 0
    $BtnStart.Enabled    = $false
    $BtnStop.Enabled     = $true
    $BtnUpdate.Enabled   = $false
}

function Stop-EvrimaServer {
    $script:ManualStop = $true
    $script:IsRunning  = $false
    Write-GuiLog "Stopping Evrima Server processes..."

    Get-Process -Name "TheIsleServer-Win64-Shipping", "TheIsleServer" -ErrorAction SilentlyContinue | Stop-Process -Force
    
    $LblStatus.Text = "Status: OFFLINE"
    $LblStatus.ForeColor = [System.Drawing.Color]::Salmon
    $LblPID.Text = "Shipping PID: N/A"
    $LblRAM.Text = "Memory: 0.00 GB"
    $LblThreads.Text = "Active Threads: 0"
    $BtnStart.Enabled  = $true
    $BtnStop.Enabled   = $false
    $BtnUpdate.Enabled = $true
    Write-GuiLog "Server stopped."
}

# --- BACKGROUND MONITOR & OPTIMIZER TIMER ---
$MonitorTimer = New-Object System.Windows.Forms.Timer
$MonitorTimer.Interval = 2000
$MonitorTimer.Add_Tick({
    $ShippingProc = Get-Process -Name "TheIsleServer-Win64-Shipping" -ErrorAction SilentlyContinue

    if ($ShippingProc) {
        $LblStatus.Text = "Status: ONLINE"
        $LblStatus.ForeColor = [System.Drawing.Color]::LightGreen
        $LblPID.Text = "Shipping PID: $($ShippingProc.Id)"
        $MemGB = [Math]::Round($ShippingProc.WorkingSet64 / 1GB, 2)
        $LblRAM.Text = "Memory: $MemGB GB"
        $LblThreads.Text = "Active Threads: $($ShippingProc.Threads.Count)"

        if ($script:OptimizedPID -ne $ShippingProc.Id) {
            try {
                if ($ChkAllCores.Checked) {
                    $ShippingProc.ProcessorAffinity = $script:AllCoresMask
                }
                if ($ChkHighPrio.Checked) {
                    $ShippingProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                    powercfg /powerthrottling disable /p $ShippingProc.Id | Out-Null
                }
                $script:OptimizedPID = $ShippingProc.Id
                Write-GuiLog "Applied Hardware Optimizations to PID $($ShippingProc.Id) (Mask: 0x$($script:AllCoresMask.ToString('X')))"
            } catch {
                $script:OptimizedPID = $ShippingProc.Id
                Write-GuiLog "WARNING: Failed to elevate Priority/Affinity. Run EXE as Administrator!"
            }
        }
    } else {
        if ($script:IsRunning -and -not $script:ManualStop) {
            $WrapperProc = Get-Process -Name "TheIsleServer" -ErrorAction SilentlyContinue
            if (-not $WrapperProc) {
                $LblStatus.Text = "Status: CRASHED"
                $LblStatus.ForeColor = [System.Drawing.Color]::Orange
                if ($ChkAutoRestart.Checked) {
                    Write-GuiLog "Server termination detected! Auto-restarting..."
                    Start-EvrimaServer
                } else {
                    Stop-EvrimaServer
                }
            }
        }
    }
})
$MonitorTimer.Start()

# --- BUTTON CLICK EVENTS ---
$BtnStart.Add_Click({ Start-EvrimaServer })
$BtnStop.Add_Click({ Stop-EvrimaServer })
$BtnPatchEngine.Add_Click({ Update-EngineIni })
$BtnRestoreEngine.Add_Click({ Restore-LatestEngineBackup })

$BtnViewBackups.Add_Click({
    $BackupDir = Join-Path $TxtServerDir.Text "TheIsle\Saved\Config\WindowsServer\Backups"
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    Invoke-Item $BackupDir
})

$BtnUpdate.Add_Click({
    if (-not (Test-Path $TxtSteamCMD.Text)) {
        Write-GuiLog "ERROR: SteamCMD not found at $($TxtSteamCMD.Text)"
        return
    }
    Write-GuiLog "Starting SteamCMD Evrima branch update (AppID 412680)..."
    $SteamArgs = "+force_install_dir `"$($TxtServerDir.Text)`" +login anonymous +app_update 412680 -beta evrima validate +quit"
    Start-Process -FilePath $TxtSteamCMD.Text -ArgumentList $SteamArgs -Wait
    Write-GuiLog "SteamCMD update & validation complete."
})

$BtnConfig.Add_Click({
    $ConfigDir = Join-Path $TxtServerDir.Text "TheIsle\Saved\Config\WindowsServer"
    if (Test-Path $ConfigDir) {
        Invoke-Item $ConfigDir
    } else {
        Write-GuiLog "Config folder not found yet. Click 'Backup & Update Engine.ini' to initialize it."
    }
})

$Form.Add_FormClosing({ $MonitorTimer.Stop() })

Write-GuiLog "GUI Initialized. Detected $($script:LogicalCores) Logical Processors (Mask: 0x$($script:AllCoresMask.ToString('X')))."
[void]$Form.ShowDialog()

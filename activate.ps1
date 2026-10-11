if ($MyInvocation.InvocationName -ne '.') {
    Write-Error 'Run this script by dot-sourcing it: . .\activate.ps1'
    return
}
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or later is required. Run this script from pwsh.'
}

$InstallPathFile = Join-Path $PSScriptRoot '.ros2-install-path'
if (-not (Test-Path -LiteralPath $InstallPathFile -PathType Leaf)) {
    throw "ROS 2 installation path not found. Run '.\setup.ps1' first."
}

$RosRoot = (Get-Content -LiteralPath $InstallPathFile -Raw).Trim()
$RosSetup = Join-Path $RosRoot 'local_setup.bat'
if (-not (Test-Path -LiteralPath $RosSetup -PathType Leaf)) {
    throw "ROS setup file not found: $RosSetup. Rerun setup.ps1."
}

$PixiCommand = Get-Command pixi -CommandType Application -ErrorAction SilentlyContinue
if (-not $PixiCommand) {
    $PixiPath = Join-Path $env:USERPROFILE '.pixi\bin\pixi.exe'
    if (-not (Test-Path -LiteralPath $PixiPath -PathType Leaf)) {
        $PixiPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\pixi.exe'
    }
    if (-not (Test-Path -LiteralPath $PixiPath -PathType Leaf)) {
        throw 'Pixi was not found. Install it from https://pixi.sh/latest/ and open a new PowerShell window.'
    }
} else {
    $PixiPath = $PixiCommand.Source
}

Push-Location $RosRoot
try {
    $PixiHook = & $PixiPath shell-hook --shell powershell
    if ($LASTEXITCODE -ne 0) {
        throw "Pixi failed to create its PowerShell activation hook (exit code $LASTEXITCODE)."
    }
    Invoke-Expression ($PixiHook -join [Environment]::NewLine)
} finally {
    Pop-Location
}

$Command = "call `"$RosSetup`" >nul && set"
$ProcessInfo = [Diagnostics.ProcessStartInfo]::new($env:ComSpec)
$ProcessInfo.ArgumentList.Add('/u')
$ProcessInfo.ArgumentList.Add('/d')
$ProcessInfo.ArgumentList.Add('/c')
$ProcessInfo.ArgumentList.Add($Command)
$ProcessInfo.UseShellExecute = $false
$ProcessInfo.RedirectStandardOutput = $true
$ProcessInfo.RedirectStandardError = $true
$ProcessInfo.StandardOutputEncoding = [Text.Encoding]::Unicode
$ProcessInfo.StandardErrorEncoding = [Text.Encoding]::Unicode

$Process = [Diagnostics.Process]::new()
$Process.StartInfo = $ProcessInfo
try {
    if (-not $Process.Start()) {
        throw 'Could not start Command Prompt to load the ROS environment.'
    }
    $OutputTask = $Process.StandardOutput.ReadToEndAsync()
    $ErrorTask = $Process.StandardError.ReadToEndAsync()
    $Process.WaitForExit()
    $EnvironmentOutput = $OutputTask.GetAwaiter().GetResult()
    $ErrorOutput = $ErrorTask.GetAwaiter().GetResult()
    if ($Process.ExitCode -ne 0) {
        throw "ROS local_setup.bat failed (exit code $($Process.ExitCode)): $ErrorOutput"
    }
} finally {
    $Process.Dispose()
}

foreach ($Line in $EnvironmentOutput -split "`r?`n") {
    $EqualsIndex = $Line.IndexOf('=')
    if ($EqualsIndex -gt 0) {
        $Name = $Line.Substring(0, $EqualsIndex)
        $Value = $Line.Substring($EqualsIndex + 1)
        [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    }
}

Write-Host 'Activated the ROS 2 Lyrical Pixi and ROS environments.'

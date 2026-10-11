param(
    [string]$RosInstallRoot = (Join-Path $env:USERPROFILE 'ros2-lyrical')
)

$ErrorActionPreference = 'Stop'
$RequirementsFile = Join-Path $PSScriptRoot 'requirements.txt'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or later is required. Run this script from pwsh.'
}
if ($env:OS -ne 'Windows_NT' -or [Environment]::OSVersion.Version.Build -lt 22000) {
    throw 'The ROS 2 Lyrical Windows binary requires Windows 11.'
}
if (-not (Test-Path -LiteralPath $RequirementsFile -PathType Leaf)) {
    throw "Requirements file not found: $RequirementsFile"
}

$PixiCommand = Get-Command pixi -CommandType Application -ErrorAction SilentlyContinue
if ($PixiCommand) {
    $PixiPath = $PixiCommand.Source
} else {
    $PixiCandidates = @(
        (Join-Path $env:USERPROFILE '.pixi\bin\pixi.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\pixi.exe')
    )
    $PixiPath = $PixiCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
}

if (-not $PixiPath) {
    $WingetCommand = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue
    if (-not $WingetCommand) {
        throw 'Pixi is required. Install it from https://pixi.sh/latest/ and rerun setup.ps1.'
    }

    Write-Host 'Installing Pixi with WinGet...'
    & $WingetCommand.Source install --id prefix-dev.pixi --exact --source winget `
        --accept-source-agreements --accept-package-agreements --silent --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "WinGet failed to install Pixi (exit code $LASTEXITCODE)."
    }

    $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $MachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $env:Path = "$MachinePath;$UserPath;$env:Path"
    $PixiCommand = Get-Command pixi -CommandType Application -ErrorAction SilentlyContinue
    if ($PixiCommand) {
        $PixiPath = $PixiCommand.Source
    } else {
        $PixiCandidates = @(
            (Join-Path $env:USERPROFILE '.pixi\bin\pixi.exe'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\pixi.exe')
        )
        $PixiPath = $PixiCandidates |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
    }
    if (-not $PixiPath) {
        throw 'Pixi was installed but could not be found on PATH. Open a new PowerShell window and rerun setup.ps1.'
    }
}

$RosInstallRoot = [IO.Path]::GetFullPath($RosInstallRoot)
$RosInstallParent = Split-Path -Parent $RosInstallRoot
New-Item -ItemType Directory -Path $RosInstallParent -Force | Out-Null

$RosRoot = $null
if (Test-Path -LiteralPath $RosInstallRoot) {
    $ExistingManifest = Get-ChildItem -LiteralPath $RosInstallRoot -Filter pixi.toml -File -Recurse |
        Where-Object {
            (Test-Path -LiteralPath (Join-Path $_.DirectoryName 'local_setup.bat') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $_.DirectoryName 'preinstall_setup_windows.py') -PathType Leaf)
        } |
        Select-Object -First 1
    if ($ExistingManifest) {
        $RosRoot = $ExistingManifest.DirectoryName
        Write-Host "Using the existing ROS 2 installation at $RosRoot"
    } else {
        throw "ROS install directory exists but is incomplete: $RosInstallRoot. Choose an empty directory or remove that specific incomplete install."
    }
} else {
    $Headers = @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'robotControl-setup'
    }
    $ReleaseAsset = $null
    for ($Page = 1; $Page -le 10 -and -not $ReleaseAsset; $Page++) {
        $Releases = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/ros2/ros2/releases?per_page=100&page=$Page" `
            -Headers $Headers
        foreach ($Release in $Releases) {
            $ReleaseAsset = $Release.assets |
                Where-Object { $_.name -match '^ros2-lyrical-.*-windows-AMD64\.zip$' } |
                Select-Object -First 1
            if ($ReleaseAsset) {
                break
            }
        }
    }
    if (-not $ReleaseAsset) {
        throw 'Could not find a ROS 2 Lyrical Windows x64 binary in the ros2/ros2 GitHub releases. See https://github.com/ros2/ros2/releases.'
    }

    $ZipPath = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + '.zip')
    try {
        Write-Host "Downloading $($ReleaseAsset.name)..."
        Invoke-WebRequest -Uri $ReleaseAsset.browser_download_url -OutFile $ZipPath
        if ($ReleaseAsset.digest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
            $ExpectedHash = $Matches.hash
            $ActualHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash
            if ($ActualHash -ne $ExpectedHash) {
                throw "SHA-256 verification failed for $($ReleaseAsset.name)."
            }
        }

        New-Item -ItemType Directory -Path $RosInstallRoot | Out-Null
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $RosInstallRoot
    } finally {
        if (Test-Path -LiteralPath $ZipPath) {
            Remove-Item -LiteralPath $ZipPath
        }
    }

    $RosRoot = $RosInstallRoot
    $Manifest = Join-Path $RosRoot 'pixi.toml'
    if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
        $NestedManifest = Get-ChildItem -LiteralPath $RosInstallRoot -Filter pixi.toml -File -Recurse |
            Where-Object {
                (Test-Path -LiteralPath (Join-Path $_.DirectoryName 'local_setup.bat') -PathType Leaf) -and
                (Test-Path -LiteralPath (Join-Path $_.DirectoryName 'preinstall_setup_windows.py') -PathType Leaf)
            } |
            Select-Object -First 1
        if ($NestedManifest) {
            $RosRoot = $NestedManifest.DirectoryName
        }
    }

    foreach ($RequiredFile in @('pixi.toml', 'local_setup.bat', 'preinstall_setup_windows.py')) {
        $RequiredPath = Join-Path $RosRoot $RequiredFile
        if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf)) {
            throw "The downloaded ROS archive is missing '$RequiredFile'."
        }
    }
}

Push-Location $RosRoot
try {
    & $PixiPath install
    if ($LASTEXITCODE -ne 0) {
        throw "Pixi failed to install the ROS dependencies (exit code $LASTEXITCODE)."
    }

    if (-not (Test-Path -LiteralPath (Join-Path $RosRoot '.robotcontrol-preinstall-complete'))) {
        & $PixiPath run python preinstall_setup_windows.py
        if ($LASTEXITCODE -ne 0) {
            throw "The ROS Windows preinstall script failed (exit code $LASTEXITCODE)."
        }
        New-Item -ItemType File -Path (Join-Path $RosRoot '.robotcontrol-preinstall-complete') |
            Out-Null
    }

    $PipRequirements = @(Get-Content -LiteralPath $RequirementsFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') })
    if ($PipRequirements.Count -gt 0) {
        & $PixiPath run python -m pip install -r $RequirementsFile
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Python requirements into the ROS Pixi environment (exit code $LASTEXITCODE)."
        }
    }
} finally {
    Pop-Location
}

Set-Content -LiteralPath (Join-Path $PSScriptRoot '.ros2-install-path') `
    -Value $RosRoot -Encoding UTF8 -NoNewline

Write-Host "`nROS 2 Lyrical and project Python requirements are ready."
Write-Host 'Activate this environment in the current PowerShell session with: . .\activate.ps1'
Write-Host 'The ROS apt packages listed in requirements.txt are Ubuntu-only and are not installed by this Windows setup.'

[CmdletBinding()]
param (
    [string] $Configuration = 'Release',
    [string] $BuildType = 'Rebuild'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'


# -------------------------------
# debugging
# -------------------------------
if ($env:ARTIFACT_DEBUG_ENABLED -eq $true) {
    Write-Host "[INFO]: GitStatus.txt is to help find dirty status.  File should say repo and submodules are clean."
    Write-Host "[INFO]: Update the skip-worktree section in this script to fix CI builds."
    & git status > GitStatus.txt
    & git submodule foreach --recursive git status >> GitStatus.txt
    Push-AppveyorArtifact .\GitStatus.txt
    & tree /F /A > tree.txt
    Push-AppveyorArtifact .\tree.txt
}

# -------------------------------
# build artifacts
# -------------------------------
Push-Location $PSScriptRoot/../Setup

$hMSBuild = Resolve-Path hMSBuild.bat

$Version = '3.2.0.0';
if (![string]::IsNullOrWhiteSpace($env:APPVEYOR_BUILD_VERSION)) {
    $Version = $env:APPVEYOR_BUILD_VERSION
}

try {
    Write-Host "Creating installers for Git Extensions $Version";

    $msi = "../GitExtensions-$Version.msi";
    if (Test-Path $msi) {
        Write-Host "Removing GitExtensions-$Version.msi"
        Remove-Item -Path $msi -Force | Out-Null
    }

    try {
        Push-Location ..\GitExtensionsShellEx
        & $hMSBuild GitExtensionsShellEx.sln /p:Platform=Win32 /p:Configuration=$Configuration /t:Rebuild /nologo /v:m
        if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }
        & $hMSBuild GitExtensionsShellEx.sln /p:Platform=x64 /p:Configuration=$Configuration /t:Rebuild /nologo /v:m
        if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }
    }
    finally {
        Pop-Location
    }

    try {
        Push-Location ..\GitExtSshAskPass
        & $hMSBuild GitExtSshAskPass.sln /p:Platform=Win32 /p:Configuration=$Configuration /t:Rebuild /nologo /v:m
    }
    finally {
        Pop-Location
    }

    try {
        Push-Location ..\GitExtensionsVSIX

        $path = "..\GitExtensionsVSIX\bin\$Configuration";
        if (Test-Path $path) {
            Remove-Item -Path $path -Force | Out-Null
        }

        & $hMSBuild /p:Configuration=$Configuration /t:Rebuild /nologo /v:m /bl
        if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }
    }
    finally {
        Pop-Location
    }

    & $hMSBuild Setup.wixproj /t:$BuildType /p:Version=$Version /p:NumericVersion=$Version /p:Configuration=$Configuration /nologo /v:m /bl
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }

    Copy-Item -Path .\bin\$Configuration\GitExtensions.msi -Destination $PSScriptRoot/../GitExtensions-$Version.msi -Force
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }

    & .\Set-Portable.ps1 -IsPortable
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }

    & .\MakePortableArchive.cmd Release $env:APPVEYOR_BUILD_VERSION
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }

    & .\Set-Portable.ps1
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }
}
finally {
    Pop-Location
}


# -------------------------------
# sign artifacts
# -------------------------------
# do not sign artifacts for non-release branches
if ($env:APPVEYOR_PULL_REQUEST_TITLE) {
    return
}

# get files
$msi = (Resolve-Path $PSScriptRoot/../GitExtensions-*.msi)[0].Path;
$zip = (Resolve-Path $PSScriptRoot/../Setup/GitExtensions-Portable-*.zip)[0].Path;
$vsix = (Resolve-Path $PSScriptRoot/../GitExtensionsVSIX/bin/Release/GitExtensionsVSIX.vsix)[0].Path;

# archive files so we send them all in one go
$combined = ".\combined.$Version-unsigned.zip"
Compress-Archive -LiteralPath $msi, $zip, $vsix -CompressionLevel NoCompression -DestinationPath $combined -Force

# move the pdbs to the root folder, so the published artifact looks nicer
Move-Item -Path $PSScriptRoot/../Setup/GitExtensions-pdbs-*.zip -Destination $PSScriptRoot/../ -Force
Move-Item -Path $PSScriptRoot/../GitExtensionsVSIX/bin/Release/GitExtensionsVSIX.vsix -Destination $PSScriptRoot/../ -Force

if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }

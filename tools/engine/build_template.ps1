# Builds Seed Splicer's slim Windows release template (Godot engine without 3D etc.).
#
# Needs: Godot source checked out at the editor's exact version (4.7.2-stable) in -GodotSrc,
# Python with SCons (pip install scons), and VS Build Tools with C++ + Windows 11 SDK.
# Output: tools/engine/bin/seedsplicer_template_release.x86_64.exe (gitignored), which
# export_presets.cfg uses as the Windows custom release template.
#
#   powershell -ExecutionPolicy Bypass -File tools\engine\build_template.ps1
param(
    [string]$GodotSrc = 'E:\godot-src',
    [int]$Jobs = [Environment]::ProcessorCount
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$profilePath = Join-Path $here 'slim_windows.py'

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'No Visual Studio with the C++ tools found.' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'

Push-Location $GodotSrc
try {
    # d3d12=no must be on the command line: Godot's Windows platform flags override the profile.
    cmd /c "`"$vcvars`" >nul 2>&1 && python -m SCons profile=`"$profilePath`" d3d12=no -j$Jobs"
    if ($LASTEXITCODE -ne 0) { throw "SCons failed ($LASTEXITCODE)" }
} finally { Pop-Location }

$built = Join-Path $GodotSrc 'bin\godot.windows.template_release.x86_64.exe'
$outDir = Join-Path $here 'bin'
New-Item -ItemType Directory -Force $outDir | Out-Null
$out = Join-Path $outDir 'seedsplicer_template_release.x86_64.exe'
Copy-Item $built $out -Force
'{0} ({1:N1} MB)' -f $out, ((Get-Item $out).Length / 1MB)

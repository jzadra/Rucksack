[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FontSourceDirectory,

    [Parameter(Mandatory = $true)]
    [string]$LoaderSource
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $FontSourceDirectory -PathType Container)) {
    throw "Font source directory was not found: $FontSourceDirectory"
}

if (-not (Test-Path -LiteralPath $LoaderSource -PathType Leaf)) {
    throw "Font loader script was not found: $LoaderSource"
}

$fontDestination = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontRegistry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$loaderDirectory = Join-Path $env:LOCALAPPDATA 'Rucksack\scripts'
$loaderDestination = Join-Path $loaderDirectory 'load_user_fonts.ps1'
$startupDirectory = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDirectory 'Load User Fonts.lnk'

New-Item -ItemType Directory -Path $fontDestination -Force | Out-Null
New-Item -Path $fontRegistry -Force | Out-Null
New-Item -ItemType Directory -Path $loaderDirectory -Force | Out-Null

$fontFiles = Get-ChildItem -LiteralPath $FontSourceDirectory -File | Where-Object {
    $_.Extension -in '.ttf', '.otf'
}

foreach ($fontFile in $fontFiles) {
    $destination = Join-Path $fontDestination $fontFile.Name
    Copy-Item -LiteralPath $fontFile.FullName -Destination $destination -Force

    $fontType = if ($fontFile.Extension -ieq '.otf') { 'OpenType' } else { 'TrueType' }
    $registryName = "$($fontFile.BaseName) ($fontType)"
    New-ItemProperty -Path $fontRegistry -Name $registryName -Value $destination -PropertyType String -Force | Out-Null
    Write-Host "Installed per-user font file: $($fontFile.Name)"
}

Copy-Item -LiteralPath $LoaderSource -Destination $loaderDestination -Force

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$loaderDestination`""
$shortcut.WorkingDirectory = $loaderDirectory
$shortcut.WindowStyle = 7
$shortcut.Description = 'Load Rucksack per-user fonts into the Windows font table'
$shortcut.Save()

$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
& $powershell -NoProfile -ExecutionPolicy Bypass -File $loaderDestination
if ($LASTEXITCODE -ne 0) {
    throw "The per-user font loader failed with exit status $LASTEXITCODE"
}

Write-Host "Installed persistent font loader: $loaderDestination"
Write-Host "Created Startup shortcut: $shortcutPath"

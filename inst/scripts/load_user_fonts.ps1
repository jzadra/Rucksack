[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'

if (-not (Test-Path -LiteralPath $fontDirectory -PathType Container)) {
    exit 0
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace RucksackFontLoader {
    public static class NativeMethods {
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern int AddFontResource(string fileName);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr windowHandle,
            uint message,
            UIntPtr wParam,
            IntPtr lParam,
            uint flags,
            uint timeout,
            out UIntPtr result
        );
    }
}
'@

$fontFiles = Get-ChildItem -LiteralPath $fontDirectory -File | Where-Object {
    $_.Extension -in '.ttf', '.otf'
}

$failedFonts = [System.Collections.Generic.List[string]]::new()
foreach ($fontFile in $fontFiles) {
    $loaded = [RucksackFontLoader.NativeMethods]::AddFontResource($fontFile.FullName)
    if ($loaded -eq 0) {
        $failedFonts.Add($fontFile.Name)
        Write-Warning "Windows could not load font into the active session: $($fontFile.Name)"
    }
}

$broadcastResult = [UIntPtr]::Zero
[void][RucksackFontLoader.NativeMethods]::SendMessageTimeout(
    [IntPtr]0xffff,
    0x001D,
    [UIntPtr]::Zero,
    [IntPtr]::Zero,
    0x0002,
    5000,
    [ref]$broadcastResult
)

if ($failedFonts.Count -gt 0) {
    throw "Failed to load $($failedFonts.Count) font(s): $($failedFonts -join ', ')"
}

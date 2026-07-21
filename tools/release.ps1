# Yeni surum yayinlama akisi (tek komut):
#   powershell -ExecutionPolicy Bypass -File tools\release.ps1 -Version 1.0.1 [-Notes "degisiklikler"]
#
# Adimlar: project.godot surumunu gunceller -> exe'yi derler -> commit + tag +
# push -> GitHub Release olusturur ve exe'yi yukler. Oyuncularin oyunlari bir
# sonraki aciliste bu release'i gorur ve kendini gunceller (autoload/updater.gd).
# Gereksinim: gh CLI ile giris yapilmis olmali (gh auth login).

param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Notes = ""
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Surum bicimi X.Y.Z olmali (ornek: 1.0.1). Verilen: $Version"
}

$root = Split-Path -Parent $PSScriptRoot
$godot = "C:\Users\Onur\Downloads\GodotBin\Godot_v4.7-stable_win64_console.exe"
$projFile = Join-Path $root "project.godot"
$exePath = Join-Path $root "build\windows\WolfInWool.exe"
$repo = "onryzici/kuzu-koyu"
$tag = "v$Version"

# --- On kontroller ---
if (-not (Test-Path $godot)) { throw "Godot bulunamadi: $godot" }
gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh CLI giris yapmamis. Once calistir: gh auth login" }

# --- 1) project.godot surumunu guncelle (BOM'suz UTF8 — Godot BOM sevmez) ---
$content = [System.IO.File]::ReadAllText($projFile)
if ($content -match 'config/version="[^"]*"') {
    $content = $content -replace 'config/version="[^"]*"', "config/version=`"$Version`""
} else {
    throw "project.godot icinde config/version bulunamadi."
}
[System.IO.File]::WriteAllText($projFile, $content, (New-Object System.Text.UTF8Encoding $false))
Write-Host "project.godot -> $Version"

# --- 2) Derle ---
New-Item -ItemType Directory -Force (Split-Path $exePath) | Out-Null
& $godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { throw "Import basarisiz (cikis kodu $LASTEXITCODE)" }
& $godot --headless --path $root --export-release "Windows Desktop"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exePath)) { throw "Export basarisiz" }
Write-Host ("Exe hazir: {0:N1} MB" -f ((Get-Item $exePath).Length / 1MB))

# --- 3) Commit + tag + push ---
git -C $root add -A
git -C $root diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git -C $root commit -m "Release $tag"
    if ($LASTEXITCODE -ne 0) { throw "Commit basarisiz" }
}
git -C $root tag $tag
if ($LASTEXITCODE -ne 0) { throw "Tag olusturulamadi ($tag zaten var olabilir)" }
git -C $root push origin main
if ($LASTEXITCODE -ne 0) { throw "Push basarisiz" }
git -C $root push origin $tag
if ($LASTEXITCODE -ne 0) { throw "Tag push basarisiz" }

# --- 4) GitHub Release + exe yukleme ---
if ($Notes -eq "") { $Notes = "Surum $tag" }
gh release create $tag $exePath --repo $repo --title $tag --notes $Notes
if ($LASTEXITCODE -ne 0) { throw "Release olusturulamadi" }

Write-Host ""
Write-Host "YAYINLANDI: https://github.com/$repo/releases/tag/$tag"
Write-Host "Oyuncular bir sonraki aciliste guncelleme bildirimi gorecek."

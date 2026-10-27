# Vláčky – příprava čistého balíčku pro kamarády (spouští Lukáš na svém počítači).
# Vytvoří NOVOU složku (ne zip) bez dat, záloh .bak, staré kopie src a osobních nastavení.
# Použití:  powershell -ExecutionPolicy Bypass -File pripravit-balicek.ps1 [-Cil C:\cesta\vlacky-pro-kamarady]
param([string]$Cil = (Join-Path (Split-Path $PSScriptRoot -Parent) '..\vlacky-pro-kamarady'))
$zdroj = Split-Path $PSScriptRoot -Parent
$Cil = [IO.Path]::GetFullPath($Cil)
if (Test-Path $Cil) { Write-Host "Cíl už existuje: $Cil – smaž ho nebo zvol jiný (-Cil)."; exit 1 }
New-Item -ItemType Directory -Path $Cil | Out-Null

# robocopy: kód aplikace bez záloh .bak-*, bez staré kopie src a bez případných dat
robocopy $zdroj $Cil /E /XD (Join-Path $zdroj 'src') (Join-Path $zdroj 'data') (Join-Path $zdroj '.git') __pycache__ /XF 'pripravit-balicek.ps1' 'PRO-LUKASE.md' '*.bak-*' '*.bak' '.env' 'docker-compose.yml' 'Dockerfile.bak-*' 'auth.json' 'central.json' 'agent.json' 'ai.json' 'secret.key' 'decoder_types.json' 'vlacky.db' /NFL /NDL /NJH /NJS | Out-Null
# instalator\docker-compose.yml je potřeba (zdrojový docker-compose.yml v kořeni je jen Lukášův)
Copy-Item (Join-Path $PSScriptRoot 'docker-compose.yml') (Join-Path $Cil 'instalator\docker-compose.yml') -Force
Copy-Item (Join-Path $PSScriptRoot 'NAVOD.md') (Join-Path $Cil 'NAVOD.md') -Force

# osobní logo se v balíčku nahradí neutrálním nápisem „Vláčky“
Copy-Item (Join-Path $PSScriptRoot 'logo-neutralni.png') (Join-Path $Cil 'app\static\logo.png') -Force
Remove-Item (Join-Path $Cil 'instalator\logo-neutralni.png') -ErrorAction SilentlyContinue
foreach ($f in 'app\login.html', 'app\static\app.js') {
  $fp = Join-Path $Cil $f
  $x = [IO.File]::ReadAllText($fp, [Text.Encoding]::UTF8).Replace('Moje-vlacky.cz by Edys', 'Vláčky')
  [IO.File]::WriteAllText($fp, $x, (New-Object Text.UTF8Encoding $false))
}

# kontrola: nic osobního nesmí zbýt
$chyby = @()
Get-ChildItem $Cil -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($Cil.Length)
  if ($_.Name -match '^(auth|central|agent|ai)\.json$|secret\.key$|^\.env$|\.bak') { $chyby += "zakázaný soubor: $rel" }
  if ($_.Extension -eq '.db' -and $_.Name -ne 'jmri_decoders.db') { $chyby += "cizí databáze: $rel" }
  if ($_.Extension -in '.py','.yml','.md','.sh','.ps1','.cmd','.html','.js','.json','.txt') {
    $t = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if ($t -match 'sk-ant-[A-Za-z0-9]|l-system\.cz|qTVhnj|192\.168\.88\.|Edys') { $chyby += "osobní údaj v souboru: $rel" }
  }
}
if ($chyby) { Write-Host 'POZOR, v balíčku zůstalo něco osobního:'; $chyby | ForEach-Object { Write-Host "  $_" }; exit 1 }
Write-Host "Hotovo. Čistý balíček je ve složce: $Cil"
Write-Host 'Pošli kamarádům celou tuto složku (např. přes sdílení OneDrive/Disku). Návod je v NAVOD.md.'

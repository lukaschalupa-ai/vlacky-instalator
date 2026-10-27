# Vláčky – instalační průvodce pro Windows (Docker Desktop). Bez argumentů: nainstaluje nebo aktualizuje.
Set-Location $PSScriptRoot
$bad = '[\$"''#\\`]'

function Ask($q, $def) { $a = Read-Host "$q [$def]"; if ([string]::IsNullOrWhiteSpace($a)) { $def } else { $a } }

Write-Host '=== Vláčky – instalace ==='

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host 'Docker nebyl nalezen. Nainstaluj Docker Desktop: https://www.docker.com/products/docker-desktop/ a spusť ho.'
  exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) { Write-Host 'Docker Desktop neběží. Spusť ho, počkej než naběhne, a spusť průvodce znovu.'; exit 1 }

if (Test-Path .env) {
  Write-Host 'Nalezeno stávající nastavení (.env). Zachovávám ho a aplikaci jen znovu sestavím (aktualizace).'
  Write-Host 'Chceš nastavení vytvořit znovu? Smaž soubor instalator\.env a spusť průvodce znovu. Data se tím nesmažou.'
} else {
  $port = Ask 'Port, na kterém aplikace poběží' '8090'
  if ($port -notmatch '^\d+$') { Write-Host 'Port musí být číslo.'; exit 1 }
  $name = Ask 'Název aplikace (zobrazí se u ikony v telefonu)' 'Vláčky'
  if ($name -match $bad) { Write-Host 'Název nesmí obsahovat znaky $ " '' # \ ani zpětný apostrof.'; exit 1 }
  $data = Ask 'Složka pro data (databáze, fotky, zálohy)' (Join-Path $PSScriptRoot 'data')
  Write-Host 'Úvodní heslo (aspoň 8 znaků, nejlépe dlouhá věta; znaky $ " '' # \ nepoužívej).'
  $sec = Read-Host 'Heslo (prázdné = vygenerovat náhodné)' -AsSecureString
  $pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
  if ([string]::IsNullOrEmpty($pw)) {
    $pw = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
    Write-Host "Vygenerované heslo: $pw   (zapiš si ho; po přihlášení si ho můžeš změnit v Nastavení)"
  }
  if ($pw.Length -lt 8) { Write-Host 'Heslo musí mít aspoň 8 znaků.'; exit 1 }
  if ($pw -match $bad) { Write-Host 'Heslo nesmí obsahovat znaky $ " '' # \ ani zpětný apostrof.'; exit 1 }
  $cert = ''
  if ((Ask 'Chceš zapnout HTTPS (máš soubory fullchain.pem a privkey.pem)? a/n' 'n') -match '^[aAyY]') {
    $cert = Read-Host 'Složka s certifikátem'
    if (-not ((Test-Path "$cert\fullchain.pem") -and (Test-Path "$cert\privkey.pem"))) { Write-Host 'V té složce chybí fullchain.pem nebo privkey.pem.'; exit 1 }
  }
  New-Item -ItemType Directory -Force -Path $data | Out-Null
  $lines = @("APP_PASSWORD=$pw", "VLACKY_PORT=$port", "APP_NAME=$name", "VLACKY_DATA=$($data -replace '\\','/')", 'VLACKY_TZ=Europe/Prague')
  if ($cert) { $lines += "VLACKY_CERT_DIR=$($cert -replace '\\','/')" }
  [IO.File]::WriteAllLines((Join-Path $PSScriptRoot '.env'), $lines, (New-Object Text.UTF8Encoding $false))
  Write-Host 'Nastavení uloženo do instalator\.env (heslo je v něm čitelně – nikomu tento soubor neposílej).'
}

$files = @('-f', 'docker-compose.yml')
$envText = Get-Content .env -Raw
if ($envText -match '(?m)^VLACKY_CERT_DIR=') { $files += @('-f', 'docker-compose.https.yml') }

Write-Host 'Sestavuji a spouštím aplikaci (první sestavení může trvat několik minut)…'
docker compose @files up -d --build
if ($LASTEXITCODE -ne 0) { Write-Host 'Spuštění se nezdařilo, viz chyba výše.'; exit 1 }

$p = ([regex]::Match($envText, '(?m)^VLACKY_PORT=(.*)$')).Groups[1].Value.Trim()
$scheme = if ($envText -match '(?m)^VLACKY_CERT_DIR=') { 'https' } else { 'http' }
Write-Host ''
Write-Host "Hotovo. Otevři v prohlížeči:  ${scheme}://localhost:${p}  (z tabletu/telefonu v domácí síti použij IP adresu počítače)"
Write-Host 'Přihlas se úvodním heslem z instalator\.env a nastav si svoji centrálu v aplikaci.'
Write-Host 'Logy: docker compose logs -f      Zastavení: docker compose down   (ve složce instalator)'

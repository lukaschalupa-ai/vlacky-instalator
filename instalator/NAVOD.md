# Vláčky – instalace pro vlastní provoz

Aplikace Vláčky je evidence lokomotiv, dekodérů, příslušenství a jejich CV pro digitální modelovou železnici. Tento balíček si můžeš provozovat u sebe: začneš s **prázdnou databází, vlastním heslem a vlastním nastavením**. Žádná cizí data v něm nejsou.

## Co potřebuješ

- Počítač nebo NAS, který bude aplikaci provozovat (stačí, když je zapnutý, kdykoli chceš aplikaci používat):
  - **Windows 10/11** s [Docker Desktop](https://www.docker.com/products/docker-desktop/), nebo
  - **Linux** s Dockerem (včetně Raspberry Pi), nebo
  - **Synology NAS** s Container Managerem (DSM 7.2) / Dockerem (starší DSM).
- Internet při první instalaci (stáhnou se komponenty, pár minut).
- Prohlížeč na počítači, tabletu nebo telefonu ve stejné domácí síti.

## Instalace – Windows

1. Nainstaluj a spusť Docker Desktop.
2. Rozbal/zkopíruj balíček do libovolné složky, např. `C:\Vlacky`.
3. Ve složce `instalator` dvakrát klikni na **`instalovat.cmd`**.
4. Průvodce se zeptá na port (výchozí 8090), název aplikace, složku pro data a heslo. Heslo můžeš nechat vygenerovat.
5. Po dokončení otevři `http://localhost:8090` (z jiných zařízení `http://IP-ADRESA-POČÍTAČE:8090`) a přihlas se.

## Instalace – Linux a Synology přes SSH

```
cd vlacky/instalator
chmod +x instalovat.sh
./instalovat.sh
```

Průvodce udělá totéž co na Windows. Na Synology navrhne složku dat `/volume1/docker/vlacky/data`.
SSH na Synology zapneš v Ovládacím panelu → Terminál a SNMP. Po připojení se může hodit `sudo -i`.

## Instalace – Synology bez příkazové řádky (Container Manager)

1. Zkopíruj celou složku balíčku na NAS, např. do `/volume1/docker/vlacky-app`.
2. Ve složce `instalator` zkopíruj `env.example` na `.env` a uprav v něm `APP_PASSWORD`, `VLACKY_PORT` a `VLACKY_DATA` (např. `/volume1/docker/vlacky/data`).
3. Container Manager → Projekt → Vytvořit → cesta ke složce `instalator` → použít existující `docker-compose.yml` → sestavit a spustit.

## První přihlášení a nastavení

1. Přihlas se úvodním heslem (je v souboru `instalator/.env`, řádek `APP_PASSWORD`).
2. V nastavení aplikace si heslo změň. Od té chvíle se heslo v `.env` ignoruje (a můžeš ho z něj smazat). Zapomenuté heslo: smaž ve složce dat soubor `auth.json` a znovu platí heslo z `.env`.
3. V aplikaci (v nastavení centrály) vyber svou centrálu (Z21, DR5000 a další) a zadej její IP adresu. Aplikace a centrála musí být ve stejné síti. Jestli nejsou, použij volitelný „agent“ (program na počítači v síti centrály; zeptej se, pošlu ho).
4. Začni přidávat dekodéry a lokomotivy. Knihovna šablon CV z projektu JMRI je už v balíčku.
5. Volitelně: AI asistent potřebuje **tvůj vlastní** klíč k API Anthropic. Bez něj aplikace funguje normálně.

## HTTPS, kamera a instalace do telefonu

Přes obyčejné `http://` aplikace funguje, ale prohlížeče tam **nepustí kameru** (čtečka QR, tlačítko Vyfotit) a **nenabídnou instalaci do telefonu jako aplikaci** (PWA). Výjimkou je `localhost`. Pokud to chceš:

- Měj domény a certifikát (např. z Let's Encrypt, nebo ze Synology: Ovládací panel → Zabezpečení → Certifikát) a při instalaci odpověz na HTTPS „a“ a zadej složku se soubory `fullchain.pem` a `privkey.pem`. Na Synology je to `/usr/syno/etc/certificate/_archive/<ID-certifikátu>`.
- Při obnově certifikátu se aplikace sama restartuje.
- Přístup z internetu zvaž jen s HTTPS a dlouhým heslem; aplikace blokuje opakované pokusy o přihlášení, ale nejbezpečnější je zůstat jen v domácí síti (nebo přes VPN).

## Kde jsou moje data a jak je zálohovat

Všechno je ve složce dat (`VLACKY_DATA` v `.env`): databáze `vlacky.db`, `photos/`, `files/`, `backups/` a nastavení (`auth.json`, `central.json`, `ai.json`). Aplikace sama dělá automatické zálohy databáze do `backups/auto` (posledních 14). Úplná záloha = zkopíruj celou složku dat na jiné místo. Export je i v aplikaci (JSON/CSV).

## Aktualizace

Dostaneš novou verzi balíčku: přepiš složku `app`, `Dockerfile` a `requirements.txt` (složku dat ani `instalator/.env` nepřepisuj) a znovu spusť průvodce. Zachová nastavení a jen aplikaci znovu sestaví. Data zůstanou.

## Užitečné příkazy (ve složce `instalator`)

```
docker compose logs -f         # co aplikace dělá
docker compose restart         # restart
docker compose down            # zastavení (data zůstanou)
```

Při HTTPS přidej `-f docker-compose.yml -f docker-compose.https.yml`. Na starších Synology místo `docker compose` piš `docker-compose`.

## Řešení potíží

| Příznak | Co zkusit |
|---|---|
| „Port is already allocated“ | Port je obsazený (na Synology často 8080). Smaž `instalator/.env`, spusť průvodce a zvol jiný, např. 8090. |
| Aplikace se nespustí, v logu „Nastav APP_PASSWORD“ | V `.env` chybí nebo je krátké heslo (min. 8 znaků). |
| V logu „HTTPS je zapnuté, ale certifikát nenalezen“ | Špatná cesta v `VLACKY_CERT_DIR` nebo chybí `fullchain.pem`/`privkey.pem`. |
| Nejde se připojit z tabletu | Zkontroluj firewall a že zařízení je ve stejné síti; použij IP adresu počítače, ne `localhost`. |
| Windows: skript se nespustí | Spusť `instalovat.cmd` (ne `.ps1` dvojklikem). Docker Desktop musí běžet. |

## Licence a původ dat

Knihovna dekodérů vychází z projektu **JMRI** (licence GNU GPL v2). Podrobnosti a podmínky dalšího šíření jsou v `instalator/LICENCE-TRETI-STRANY.txt`. Logo v aplikaci je neutrální nápis; můžeš ho nahradit vlastním souborem `app/static/logo.png`.

# Pro Lukáše – jak připravit a rozdat balíček

Tento soubor se do balíčku pro kamarády nekopíruje.

## Příprava čistého balíčku
V PowerShellu ve složce `instalator`:

    powershell -ExecutionPolicy Bypass -File pripravit-balicek.ps1

Vznikne nová složka `vlacky-pro-kamarady` (vedle `vlacky-src-kompletni`, ne zip) s Dockerfilem, `app/`, `instalator/` a `NAVOD.md`. Skript zkontroluje, že v ní nezůstaly data ani osobní údaje, a při nálezu skončí chybou.

## Co do balíčku NEPATŘÍ (a skript to vynechá)
- data z NAS (`V:\data`: `vlacky.db`, `photos`, `files`, `backups`)
- `auth.json` (hash tvého hesla), `secret.key` (podpis relací), `central.json` (IP centrály), `agent.json`, `ai.json` (klíč k API), `decoder_types.json`
- původní `docker-compose.yml` (tvoje heslo/ID certifikátu DSM), `Dockerfile.bak-*`, všechny `*.bak-*`, stará kopie `src/`
- certifikáty a privátní klíče (`fullchain.pem`, `privkey.pem`), doména a IP z DDNS

Kód aplikace v `app/` osobní údaje neobsahuje (zkontrolováno: žádná doména, IP ani klíč). Osobní logo „Moje-vlacky.cz by Edys“ skript v balíčku nahradí neutrálním nápisem Vláčky (`logo-neutralni.png`) a upraví popisky v `login.html` a `app.js`; tvoje originály zůstanou beze změny.

## Licence
Šíříš `jmri_decoders.db` odvozenou z JMRI (GPL v2): balíček proto obsahuje `LICENCE-TRETI-STRANY.txt` a převodní skript `jmri2vlacky.py` je dobré přibalit (stačí do `instalator/`). Pro rozdávání kamarádům zdarma je to v pořádku; kdyby sis aplikaci chtěl veřejně nabízet nebo prodávat, rozmysli licencování celé aplikace.

## Aktualizace pro kamarády
Pošli novou verzi složky; oni přepíšou `app`, `Dockerfile`, `requirements.txt` a znovu spustí průvodce (data ani `.env` se nemění).

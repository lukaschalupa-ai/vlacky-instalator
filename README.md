# vlacky-instalator

Instalační balíček aplikace **Vláčky** (evidence lokomotiv, dekodérů a příslušenství pro digitální modelovou železnici) pro kamarády: Docker, prázdná databáze, vlastní heslo. Návod česky: [`instalator/NAVOD.md`](instalator/NAVOD.md).

## Co tu je a co ne

Repozitář obsahuje jen **instalační kit**: `docker-compose.yml`, průvodce `instalovat.cmd` / `instalovat.sh`, skript `pripravit-balicek.ps1`, návod a licenční poznámky.

Kód aplikace (`Dockerfile`, `requirements.txt`, složka `app/`) a knihovna dekodérů `app/data/jmri_decoders.db` (odvozená z JMRI, GPL v2) tu **nejsou**. Kit se klade vedle nich:

```
vlacky/
├── Dockerfile
├── requirements.txt
├── .dockerignore
├── app/
└── instalator/      <- obsah tohoto repozitáře
```

Hotový čistý balíček se zdrojovým kódem vyrobí `instalator/pripravit-balicek.ps1` ze zdrojové složky `vlacky-src-kompletni` (viz `instalator/PRO-LUKASE.md`).

## Rychlý start

Windows: `instalator\instalovat.cmd`. Linux / Synology: `./instalator/instalovat.sh`. Podrobnosti v návodu.

## Licence

Viz `LICENSE` (GPL v3) a `instalator/LICENCE-TRETI-STRANY.txt` (JMRI, jsQR a další).

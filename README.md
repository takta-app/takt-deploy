# Takt – kom igång som testare

Den här guiden tar dig från tom dator till en fungerande Takt-installation med din första organisation och ditt första team. Installationen är Docker Compose. Med internet hämtas images från [Docker Hub](https://hub.docker.com/r/mrweiland/takt). Utan internet (`airgapped`) laddar du ner zip och images på en dator med nät, flyttar dem och kör `docker load`.

Frågor eller fel: skriv till den som bjöd in dig. Bifoga gärna utskriften från `docker compose --env-file .env logs app --tail 100` (kör i mappen `takt-deploy`).

## 1. Krav

| | Minimum | Kommentar |
|---|---|---|
| Docker | Docker Desktop 4.30+ (Mac/Windows) eller Docker Engine 27+ (Linux) med **Compose v2** | Kontrollera med `docker compose version` – ska visa `v2.x` eller nyare. Gamla `docker-compose` (bindestreck) fungerar inte. |
| Arkitektur | `amd64` eller `arm64` | Apple Silicon fungerar. |
| Minne till Docker | 4 GB | Postgres + S3 + app. På Mac/Windows: Docker Desktop → Settings → Resources. |
| Disk | ~3 GB fritt | Images plus data. |
| Portar | `3005`, `23647` och `5435` lediga | App, fillagringens adminsida och databas. Byts i `.env` (`TAKT_PORT` **och** `AUTH_URL` måste ändras ihop). |
| Nät | online eller airgapped | Online: Hub vid start. Airgapped: `docker save` på en dator med nät, `docker load` här, sedan `docker compose --env-file .env up -d --pull never`. |

Kontroll:

```bash
docker --version
docker compose version
```

Om kommandona misslyckas är Docker inte igång. Starta Docker Desktop och försök igen. Online kan du även köra `docker run --rm hello-world` som extra kontroll.

## 2. Hämta installationsmappen

Du får en zip, `takt-deploy.zip`, från den som bjöd in dig. Den innehåller bara Compose-filer och skript – ingen källkod. Packa upp den och gå in i mappen:

```bash
unzip takt-deploy.zip
cd takt-deploy
ls
# .env  .env.example  README.md  backup-loop.sh  pg-migrate-data-dir.sh  cli/  compose.yaml  down.sh
```

`.env` är dold i Finder/Utforskaren; `ls -a` i terminalen visar den.

Mappen `cli/` innehåller Takt-kommandot för terminalen och MCP (frivilligt, se avsnitt 8).

Vilken version av appen som ska köras står i `.env` (`TAKT_VERSION`). Ändra inte den om du inte blivit ombedd. Samma tagg används när du sparar images för airgap.

## 3. Fyll i `.env`

Zippen innehåller en färdig `.env` med alla rader på plats. Öppna den i en editor **innan** du startar första gången. Det du ska fylla i står överst under rubriken `FYLL I`, med exempel på hur raderna ska se ut:

```env
AUTH_SECRET=          # openssl rand -base64 32
AI_ENABLED=1
AI_GATEWAY_API_KEY=vck_a1B2c3D4e5F6g7H8i9J0kLmNoPqRsTuVwXyZ
```

Sammanfattning av vad som får ändras:

| Rad | Värde | Varför |
|---|---|---|
| `AUTH_SECRET=` | utskrift från `openssl rand -base64 32` | Krävs. Unik per installation. Byt den aldrig efteråt. |
| `AI_ENABLED=1` | `1` | Slår på AI-assistenten på instansen. Utan den är AI dold i hela appen, även om du slår på den i organisationens inställningar. |
| `AI_GATEWAY_API_KEY=` | nyckeln du fått av den som bjöd in dig | Krävs tillsammans med `AI_ENABLED`. Dela den inte vidare. |
| `TAKT_PORT` och `AUTH_URL` | t.ex. `3006` och `http://localhost:3006` | Bara om 3005 är upptagen. Båda måste peka på samma port, annars fungerar inte inloggningen. |
| `POSTGRES_PORT`, `S3_CONSOLE_PORT` + `S3_CONSOLE_URL` | t.ex. `5436`, `23648` + `http://localhost:23648` | Bara om 5435 eller 23647 är upptagen. |

Övriga rader kan stå kvar som de är. `.env.example` är en orörd kopia att jämföra med. `AUTH_SECRET` måste vara ifylld innan Compose startar.

Vill du köra utan AI, lämna `AI_ENABLED` och `AI_GATEWAY_API_KEY` tomma. Allt utom assistenten fungerar ändå.

Ändrar du `.env` senare: `docker compose --env-file .env up -d` så startas appen om med de nya värdena.

## 4. Starta

Två vägar, samma stack. Versionen i `.env` (`TAKT_VERSION`) är Hub-taggen **utan** `v`. Images:

- `mrweiland/takt:<TAKT_VERSION>`
- `postgres:19beta3-alpine`
- `chrislusf/seaweedfs:4.46`

### Online

```bash
docker compose --env-file .env up -d
```

Compose hämtar images från Docker Hub (första gången), startar stacken och kör migreringar. Första nedladdningen tar någon minut. `AUTH_SECRET` måste vara ifylld.

### Airgapped

På en dator **med** internet (samma `TAKT_VERSION` som i zippens `.env`):

```bash
docker pull mrweiland/takt:<version>
docker pull postgres:19beta3-alpine
docker pull chrislusf/seaweedfs:4.46
docker save mrweiland/takt:<version> postgres:19beta3-alpine chrislusf/seaweedfs:4.46 \
  | gzip > takt-images.tar.gz
```

Flytta zippen och `takt-images.tar.gz` till den luftgapade maskinen. Där:

```bash
gunzip -c takt-images.tar.gz | docker load
unzip takt-deploy.zip
cd takt-deploy
docker compose --env-file .env up -d --pull never
```

`--pull never` pratar inte med Hub. CLI i zippen installeras lokalt med `./cli/install.sh` (ingen GitHub-nedladdning).

Klart när alla fyra rader visar `healthy` eller `Up`:

```text
takt-install-app-1        Up (healthy)   0.0.0.0:3005->3005/tcp
takt-install-backup-1     Up
takt-install-postgres-1   Up (healthy)
takt-install-s3-1         Up (healthy)
```

Öppna sedan [http://localhost:3005/register](http://localhost:3005/register).

`docker compose --env-file .env up -d` kan köras igen: online hämtar den imagen för din `TAKT_VERSION` om den saknas lokalt och startar om. Airgapped: `--pull never` efter ny `docker load`. Databasen ligger kvar i en Docker-volym mellan omstarter.

## 5. Skapa konto

På `/register`:

| Fält | Krav |
|---|---|
| Namn | 1–80 tecken |
| E-post | giltig adress; används som inloggning |
| Lösenord | minst 8 tecken |

Klicka **Skapa konto**. Du loggas in direkt och hamnar i onboarding-guiden. Första kontot blir administratör för organisationen du skapar i nästa steg.

Gränssnittet är på svenska som standard. Vill du ha engelska: lägg `/en` först i adressen, t.ex. `http://localhost:3005/en/register`.

## 6. Guiden: organisation och första team

Guiden på `/app/new` har fyra steg. Inget sparas förrän du klickar **Skapa arbetsyta** i sista steget, så du kan gå fram och tillbaka.

### Steg 1 – Organisation

| Fält | Beskrivning |
|---|---|
| **Organisationens namn** | Fritt, t.ex. `Northbricks AB`. |
| **Adress** | Kort identifierare som blir en del av URL:en: `localhost:3005/app/<adress>`. Fylls i automatiskt från namnet. Bara små bokstäver, siffror och bindestreck, 2–40 tecken. |
| **Ditt namn** | Förifyllt från registreringen. |
| **AI-assistent** | På som standard. Har ingen effekt förrän en operatör satt `AI_ENABLED=true` och en nyckel i `.env`; utan det är AI-funktioner dolda och allt annat fungerar. |

### Steg 2 – Inloggning

Visar bara hur användare loggar in i den här installationen (e-post och lösenord). Inget att välja. **Fortsätt**.

### Steg 3 – Första teamet

| Fält | Beskrivning |
|---|---|
| **Teamets namn** | T.ex. `Plattform`. Blir `localhost:3005/app/<adress>/teams/plattform`. |
| **Bjud in personer** | Valfritt. E-postadresser, max 50. De som registrerar sig med en av adresserna blir automatiskt **Medlem** i organisationen och teamet. Inget mejl skickas – du måste själv ge dem länken till `/register`. |

### Steg 4 – Granska och slutför

Läs igenom och klicka **Skapa arbetsyta →**. Du landar på teamets tavla:

```text
http://localhost:3005/app/<adress>/teams/<team>
```

## 7. Första stegen i appen

### Skapa ett arbetsobjekt

På teamets tavla eller backlogg: knappen **Nytt** → välj typ (epic, feature, story, task, bug, krav) → fyll i **Titel** (enda obligatoriska fältet) → spara. Objektet dyker upp i första kolumnen.

Vyer per team i vänstermenyn:

| Vy | URL |
|---|---|
| Tavla (Kanban) | `/app/<adress>/teams/<team>` |
| Backlogg | `/app/<adress>/teams/<team>/backlog` |
| Sprint | `/app/<adress>/teams/<team>/sprint` |

### Fler team

**Teams** i menyn → **Nytt team** (`/app/<adress>/teams/new`). Bara namn krävs. Du hamnar på teamets inställningar efteråt.

### Bjuda in fler personer och sätta roller

Organisationsmenyn → **Inställningar** → fliken **Medlemmar** (`/app/<adress>/settings?tab=members`) → **Bjud in personer**:

| Roll | Kan |
|---|---|
| **Organisationsadmin** | allt, inklusive inställningar, medlemmar, säkerhetskopior |
| **Medlem** | skapa och redigera arbete i sina team |
| **Läsare** | bara läsa |

Välj gärna team samtidigt. Rollen aktiveras när personen loggar in med samma e-postadress. Takt skickar inga mejl – ge personen länken till `/register`.

### Bilder och filer

Klistra in eller dra en bild i en beskrivning eller kommentar. Filerna lagras i S3-containern och visas bara för den som får se arbetsobjektet.

### Säkerhetskopior

Organisationsmenyn → **Säkerhetskopior** (`/app/<adress>/backup`). Compose tar en dump var 30:e minut (48 senaste sparas). Återställning ersätter **hela installationen**, alla organisationer – använd med eftertanke i test.

## 8. CLI och MCP (frivilligt)

`takt` är ett terminalkommando som pratar med din Takt-installation via API:et. Det ger dels en interaktiv arbetssession i terminalen, dels en **MCP-server** så att Cursor, Claude Desktop eller andra MCP-klienter kan läsa och skapa arbetsobjekt, mål och idéer i Takt.

Kräver macOS eller Linux (`amd64`/`arm64`). Windows stöds inte i den här versionen; kör via WSL om du vill prova.

### Installera

Från mappen `takt-deploy`:

```bash
./cli/install.sh
```

Skriptet installerar binären som ligger i zippen (`takt-<os>-<arch>`), kontrollerar SHA256-summan och lägger den som `~/.local/bin/takt`. Det fungerar airgapped — ingen nedladdning från GitHub. Om terminalen inte hittar `takt` efteråt, lägg till sökvägen:

```bash
export PATH="$HOME/.local/bin:$PATH"     # lägg gärna i ~/.zshrc eller ~/.bashrc
takt --version
```

### Logga in

```bash
takt login --url http://localhost:3005
```

Du får frågor om e-post och lösenord (samma som i webben). Har du flera organisationer: lägg till `--org <adress>`, där adressen är samma som i URL:en `/app/<adress>/`. Token sparas lokalt i din användarprofil; kör `takt logout` för att ta bort den.

Prova sedan:

```bash
takt              # interaktiv session: fråga om ditt arbete, skapa objekt
takt org list     # dina organisationer
takt --help       # alla kommandon
```

### MCP i Cursor

Skapa eller redigera `.cursor/mcp.json` i ditt projekt (eller den globala `~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "takt": {
      "command": "takt",
      "args": ["mcp"]
    }
  }
}
```

Starta om Cursor. Verktygen heter t.ex. `search_workitems`, `create_workitem`, `list_goals`, `get_my_work`. Ingen token ska stå i filen – den kommer från `takt login`.

### MCP i Claude Desktop

Samma block i `claude_desktop_config.json` (macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`).

### Felsökning

| Symptom | Åtgärd |
|---|---|
| `command not found: takt` | `~/.local/bin` saknas i `PATH`, se ovan. |
| `takt login` svarar "connection refused" | Takt kör inte, eller fel port. Kontrollera `docker compose --env-file .env ps` och `TAKT_PORT`. |
| MCP-klienten visar inga Takt-verktyg | Kör `takt login` i en terminal först och starta om klienten. MCP-processen loggar aldrig in själv. |
| Token har gått ut | `takt login` igen, starta om MCP-klienten. |
| `checksum mismatch` vid install | Zippen är skadad; hämta den igen. |

## 9. Vardagskommandon

Kör dessa från mappen `takt-deploy`:

```bash
docker compose --env-file .env up -d                   # online: starta (pull om imagen saknas)
docker compose --env-file .env up -d --pull never      # airgapped: lokala images
docker compose --env-file .env down                    # stoppa Takt, behåll data
docker compose --env-file .env ps                      # status
docker compose --env-file .env logs -f app             # appens logg
```

Ny version **online:** ny zip, packa upp i samma mapp (behåll `.env`), sätt `TAKT_VERSION` **utan** `v`, `docker compose --env-file .env up -d`.

Ny version **airgapped:** på en dator med nät: ny zip + ny `takt-images.tar.gz`. Flytta, `docker load`, packa upp zippen i samma mapp (behåll `.env`), `docker compose --env-file .env up -d --pull never`.

Börja om från noll (raderar **alla** testdata i den här installationen, du får bekräfta):

```bash
./down.sh --purge
docker compose --env-file .env up -d            # airgapped: lägg till --pull never
```

## 10. Vanliga problem

| Symptom | Åtgärd |
|---|---|
| `manifest for mrweiland/takt:<version> not found` | Versionen i `.env` (`TAKT_VERSION`) finns inte på Docker Hub. Använd **utan** `v` (`0.2.0`, inte `v0.2.0`). Airgapped: image måste finnas lokalt efter `docker load`. |
| `AUTH_SECRET is required` | `AUTH_SECRET` i `.env` är tom. Fyll i med `openssl rand -base64 32`. |
| `pull access denied` / `unauthorized` / Hub unreachable | Airgapped: `docker load` först, sedan `docker compose --env-file .env up -d --pull never`. Online: Hub kräver ingen inloggning; `docker logout` och prova igen; kontrollera proxy/brandvägg. |
| Sidan laddar men inloggningen loopar / "Untrusted host" | `AUTH_URL` i `.env` matchar inte adressen i webbläsaren (port eller host). Rätta och kör `docker compose --env-file .env up -d` igen. |
| `port is already allocated` på 3005 | Byt `TAKT_PORT` **och** `AUTH_URL`, se avsnitt 3. |
| `port is already allocated` på 23646 / 5433 | En äldre `.env` pekar på 23646/5433. Sätt `S3_CONSOLE_PORT`/`S3_CONSOLE_URL` respektive `POSTGRES_PORT` till 23647 / 5435. |
| AI syns inte trots att den är på i organisationens inställningar | `AI_ENABLED=1` och `AI_GATEWAY_API_KEY` saknas i `.env`, se avsnitt 3. Kör `docker compose --env-file .env up -d` efter ändringen. |
| Appen står i `health: starting` länge | Normalt upp till en minut första gången (migreringar). Kolla `logs app` om det tar längre. |
| Postgres startar inte efter versionsbyte | Volymen är från en äldre Postgres-version. Ta en dump först, sedan `docker compose --env-file .env down -v` och starta igen. Hör av dig om du vill behålla data. |
| Vill ha engelska | `/en` före sökvägen, t.ex. `/en/app`. |

## 11. Vad som körs

| Container | Image | Roll |
|---|---|---|
| `takt-install-app-1` | `mrweiland/takt:<TAKT_VERSION>` | Appen, port `TAKT_PORT` |
| `takt-install-postgres-1` | `postgres:19beta3-alpine` | Databas, port `POSTGRES_PORT` (5435) på din dator |
| `takt-install-s3-1` | `chrislusf/seaweedfs:4.46` | Fillagring (bilder, bilagor); adminsida på `S3_CONSOLE_PORT` (23647) |
| `takt-install-backup-1` | `postgres:19beta3-alpine` | Dump var 30:e minut till volymen `takt-install-backups` |

Portar på din dator: `TAKT_PORT` (3005), `POSTGRES_PORT` (5435) och `S3_CONSOLE_PORT` (23647). Själva S3-API:et är bara nåbart inifrån Docker. All data ligger i Docker-volymer (`takt-install-*`) och försvinner bara vid `./down.sh --purge` eller `down -v`.

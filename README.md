# Takt – kom igång som testare

Den här guiden tar dig från tom dator till en fungerande Takt-installation med din första organisation och ditt första team. Du behöver inte kunna Next.js eller Postgres, och du bygger ingenting själv: appen hämtas som en färdig image från [Docker Hub](https://hub.docker.com/r/mrweiland/takt) och allt körs i Docker.

Frågor eller fel: skriv till den som bjöd in dig. Bifoga gärna utskriften från `docker compose --env-file .env logs app --tail 100` (kör i mappen `takt-deploy`).

## 1. Krav

| | Minimum | Kommentar |
|---|---|---|
| Docker | Docker Desktop 4.30+ (Mac/Windows) eller Docker Engine 27+ (Linux) med **Compose v2** | Kontrollera med `docker compose version` – ska visa `v2.x` eller nyare. Gamla `docker-compose` (bindestreck) fungerar inte. |
| Arkitektur | `amd64` eller `arm64` | Apple Silicon fungerar. |
| Minne till Docker | 4 GB | Postgres + S3 + app. På Mac/Windows: Docker Desktop → Settings → Resources. |
| Disk | ~3 GB fritt | Images plus data. |
| Portar | `3001` ledig | Byts i `.env` (`TAKT_PORT` **och** `AUTH_URL` måste ändras ihop). |
| Internet | vid start | För att hämta images från Docker Hub. Därefter körs allt lokalt. |
| Git, Node | **Behövs inte** | Ingen källkod och inget bygge på din dator. |

Kontroll:

```bash
docker --version
docker compose version
docker run --rm hello-world
```

Om `hello-world` inte kör är Docker inte igång. Starta Docker Desktop och försök igen.

## 2. Hämta installationsmappen

Du får en zip, `takt-deploy.zip`, från den som bjöd in dig. Den innehåller bara Compose-filer och skript – ingen källkod. Packa upp den och gå in i mappen:

```bash
unzip takt-deploy.zip
cd takt-deploy
ls
# .env  .env.example  README.md  backup-loop.sh  pg-migrate-data-dir.sh  cli/  compose.yaml  down.sh  up.sh
```

`.env` är dold i Finder/Utforskaren; `ls -a` i terminalen visar den.

Mappen `cli/` innehåller Takt-kommandot för terminalen och MCP (frivilligt, se avsnitt 8).

Vilken version av appen som hämtas står i `.env` (`TAKT_VERSION`). Ändra inte den om du inte blivit ombedd.

## 3. Fyll i `.env`

Zippen innehåller en färdig `.env` med alla rader på plats. Öppna den i en editor **innan** du startar första gången. Det du ska fylla i står överst under rubriken `FYLL I`, med exempel på hur raderna ska se ut:

```env
AI_ENABLED=1
AI_GATEWAY_API_KEY=vck_a1B2c3D4e5F6g7H8i9J0kLmNoPqRsTuVwXyZ
```

Sammanfattning av vad som får ändras:

| Rad | Värde | Varför |
|---|---|---|
| `AI_ENABLED=1` | `1` | Slår på AI-assistenten på instansen. Utan den är AI dold i hela appen, även om du slår på den i organisationens inställningar. |
| `AI_GATEWAY_API_KEY=` | nyckeln du fått av den som bjöd in dig | Krävs tillsammans med `AI_ENABLED`. Dela den inte vidare. |
| `TAKT_PORT` och `AUTH_URL` | t.ex. `3002` och `http://localhost:3002` | Bara om 3001 är upptagen. Båda måste peka på samma port, annars fungerar inte inloggningen. |

Övriga rader kan stå kvar som de är. `AUTH_SECRET` är tom med flit; `./up.sh` fyller i en slumpad vid första start. `.env.example` är bara en orörd kopia att jämföra med.

Vill du köra utan AI, lämna `AI_ENABLED` och `AI_GATEWAY_API_KEY` tomma. Allt utom assistenten fungerar ändå.

Ändrar du `.env` senare: kör `./up.sh` igen så startas appen om med de nya värdena.

## 4. Starta

```bash
./up.sh
```

Skriptet:

1. fyller i `AUTH_SECRET` i `.env` om den är tom,
2. hämtar app-imagen `mrweiland/takt` samt Postgres 19 och S3 (SeaweedFS) från Docker Hub,
3. startar allt och visar `docker compose ps`.

Första gången tar nedladdningen någon minut beroende på uppkoppling.

Klart när alla fyra rader visar `healthy` eller `Up`:

```text
takt-install-app-1        Up (healthy)   0.0.0.0:3001->3001/tcp
takt-install-backup-1     Up
takt-install-postgres-1   Up (healthy)
takt-install-s3-1         Up (healthy)
```

Öppna sedan [http://localhost:3001/register](http://localhost:3001/register).

`./up.sh` kan köras igen när som helst; det hämtar senaste imagen för din `TAKT_VERSION` och startar om. Databasen ligger kvar i en Docker-volym mellan omstarter.

## 5. Skapa konto

På `/register`:

| Fält | Krav |
|---|---|
| Namn | 1–80 tecken |
| E-post | giltig adress; används som inloggning |
| Lösenord | minst 8 tecken |

Klicka **Skapa konto**. Du loggas in direkt och hamnar i onboarding-guiden. Första kontot blir administratör för organisationen du skapar i nästa steg.

Gränssnittet är på svenska som standard. Vill du ha engelska: lägg `/en` först i adressen, t.ex. `http://localhost:3001/en/register`.

## 6. Guiden: organisation och första team

Guiden på `/app/new` har fyra steg. Inget sparas förrän du klickar **Skapa arbetsyta** i sista steget, så du kan gå fram och tillbaka.

### Steg 1 – Organisation

| Fält | Beskrivning |
|---|---|
| **Organisationens namn** | Fritt, t.ex. `Northbricks AB`. |
| **Adress** | Kort identifierare som blir en del av URL:en: `localhost:3001/app/<adress>`. Fylls i automatiskt från namnet. Bara små bokstäver, siffror och bindestreck, 2–40 tecken. |
| **Ditt namn** | Förifyllt från registreringen. |
| **AI-assistent** | På som standard. Har ingen effekt förrän en operatör satt `AI_ENABLED=true` och en nyckel i `.env`; utan det är AI-funktioner dolda och allt annat fungerar. |

### Steg 2 – Inloggning

Visar bara hur användare loggar in i den här installationen (e-post och lösenord). Inget att välja. **Fortsätt**.

### Steg 3 – Första teamet

| Fält | Beskrivning |
|---|---|
| **Teamets namn** | T.ex. `Plattform`. Blir `localhost:3001/app/<adress>/teams/plattform`. |
| **Bjud in personer** | Valfritt. E-postadresser, max 50. De som registrerar sig med en av adresserna blir automatiskt **Medlem** i organisationen och teamet. Inget mejl skickas – du måste själv ge dem länken till `/register`. |

### Steg 4 – Granska och slutför

Läs igenom och klicka **Skapa arbetsyta →**. Du landar på teamets tavla:

```text
http://localhost:3001/app/<adress>/teams/<team>
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

Skriptet väljer rätt binär för din dator, kontrollerar SHA256-summan och lägger den som `~/.local/bin/takt`. Om terminalen inte hittar `takt` efteråt, lägg till sökvägen:

```bash
export PATH="$HOME/.local/bin:$PATH"     # lägg gärna i ~/.zshrc eller ~/.bashrc
takt --version
```

### Logga in

```bash
takt login --url http://localhost:3001
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
./setup.sh start                                       # starta, eller hämta ny image och starta om
./setup.sh stop                                        # stoppa Takt, behåll data
./setup.sh upgrade                                     # senaste GitHub Release + behåll .env
docker compose --env-file .env ps                     # status
docker compose --env-file .env logs -f app            # appens logg
```

Ny version: `./setup.sh upgrade` (rekommenderas). Manuellt: sätt `TAKT_VERSION` i `.env` **utan** `v` (Hub-tagg `0.2.0`, GitHub-release `v0.2.0`) och kör `./up.sh`. Databasen migreras vid start. `git pull` uppdaterar inte en befintlig `.env`.

Börja om från noll (raderar **alla** testdata i den här installationen, du får bekräfta):

```bash
./down.sh --purge
./up.sh
```

## 10. Vanliga problem

| Symptom | Åtgärd |
|---|---|
| `manifest for mrweiland/takt:<version> not found` | Versionen i `.env` (`TAKT_VERSION`) finns inte på Docker Hub. Använd **utan** `v` (`0.2.0`, inte `v0.2.0`). |
| `pull access denied` / `unauthorized` | Docker Hub-nedladdning kräver ingen inloggning. Kör `docker logout` och prova igen; kontrollera proxy/brandvägg. |
| Sidan laddar men inloggningen loopar / "Untrusted host" | `AUTH_URL` i `.env` matchar inte adressen i webbläsaren (port eller host). Rätta och kör `./up.sh` igen. |
| `port is already allocated` på 3001 | Byt `TAKT_PORT` **och** `AUTH_URL`, se avsnitt 3. |
| AI syns inte trots att den är på i organisationens inställningar | `AI_ENABLED=1` och `AI_GATEWAY_API_KEY` saknas i `.env`, se avsnitt 3. Kör `./up.sh` efter ändringen. |
| Appen står i `health: starting` länge | Normalt upp till en minut första gången (migreringar). Kolla `logs app` om det tar längre. |
| Postgres startar inte efter versionsbyte | Volymen är från en äldre Postgres-version. Ta en dump först, sedan `down -v` och `./up.sh`. Hör av dig om du vill behålla data. |
| Vill ha engelska | `/en` före sökvägen, t.ex. `/en/app`. |

## 11. Vad som körs

| Container | Image | Roll |
|---|---|---|
| `takt-install-app-1` | `mrweiland/takt:<TAKT_VERSION>` | Appen, port `TAKT_PORT` |
| `takt-install-postgres-1` | `postgres:19beta3-alpine` | Databas, bara nåbar inifrån Docker |
| `takt-install-s3-1` | `chrislusf/seaweedfs` | Fillagring (bilder, bilagor) |
| `takt-install-backup-1` | `postgres:19beta3-alpine` | Dump var 30:e minut till volymen `takt-install-backups` |

Inga portar utom `TAKT_PORT` exponeras på din dator. All data ligger i Docker-volymer (`takt-install-*`) och försvinner bara vid `down -v`.

# CBO Winter Operations v2 — Independent Monitoring & Disaster Recovery

21 oktober 2026. Utvecklingsförslag, ingen produktionsaktivering. Fortsättning på v1.
Verifierad main: `4a96b7a5c70002f4dd1e99a7c369c3d8556e6d38`. V1:s manuella produktionsprov
`39573956551` är tidigare verifierat; första verkliga schedule väntas 22 oktober.
V1-dokumentet är leveranshistorik, inte aktuell installationsstatus. V2 är inte mergad.

## A. Oberoende frånvarolarm

Rekommendation: Healthchecks.io Hobbyist, officiellt $0/månad, 20 kontroller och 100
loggposter per kontroll. Ingen betald plan, SMS eller telefon behövs. E-postintegration
konfigureras per projekt och måste vara ON för kontrollen; verklig leverans/mottagning
är ännu inte provad. En extern kontroll fortsätter bevaka frånvaron även när GitHub
slutar köra, utan ChatGPT. Ingen kostnadsfri tjänst ger obegränsad driftgaranti.

Konfiguration efter separat godkännande:

1. Ägaren skapar/väljer ett konto på Free/Hobbyist, utan betald uppgradering. Bekräfta
   e-post, välj ansvarig mottagare och ställ in stark kontosäkerhet. Dela inte loginlänkar.
2. Skapa `CBO daily verified health`, Simple, period 24 timmar, grace 24 timmar.
   Det innebär larm cirka 48 timmar efter senaste accepterade PASS, inte omedelbart
   vid första missade körning. GitHub ger tidigare röd status vid upptäckt driftfel.
   24 h grace tolererar fördröjning/ett missat dygn men fördröjer upptäckt; efter verklig
   observation kan ägaren besluta om kortare grace, exempelvis 6 h. Inget schema ändras här.
3. Använd UUID-baserad `https://hc-ping.com/<uuid>`, tillåt endast POST, ingen
   auto-provisionering, body-filter eller start-ping. Aktivera e-post för kontrollen.
4. Efter godkänd merge: GitHub repo Settings → Secrets and variables → Actions →
   Secrets: `CBO_HEALTHCHECKS_PING_URL`. Lägg inte URL i issue, PR, chatt eller logg.
   Variables: `CBO_HEALTHCHECKS_ENABLED=true`. Dessa skapas INTE i detta uppdrag.
5. Nästa verkliga lyckade schedule ger första heartbeat. Kontrollera acceptans i
   Healthchecks-historiken och dokumentera UTC/run-ID utan ping-URL. Ett manuellt
   GitHub-prov skickar avsiktligt INTE heartbeat: manuella prov får inte dölja dött schema.

Integrationen är avstängd när opt-in-variabeln inte är exakt `true` och redovisar då
`NOT_ENABLED`, inte ett verifierat frånvaroskydd. Vid aktiverad integration ger saknad
eller felaktig secret FAIL. Bara den skyddade main-jobben vid `schedule`, efter
framgångsrik health-step, har tillgång till ping-secret. PR-QA har inga produktionssecrets.
Skriptet kräver dessutom READ_ONLY_LIVE/PASS, rätt två kontroller med HTTP 200 och färsk UTC
(max fem minuter). FAIL, gammal rapport, simulering eller manuell körning ger ingen signal.

Endast tom POST skickas. Exakt HTTPS-värd och UUID-format krävs; användarinformation,
port, query, fragment, extra sökväg, whitespace och redirects avvisas. Högst tre försök,
15 sekunder per försök inklusive svarsläsning, max 32 bytes. Endast exakt HTTP 200 +
`OK` räknas som acceptans: API:t kan ge 200 även för okänd kontroll eller rate limit.
Fast felkod loggas, aldrig URL, nycklar, body eller exceptionstext. Ett heartbeatfel
ger rött jobb men ändrar inte de redan redovisade frontend-/databasresultaten.

Ping-URL är en bearer-hemlighet: den som får den kan förfalska hälsa. Vid läcka skapa
ersättningskontroll och ersätt secret efter godkännande; den gamla UUID:n kan inte
roteras på plats. Publicera inte kontrollens privata länkar eller webbläsarförhandsvisningar.
Leverantören ser nödvändigtvis anrops-IP och tidpunkt, men inga CBO-data skickas.
Högst fem pingar/minut anges av leverantören; denna design gör normalt ett per dygn.
100 loggposter motsvarar ungefär 100 dygn, kortare vid retries/extra signaler.

Viktig separat livscykel: Healthchecks varnar efter över ett år utan kontoinloggning
och kan radera kontot 30 dagar senare; pingar förhindrar inte detta. Ägaren ska logga
in och kontrollera mottagare minst halvårsvis och bevaka kontots varningsmejl.
Det är ingen daglig användaraktivitet, men lösningen är inte evig utan förvaltning.
GitHubs 60-dagarsrisk och möjlig fördröjd/tappad schedule kvarstår; ingen tom commit införs.
`ops/winter-watchdog.mjs` bevaras som kompletterande fristående diagnos, inte som timer
inne i samma workflow. V1 garanterar fortfarande inte skydd mot Supabase-pausning.

### Verkligt aviseringstest — kräver separat godkännande

Skapa en separat tydligt märkt QA-kontroll i samma Free-konto, period 1 minut + grace
1 minut och samma bekräftade mottagare. Skicka ett enda tomt ping från betrodd klient,
stoppa sedan QA-pingarna. Inaktivera INTE CBO:s workflow och ändra inte CBO-kontrollens
tider. Dokumentera fyra separata bevis: senaste ping UTC, leverantörens DOWN-händelse,
leveranslogg för skickat mejl, ägarens uttryckliga mottagningsbekräftelse med UTC.
Prova återhämtning med nytt QA-ping och ta bort QA-kontrollen när beviset är sparat
privat. Kontrollera dessutom CBO:s första riktiga accepterade schedule-ping.
En mock-server/tidsberäkning i CI bevisar inte Healthchecks faktiska larm eller e-post.
Ingen sådan extern kontroll, signal eller avisering har skapats under utvecklingen.

## B. Produktionens backupinventering

Read-only metadata 21 oktober: Supabase ACTIVE_HEALTHY, PostgreSQL 17.6.1.166,
18 public-tabeller med RLS, 33 public-funktioner, 27 public/Storage-policyer och inga
icke-interna public-triggers. Sju privata Storage-objekt. 2026 AVSLUTAD, 2027 PÅGÅENDE.
Installerade extensions: pg_stat_statements, pgcrypto, plpgsql, supabase_vault, uuid-ossp.
Inga Auth-rader, medlemscredentials, meddelanden, privata bilder eller secrets exporterades.

Enda identifierade privata backupen är `CBO_PRODUCTION_PREINSTALL_2026-10-19.json`,
19 oktober 11:42 UTC, 485 913 bytes, SHA-256
`5a49f716f1d502462a74b73dcb8272893199383ca3cf1999b1c0fccb6cff4086`.
Sökningen identifierade ingen senare CBO-backup. Det bevisar inte att ägaren saknar
andra kopior utanför åtkomlig lagring. Ingen verifierad plattformsbackup har inventerats.

| Komponent | Faktisk produktionsbackup / klassificering | Återställningslucka |
| --- | --- | --- |
| Tävlingskopia före installation | Säkerhetskopierad och delåterställningstestad: 16 säsonger, 222 omgångar, 1 525 resultat med relationer i tidigare PGlite-test | Inte dagens databas och inte full tjänsteåterställning |
| Aktuell 2027 och fryst 2026-snapshot/champion | Saknas i identifierad backup | Ny konsistent export behövs; officiella championfält och snapshot ska hashas och jämföras |
| Fullt PostgreSQL-schema, typer, grants, RLS, RPC, triggers, index | Delvis säkerhetskopierat men inte fullständigt återställningstestat | JSON har bara utvalda definitioner/metadata; repo-SQL ersätter inte verklig katalog |
| Players och season_players | Säker spelarprojektion/relationsdel delåterställningstestad | Fulla aktuella medlemsrader saknas |
| player_credentials, Golf-ID, kodhashar och Auth-kopplingar | Saknas i backup | Känslig export kräver godkännande; behandlas som credentials |
| Auth users/identities/övriga Auth-tabeller | Saknas i backup | Separat kompatibel Auth-export och återläsning; lösenordshashar är känsliga |
| Klubbhusets meddelanden/reactions, Kansliet, aktivitet | Saknas i backup | Samtliga public-tabeller ska omfattas, inte bara tävlingstabeller |
| Privata bucketinställningar, Storage-policyer och bildreferenser | Saknas som komplett återställningsbar uppsättning | Explicit metadatainventering och anpassade managed-schema-policyer behövs |
| Sju privata bildbinärer | Saknas i backup | Separat paginerad och checksummeverifierad Storage-export behövs |
| On Tour och övriga reaktioner | Saknas i identifierad backup | Ska ingå oförändrat i full export; ingen On Tour-logik ändras här |
| Pushprenumerationer | Saknas i backup | Känsliga endpoints/nycklar; same-origin/VAPID måste återställas eller prenumerationer förnyas |
| Edge Function-källkod och versionskonfiguration | Bara `member-cbo-code` hittades som källfil i repo; inte komplett backup/test | Sju driftsatta funktioner inventerade nedan; källkod/dependencies/JWT-flaggor måste säkras separat |
| OpenAI/VAPID, Auth-provider-/SMTP-secrets, signing-/Vault-nycklar | Kräver separat säker återställningsprocedur | Värden har inte lästs eller verifierats; lösenordsvalv/återutfärdande och ägare måste beslutas |
| GitHub Pages, PWA, appens versionshistorik | Finns i GitHub och lokal clone, men full oberoende DR ej testad | Privat mirror/bundle samt Pages/repo-inställningar och återpubliceringstest behövs; GitHub är inte två offsite-kopior |

Driftsatta Edge Functions (endast metadata, inga värden): parse-gamebook v7,
send-cbo-push v4, admin-cbo-cod v2, admin-cbo-code v1, swift-task v1,
parse-gamebook-tour v3, member-cbo-code v1. `admin-cbo-cod` har verify_jwt=false,
övriga true. Detta dokumenterar faktisk baseline, ändrar eller säkerhetscertifierar
inte befintliga funktioner. Funktioner med liknande namn får inte tappas i backupen.

### Komplett backupdesign — inte installerad

Rekommenderad körplats är ägarens betrodda dator/NAS med lokal scheduler, krypterad
disk och separat privat lagring. Varken publika GitHub-runners, offentliga artefakter,
ChatGPT eller repositoryt ska transportera produktionsbackupen. Inga nya tjänster
behövs OM dator och två tillräckliga privata lagringsplatser redan finns; de är ännu
inte bekräftade. Utan sådan befintlig lagring går $0 och två privata kopior inte att lova.
Free-planens lagring/egress måste räcka; avbryt vid quota, uppgradera inte automatiskt.

1. Ägaren godkänner exakt exportomfattning, betrodd dator, DB-läsbehörighet och
   Storage-läsbehörighet. Ingen ny hemlighet eller produktionsåtkomst skapas här.
   Databasanslutning via befintlig TLS-verifierad direktanslutning eller session-pooler
   (inte transaktionspooler), PG17-kompatibel pg_dump. Password i OS-keychain eller
   privat pgpass med 0600, anslutning i privat servicefil. Inte i argv, shellhistorik,
   processlogg, publika CI-variabler eller dokument. Undvik lösenordsreset som exportmetod.
2. Ta logisk schema/data-export med konsistent pg_dump-snapshot, roller/grants och
   migrationshistorik. Supabase CLI-guidens roller/schema/data är utgångspunkt, INTE
   bevis att allt ingår: CLI anger att managed auth/storage/extensions kan exkluderas.
   Kontrollera `--help`, `--dry-run` och faktisk dump-TOC mot källkatalogen före export.
   Auth-export måste explicit täcka alla använda Auth-tabeller och lösenordshashar;
   users/identities räcker bara för det syntetiska e-posttestet i denna PR. Inventera
   MFA/SSO, triggers och plattformsversion innan en produktionsrestore godkänns.
3. Samla public-tabeller utan undantag, inklusive snapshots, medlemscredentials,
   Klubbhus, Tour och push. Samla typer/sequences/constraints/index/policies/ACL,
   RPC-signaturer/definitioner/search_path/ägare, custom managed-schema-policyer,
   triggers och Realtime-publication. Extensions/Vault behöver separat hantering.
   Granska versionsanpassat managed-schema-diff; ersätt inte nya plattformstabeller
   blint med gamla DDL-definitioner. Bevara migrationshistorik separat.
4. Storage: inventera alla buckets (public/private, MIME/storleksgränser) och samtliga
   objekt med stabil id/path, owner, content type, cache-control, storlek, metadata,
   SHA-256 och listtid. Lista med pagination och rekursion tills HELA listan är slut;
   officiella migreringsexemplets list-limit får inte bli en tyst kapning. Läs binärer
   via godkänd Storage API-klient till privat staging, inte signerade URL:er i loggar.
   Spara manifest även för tomma buckets. Metadata ensamt är inte bildbackup.
5. DB och Storage saknar gemensam atomär snapshot: planera kort godkänt skrivuppehåll,
   eller gör dubbel inventering före/efter och omtag om id/version/size/referenser ändras.
   En DB-snapshot räcker inte för samtidiga bildändringar. V1 hälsokontroll fortsätter
   läsa; inget driftstopp eller skrivblock införs utan separat beslut.
6. Säkra Edge-källkod/import maps/låsfiler/versioner/JWT-flaggor, Auth-URL/redirects,
   SMTP/providers, Realtime-/Storage-/webhookinställningar och extern konfiguration.
   `secrets list`/hashar kan inte återskapa värden. Referera hemligheter till privat
   lösenordsvalv; OpenAI kan återutfärdas, VAPID-par bör bevaras eller alla klienter
   återprenumerera. Vault/kolumnkryptering kräver originalets krypteringsnyckel enligt
   aktuell Supabase-guide, eller uttrycklig säker nyckelåterställningsprocedur.
   `supabase_vault` är installerat; användning är inte kontrollerad genom hemlighetsläsning.
7. Gör privat git mirror/bundle vid samma release och spara deploymentinställningar,
   utan att föra in serversecrets i källkod. Källkod är inte körande tjänstekonfiguration.
8. Bygg manifest med backup-id, UTC start/slut, projekt/ref, commit, PostgreSQL/CLI-
   version, komponentlista, counts, per-fil SHA-256, objektantal/bytes, katalogfingeravtryck,
   krypteringsmetod och nyckel-id (ALDRIG nyckelvärde). Känsliga filnamn/id/hashar stannar
   inuti krypterat paket. En yttre checksumma av ciphertext kan lagras separat privat.
9. Kryptera med etablerad GnuPG/age på betrodd dator, helst publik mottagarnyckel för
   obevakad körning och separat offline dekrypteringsnyckel. Ingen egen kryptodesign.
   Kontrollera mottagarfingerprint, testa nyckelåtervinning. Nyckeln förvaras inte med
   enda backupkopian; minst en säkert återvinningsbar reservnyckel hos utsedd ägare.
10. Kopia A i befintlig privat offsite-lagring med MFA/versionshistorik; kopia B på
    annan fysisk plats/annan oberoende enhet eller leverantör, inte bara två mappar
    i samma konto. Kontrollera ciphertext-SHA på båda efter överföring, provdekryptera
    återhämtad B privat och verifiera inre manifest. Rensa privat klartextstaging först
    när två godkända kopior finns. Krypterad disk krävs även för temporära filer;
    radering på SSD är inget säkert wipe-löfte. Ingen backup ska checkas in.

### Automation, retention och mål

Förslag för ägarbeslut: backup direkt efter betydande schema-/säsongs-/medlemsändring,
samt veckovis under vintern via OS-scheduler på betrodd dator/NAS. Behåll åtta veckokopior
och tolv månadskopior, plus verifierad kopia före större ändring. Radera aldrig senaste
två godkända återställningspunkter; retention verkställs först efter verifierade nya kopior.
Kapacitet måste mätas före löfte om $0. Bärbar dator kan vara avstängd: då är schemat
inte garanterat. En befintlig alltid-på-enhet är ett driftberoende, inte en betaltjänst här.

Varje körning ska fail-closed på dumpfel, ofullständig lista, ändringar under insamling,
manifestfel, krypteringsfel eller saknad kopia. Lås för överlappande backupjobb. Ingen
framgångsping förrän båda kopior och integritet är verifierade. Separat oberoende
Healthchecks-kontroll för backup, exempelvis period 7 dagar + grace 1 dag, eget secret
på backupdatorn. Skicka inga filnamn/medlemsdata. Detta kräver samma externa godkännande
och separat larmtest; det implementeras inte som ett osäkert publikt exportjobb.

Föreslaget RPO högst sju dygn, plus ändringsdrivna kopior; RTO-mål en arbetsdag efter
åtkomst till fungerande isolerad målmiljö. Detta är mål, inte uppmätta garantier.
Full återställningsövning före driftgodkännande och därefter kvartalsvis samt efter
större schema-/Auth-/Storageändring. Krypterad backup utan återställningsprov räcker inte.

### Återställningsordning och acceptans

1. Godkänn isolerad tom målmiljö och kostnad först; använd aldrig produktion som mål.
   Verifiera projekt-id/URL, nätisolering, PG-/Auth-/Storage-version och extensions.
   Stäng av utgående push/mejl/OpenAI/webhooks under övningen. Använd inga verkliga
   konton i publik CI. Produktionskopior får bara återställas i särskilt godkänd privat miljö.
2. Hämta kopia B, verifiera ciphertext-hash, dekryptera privat och kontrollera varje fil
   mot inre manifest. Avbryt vid avvikelse. Kontrollera täckningslista innan DDL körs.
3. Återskapa plattformens kompatibla grund, egna roller/grants och Auth enligt aktuell
   Supabase-guide, sedan applikationsschema/data med FKs i korrekt ordning. Återskapa
   custom managed-schema-RLS/triggers, migrationer, extensions och Realtime-publication.
   Restore ska stoppa vid första SQL-fel och vara transaktionell där möjligt. Ingen
   automatisk prod-restore. Rollen/superuserprivilegier i syntetisk CI är inte mall för
   oinspekterad hosted restore. Custom role-passwords måste hanteras separat.
4. Återskapa bucketinställningar och ladda upp binärer via Storage API, inte genom
   direkt INSERT av storage.objects utan filer. Bevara path/owner/MIME och alla
   bildreferenser; återskapa och verifiera policyer innan medlemsåtkomst öppnas.
5. Deploya exakta Edge-källversioner och återställ secrets via säker procedur; prova
   först syntetiska nycklar/mottagare. Nytt projekt har nya URL/API-/signeringsnycklar;
   dokumentera ombindning och ny inloggning. Bevarade lösenordshashar kan fungera
   över projekt men gamla token behöver inte vara giltiga. MFA/Vault måste provas separat.
6. Jämför alla tabellantal, FKs, officiella champions/snapshot-hashar, omgångar/resultat,
   sex leaderboardkategorier och statistik, meddelanden/reactions och samtliga bildhashar.
   Riktiga separata test-Auth-sessioner: admin, medlem, okänd, anonym; endast medlem
   får privata bilder, medlem får inte adminrättigheter. Kontrollera kodhash-/Authkoppling
   och avsedd inloggning utan att logga värden. Prova nya bilder, Realtime, push/PWA
   och GameBook isolerat innan extern trafik åter tillåts; ingen sådan full certifiering här.
7. Först efter signerad acceptans tas separat beslut om cutover/configändring. Ingen
   automatisk DNS-/Pages-/frontendomkoppling. Vid misslyckad övning bevara källan och
   befintliga krypterade kopior, isolera målet, rapportera luckan; rör inte produktion.

## Isolerad implementation och bevisgräns

`ops/dr-local-qa.mjs` vägrar allt utom GitHub PR + exakt loopback-portar och fast
disposable container. Det använder riktiga lokala Supabase Auth/Storage/PostgreSQL,
syntetiska fem konton och en 1×1 PNG. Det tar verklig pg_dump, GnuPG-krypterar paketet,
skriver två privata testkopior, verifierar manifest, simulerar förlust och återläser.
Skriptet är INTE produktions-exporter eller generell restore-klient. Det återskapar
public-schema och test-Auth i samma plattformsstack, inte en ny hosted plattform.
JSON/in-memory-paketet är avgränsat till syntetisk QA; verklig backup ska vara streaming
och dimensionerad för fulla bildvolymer. Två mappar i CI är inte två offsite-kopior.

Auth users/identities och nya lösenordsinloggningar provas; MFA/SSO, Vault, riktiga
Golf-ID/CBO-koder, provider-/SMTP-/Edge-secrets och fulla produktionsbilder provas inte.
Publika funktioner/policyer/index och hela syntetiska 2026-payloaden jämförs före/efter.
Storage-policy återförs uttryckligen och privata binärer laddas upp via API; medlem,
okänd och anonym provas. Plattformens managed schemas/nycklar ersätts inte.
Detta stärker metodbeviset men stänger inte produktionsbackupens inventerade luckor.

`.github/workflows/cbo-winter-v2-qa.yml` är PR-only, standard kostnadsfri public runner,
read-only GitHub-token, ingen hosted anslutning, inget artifact-uppladdningssteg.
Genererade lokala nycklar maskeras och stack/temporära syntetiska backuper tas bort.
Den befintliga Season QA och v1-kontrollens endpoint/schedule/felhantering bevaras.
Se separat QA-rapport för faktiska resultat, inte förhandsantaganden.

## Beslut och GO/NO-GO

GO för granskning/isolering inom mandatet. NO-GO för påstående om komplett autonom
drift eller komplett produktions-DR före följande separata beslut och verifiering:

- Godkänn Healthchecks-konto/mottagare, två kontroller om backup ska övervakas, repo-
  secret/opt-in-variabel och verkligt avgränsat larmtest. Ingen är skapad här.
- Godkänn granskad PR/merge och separat produktionsintegration; befintlig v1 går vidare
  utan v2 tills dess. Rollback av v2-heartbeat: stäng opt-in efter beslut, bevara v1.
- Utse backupansvarig, betrodd alltid-på-körplats, två privata oberoende lagringsplatser,
  nyckelförvaring/ersättare, retention samt RPO/RTO. Bekräfta befintlig fri kapacitet.
- Godkänn känslig read-only produktionsdataexport och exakt behörighetsmetod, samt
  kort skrivuppehåll eller konsistensstrategi. Dela inga credentials i chatt.
- Godkänn privat isolerad återställningsövning av komplett backup och konfigurations-/
  secretsprocedur. Ingen produktionsrestore, Supabase-konfigändring eller cutover följer härav.

## Officiella källor granskade 21 oktober 2026

- https://healthchecks.io/pricing/
- https://healthchecks.io/docs/http_api/
- https://healthchecks.io/docs/configuring_checks/
- https://healthchecks.io/docs/configuring_notifications/
- https://healthchecks.io/docs/reliability_tips/
- https://healthchecks.io/docs/faq/ (kontoinaktivitet och e-postpåminnelser)
- https://supabase.com/changelog.md (TLS-ändring 10 november, moderna klienter krävs)
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/reference/cli/supabase-db-dump
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- https://supabase.com/docs/guides/troubleshooting/migrating-auth-users-between-projects
- https://supabase.com/docs/guides/getting-started/api-keys
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule

Leverantörsvillkor kan ändras. Kontakta inte leverantör eller skapa konto automatiskt.

# CBO Season Management v1 — kostnadsfri QA

Det betalda stagingförslaget är inte längre en teknisk förutsättning för kärnverifieringen. Inget Supabase-projekt eller abonnemang har skapats eller ändrats. Appkod, release-SQL, produktion och CBO on Tour är oförändrade av detta arbete.

## Kostnadsfri väg som faktiskt används

CBO-repot är verifierat publikt. Standardrunnern `ubuntu-24.04` i GitHub Actions är kostnadsfri för publika repos. Inga större/betalda runners används. Jobben är dessutom villkorade på att repot är publikt; i annat fall startas de inte. Workflow har bara `contents: read`, använder inga repository secrets, ingen produktionsanslutning och har ingen deploy-/Pages-åtgärd.

En tillfällig PostgreSQL-container och en separat lokal Supabase-stack körs på runnern. Supabase CLI startar lokala Docker-tjänster utan att länkas till ett hosted projekt. Därmed behövs ingen tredje Free-projektplats, Pro-plan, separat betald organisation eller användardator med Docker. Miljön binds till loopback, använder egna temporära Auth-identiteter och avslutas efter testet med borttagna datavolymer. Inga rapportartefakter med hemligheter laddas upp.

Officiella källor, kontrollerade 19 oktober 2026:

- https://docs.github.com/en/actions/concepts/billing-and-usage
- https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job
- https://supabase.com/docs/guides/local-development
- https://supabase.com/docs/guides/local-development/cli/testing-and-linting

## Genomförd verifiering

### PostgreSQL 17.6, separata sessioner — PASS

Första verifierade körningen: https://github.com/urbanzakrison/CBO/actions/runs/39237803654

Åtta scenarier passerade med två olika `pg_backend_pid()` (93 och 94 i första körningen). Testet kontrollerar i `pg_locks` att det konkurrerande anropet faktiskt väntar på advisory-låset innan den första transaktionen släpps; det förlitar sig inte bara på sekventiella anrop eller ett godtyckligt sleep.

1. Två samtidiga create: en förberedd säsong, det andra anropet avvisas.
2. Två samtidiga activate: en lyckas, den andra avvisas som inaktuell; exakt en aktiv säsong.
3. Publish håller låset först: den sparade omgången finns i utgående snapshot.
4. Activate håller låset först: gammalt speldatum avvisas utan partiella resultat; omgång 1 fungerar i nya året.
5. Konkurrerande dubblett av omgångsnummer avvisas.
6. Konkurrerande dubblett av datum avvisas.
7. Rollback av aktivering lämnar ingen halvuppdaterad säsong eller snapshot.
8. Vanlig SQL-roll/anon kan inte skapa/aktivera/läsa skyddad snapshot.

De tidigare 7 automatiska testerna passerar också i GitHub-runnern. Evidens: `SEASON_MANAGEMENT_FREE_QA_EVIDENCE.json`.

### Verklig lokal Supabase Auth, RLS, RPC och mobil-UI — PASS

Körning: https://github.com/urbanzakrison/CBO/actions/runs/39238252546

Teststeget `Real local Supabase Auth, RLS, RPC and mobile UI` passerade mot riktiga lokala Auth- och PostgREST-tjänster. Supabase CLI 2.121.0, supabase-js 2.118.0 och Playwright 1.62.1 är låsta i konfiguration/dependencies.

- Separata verkliga Auth-sessioner för syntetisk admin, medlem och oregistrerat konto. Inga sessionsadaptrar i detta test.
- Den befintliga `auth-client.js` används i mobilwebbläsaren med lokalt konfigurerad Supabase URL/publishable key.
- Admin kan skapa FÖRBEREDD 2027 utan att 2026 ändras och kan genom uttrycklig UI-bekräftelse aktivera 2027 i testmiljön.
- Medlem, okänt konto och utloggad klient avvisas. `user_metadata.is_admin=true` hos medlem ger ingen behörighet.
- RLS blockerar medlem från direkta säsongsskrivningar; snapshottabellen är otillgänglig för medlem. EXECUTE och search_path för de nya RPC:erna granskas i systemkatalogen.
- Ny leaderboard är tom; omgång 1 publiceras i 2027; dubblett stoppas; 2026-payload är exakt bevarad.
- Verkligt medlemskonto i separat webbläsarkontext saknar Admin-UI. Inga okontrollerade JavaScript-fel.

Testet bygger en relevant vanlig-CBO-tabell/RPC-del runt verklig lokal Supabase Auth och de inspekterade publicerings-/läsfunktionerna. Det är inte en komplett kopia av alla produktionsobjekt: exempelvis medlemsregistrering/kodgenerering, Klubbhus och On Tour byggs inte om för testet. Testbootstrapens begränsning ska bevaras i bedömningen.

### Officiella lokala Security Advisors och SQL-lint

Nästa CI-körning lägger till `supabase db advisors --local --type security` och `supabase db lint --local --schema public`. CLI:s `--help` har verifierat att båda stödjer lokal databas. PASS ska registreras först efter körningen; en systemkatalogkontroll ensam räknas inte som en genomförd Advisor-körning.

## Kvarvarande gränser

- Riktig OpenAI-bildtolkning körs inte: inga betalda API-anrop eller produktionsnycklar får användas under kostnadskravet. Det tidigare GameBook-gransknings-/publiceringstestet med kontrollerad parserutdata, gäst, SHCP och 4–3–2–1 poäng gäller fortsatt.
- Realtime/OS-push/PWA har inte fått en ny fullständig flerklient-/enhetscertifiering här. Realtimetjänsten kan finnas i lokalstacken, men det är inte i sig bevis för ett fungerande CBO-flöde. Ingen produktionspush skickas.
- Lokala Advisors gäller testdatabasen. Det är inte samma sak som en ny granskning av alla objekt och alla plattformsinställningar i produktionsprojektet.
- Den tidigare historikgranskningen på den avgränsade tävlingskopian gäller oförändrat; rådataexporten publiceras inte i CI eller GitHub.

## Återanvändbara filer

- `.github/workflows/season-qa.yml`: kostnadsfria, tidsbegränsade jobb, lokala tjänster och cleanup.
- `tests/season-postgres-qa.mjs`: strikt loopback-/testdatabasguard, separata PG-sessioner, deterministisk låsverifiering.
- `tests/season-supabase-local-qa.mjs`: strikt loopback-/portguard, verkliga Auth-sessioner, API-/RLS-kontroller, faktiska mobilinloggningar.
- Paketversioner är låsta; GitHub checkout/setup-node är låsta till verifierade commit-SHA. Tillagda paket är enbart dev dependencies.

Ingen merge eller produktionsinstallation är utförd eller automatiskt godkänd av ett grönt test. Slutlig GO/NO-GO ska väga verifierade kärnkrav och uttryckligt kvarvarande tjänste-/enhetsunderlag. Ett betalt stagingprojekt behöver däremot inte godkännas för att fortsätta dessa tester.

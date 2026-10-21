# CBO Winter Operations v1

21 oktober 2026. Status: DEVELOPMENT / QA, inte aktiverad drift och inte FULLY VERIFIED.
Ingen merge, produktionsworkflow, databasändring eller ny credential är godkänd i detta uppdrag.

## Verifierad inventering

- Aktuell main: `4c9cb505292dbe4a1cd3873934dd3ce168a1baed`; inga senare main-commits vid inventeringen. Repo publikt, inte arkiverat.
- Befintlig egen workflow: `.github/workflows/season-qa.yml`, endast PR-QA. Den ändras inte. GitHub Pages har också sin separata publiceringsmekanism; den nya driften innehåller inget deploy-steg.
- Supabase `lwymnhmwrinzuvmoqqif`, eu-west-1, PostgreSQL 17.6.1.166, `ACTIVE_HEALTHY`, organisation på `free` / `tier_free`.
- Databasen bekräftar 2026 AVSLUTAD och 2027 PÅGÅENDE. Denna leverans utför inget säsongsskifte.
- Befintliga `public.is_cbo_member()` är SQL, STABLE, läser medlemskopplingar och returnerar boolean. Anonym EXECUTE är redan tillåten. Definition och rättighet inspekterade i pg_proc före implementation. Ingen ändring av funktionen eller dess rättigheter.
- Befintliga privata Storage-bucket `cbo-clubhouse`: sju objekt vid inventeringen. Inga objekt eller medlemscredentials har exporterats för övervakningen.
- De bifogade MASTER/PROJECT RULES 4.6.5.3 gäller tillsammans med senare verifierad main; ingen äldre frontend läggs ovanpå produktion.

## Kontrollens kontrakt

`.github/workflows/cbo-winter-health.yml` föreslår en körning per dygn, `23 6 * * *` UTC. Det motsvarar 07:23 svensk vintertid / 08:23 sommartid. `workflow_dispatch` finns för manuellt prov. GitHub kräver default-branch för schedule och dispatch: dessa vägar kan inte verifieras före separat merge/aktivering. PR-triggern kör enbart isolerad QA och ett legitimt read-only-prov, inte den schemalagda produktionsjobben.

`ops/winter-health.mjs` använder bara Node 24-standardbibliotek; inga npm-installationer, externa actions utöver SHA-låsta GitHub checkout/setup-node, repository secrets eller nya inloggningar.

| Kontroll | Begäran | Godkänt svar |
| --- | --- | --- |
| Frontend | GET på exakt `https://urbanzakrison.github.io/CBO/` | HTTP 200, HTML och förväntade CBO-/inloggnings-/scriptmarkörer; generell felsida med 200 avvisas |
| Supabase-databas | POST `{}` till befintlig `/rest/v1/rpc/is_cbo_member` | HTTP 200, JSON, exakt `false` från anonym databasfunktion |

RPC:n använder POST som transport men utför endast en befintlig STABLE SELECT. Detta går genom Data API till PostgreSQL; det är starkare än enbart en Auth-/gateway-ping. Det verifierar inte riktiga användarsessioner, kompletta affärsflöden eller Storage/Realtime. Den befintliga publishable-nyckeln läses som text ur config.js utan att exekvera filen; inget service-role-, admin-, användar- eller Golf-ID-anrop görs. Nyckeltyp och projektdomän valideras. Ingen ny nyckel skapas och inga nya endpoints öppnas.

Begäran följer inga redirects, har 15 s deadline inklusive body-läsning och storleksgräns (1 MiB HTML, 32 byte boolean). Högst tre försök, en sekund mellan försöken, endast övergående HTTP-/nät-/TLS-/timeoutfel. Fel innehåll och permanenta HTTP-fel upprepas inte. Tjänsterna kontrolleras oberoende. Jobbtimeout fyra minuter. Ingen automatisk återstart/resume av Supabase.

Varje körning skriver UTC, PASS/FAIL, HTTP-kod, total svarstid inklusive retries, antal försök och en fast felkod i JSON och GitHub job summary. Fel ger exit 1 / röd status. Svarskroppar, nycklar, exceptionstext och medlemsinformation loggas aldrig. Ingen artifact innehåller råsvar. Betalda/större runners, deploy, write-token eller externa aviseringsintegrationer saknas; jobben körs endast i det publika originalrepot.

## Supabase-pausning: övervakning, ingen garanti

Supabases officiella pausdokument beskriver låg databasaktivitet under sju dagar och att viss API-/användaraktivitet kan påverka bedömningen. Exakt tröskel eller garanti för ett dagligt anonymt read-only-anrop publiceras inte. Den här kontrollen har ett legitimt hälsosyfte och kan bidra med databasaktivitet, men utlovar aldrig pausningsskydd. Ingen artificiell trafik, skrivning eller ökande anropsfrekvens används för att kringgå planens begränsningar.

Vid fel kan kontrollen visa att tjänsten inte svarar som väntat; HTTP-fel ensamt bevisar inte paus. Kontrollera Supabase Dashboard för faktisk status. Leverantörens egna pausvarningar till projektägaren är kompletterande, inte bevisat mottagna här. Om paus bekräftas kan projektägaren återuppta det i Dashboard; detta automatiseras inte.

Changelog granskad: annonserad TLS-ändring tidigast 10 november 2026 tar bort gamla CBC-chiffer. Node 24/modern Ubuntu används; TLS-verifiering är aktiv och ingen gammal cipher tvingas. Andra orörda klienters kompatibilitet certifieras inte av kontrollen.

## Avisering och bevisnivå

1. Röd GitHub-status och sanerad job summary fungerar utan externa konton.
2. Projektägaren väljer GitHub Settings → Notifications → System/Actions → Email eller On GitHub, gärna bara fel. Kontrollera också repo-bevakning. Schemalagda aviseringar kopplas enligt GitHub till den som senast ändrade cron; kontrollera verklig mottagare vid aktivering. Dessa användarinställningar ändras inte av leveransen.
3. Under isolerad PR-QA verifierades ett avsiktligt offlinefel med verklig röd Actions-status: run `39554487749` på commit `a02fb1d`. Först passerade 13/13 tester och ett riktigt read-only-prov; sedan gav simulerad frontend-503 FAIL efter exakt tre försök och exit 1. Det tillfälliga felsteget är borttaget från slutkandidaten. Efter aktivering krävs dessutom ett kontrollerat dispatch-prov och bekräftelse från ägaren för faktisk leverans/mottagning. Inga externa e-postmeddelanden skickas av skriptet.

| Led | Vad som räknas som bevis |
| --- | --- |
| Kontroll körd | Run-ID och UTC/logg |
| Fel upptäckt | Exit 1 och rött jobb, med specifik felkod |
| Avisering skickad | Leverantörens leveranslogg eller verifierbar notifikation; rött jobb räcker inte |
| Avisering mottagen | Ägarens faktiska notifikation/bekräftelse; detta får inte antas |

## Övervakningen kan själv stanna

GitHub kan stänga av schedules i publika repos efter 60 dagar utan repositoryaktivitet. Schemalagda jobb kan också fördröjas eller tappas. Egna körningar är därför inget löfte om evig drift. Ingen tom commit, automatisk repomodifiering eller activity-bot införs.

`ops/winter-watchdog.mjs` granskar offentliga GitHub API-metadata utan token. Den kräver aktiv workflow, en verklig schedule-körning (dispatch/PR räcker inte), senaste schemakörning completed/success och högst 48 h ålder. Disabled, missad körning, fel och API-fel ger FAIL. Den måste köras av en OBEROENDE timer för att skydda mot att detta repos schema stannat; att lägga den i samma workflow löser inte problemet. Första schemakörningens frånvaro ger avsiktligt FAIL under införandet.

Förslag som kräver separat beslut: en kostnadsfri dead-man-kontroll hos Healthchecks.io (officiellt upp till 20 kontroller utan kreditkort). Daglig health PASS ska då signaleras utan payload via en hemlig ping-URL, med period 24 h + 24 h grace. Utebliven signal varnar även om GitHub stängs av. Konto, mottagare, secret och integration skapas INTE i denna PR. Alternativ utan nytt konto: kör watchdog via en befintlig alltid-på-dator/NAS med egen scheduler och befintlig godkänd avisering. Tillgänglig sådan miljö är inte verifierad. En veckovis kalender-/ägargranskning av Actions och Supabase-varningar är en manuell reservrutin, inte autonomt skydd.

Enbart denna workflow är alltså inte komplett autonom vinterdrift efter en eventuell 60-dagarsavstängning. Produktionsaktivering bör kombinera vald oberoende kontroll och notifieringsprov, eller uttryckligt acceptera den manuella reservrutinen. Ingen sådan integration aktiveras genom merge av denna kod.

## Loggretention och kostnad

GitHub anger standardretention 90 dagar och högst 90 dagar för publika repos; faktisk kontoinställning har inte kunnat läsas via tillgänglig connector. Bekräfta den före aktivering, ändra den inte automatiskt. Job summary/loggar är spårbara inom faktisk retention och är inte ett permanent arkiv över hela vintern. Behövs längre historik: godkänn separat privat export av enbart sanerade resultat. Inga loggcommits eller rådataexporter införs.

Standard GitHub-hosted runners är enligt GitHub kostnadsfria i publika repos. Repo-visibility-villkor stoppar jobben vid privat repo; det är en täckningsbegränsning som oberoende watchdog ska upptäcka, inte en dold övergång till debitering. Ingen ny betaltjänst används.

## Backupinventering och återställningsgräns

Känd backup: `/CBO App/CBO_PRODUCTION_PREINSTALL_2026-10-19.json`, sparad privat 19 oktober 11:42:49 UTC. Library-sökning identifierade ingen senare CBO-backup. Lokal kopias SHA-256 matchar installationsrapporten: `5a49f716f1d502462a74b73dcb8272893199383ca3cf1999b1c0fccb6cff4086`.

Den innehåller 16 säsonger, 222 omgångar och 1 525 resultat; season_players, säker spelarprojektion, sju relevanta funktionsdefinitioner/ACL samt constraints/index/RLS/policy-metadata. Detta är en avgränsad pre-installationskopia, inte full pg_dump med alla typer/kolumner/triggers/objekt. Den föregår aktivering av 2027 och saknar den nya frysta 2026-snapshoten. Den täcker inte Auth/credentials, Klubbhusets innehåll och privata bildbinärer, Edge Function-secrets eller komplett konfiguration.

En isolerad återläsningskontroll av tävlingsdelen genomfördes mot PGlite-fixturschemat, aldrig mot produktion: checksumma verifierad och 16 säsonger, 222 omgångar samt 1 525 resultat återlästa med sina relationer. Den visar endast att denna del kan importeras; full återställning av den nuvarande CBO-tjänsten är INTE verifierad. Källbackupen och tävlingsdata skickas inte till publika CI-loggar eller repository. Supabase Free saknar verifierat nedladdningsbart användarbackupunderlag här. Tillgänglig connector kan inte lista plattformsbackuper; det görs inget antagande om deras existens. Databasbackuper innehåller enligt Supabase inte Storage-objektens binärer.

Separat kostnadsfritt backupförslag för godkännande: från ägarens betrodda dator ta schema/roller/data enligt Supabase CLI-guide, inventera inkluderade/exkluderade Auth-/Storage-tabeller och konfigurera en kontrollerad export av privata Storage-binärer med befintlig behörig klient. Kryptera lokalt, lagra två privata offsite-kopior i redan befintlig lagring, och behåll metadata/checksummor utan innehåll i protokollet. Säker anslutningsmetod/behörigheter och krypteringsnyckelförvaring måste beslutas först. Återläs schema, data och bilder i lokal Supabase och verifiera counts, champion/snapshot-hashar, referenser och bildchecksummor innan planen kallas återställningsbar. Kör vid riktiga ändringar och minst månadsvis under vintern. Ingen automatisk credential- eller produktionsdataexport byggs i denna PR.

## QA och aktiveringsbeslut

Lokalt: `node --test ops/winter-health.test.mjs` testar innehåll, separat frontend-/databasfel, strömmande timeout, max tre retries, återhämtning, permanenta HTTP-fel, begränsad svarsstorlek, fasta destinationer, publishable-format, loggsanering, CLI-exit, watchdogs schemafärskhet och förändringsscope. `node ops/winter-health.mjs` gör ett riktigt read-only-prov. Ingen appfil eller befintlig databasdefinition ändras.

QA-run-ID:n, aktuellt HEAD och det verifierade röda felprovet redovisas i PR-beskrivningen när körningarna slutförts. Dokumentet påstår inte att kommande körningar redan lyckats. Det slutliga HEAD ska ha grön PR-QA efter att avsiktligt felprov tagits bort. Första körningen `39554387054` föll före felprovet eftersom checkout saknade main-historiken som scope-testet behövde. QA-checkout korrigerades till fetch-depth 0; det felet räknas inte som det avsiktliga driftfelbeviset. Scope-testet använder PR:ns faktiska base-SHA och låser inte framtida drift till dagens main-commit.

Lokal `ops/winter-watchdog.mjs` gav avsiktligt `FAIL / NO_SCHEDULED_RUN` eftersom produktionens schema ännu inte är installerat. Detta bevisar detektionsvägen för saknad schedule, inte en aktiverad oberoende timer. Grundsvitens befintliga 9 tester körs också utan appändringar; Actions kör den befintliga Season QA separat på PR:n.

Efter separat godkännande: kontrollera main-drift och offentligt repo; mergea den granskade PR:n; ägaren kontrollerar Actions-notifikationer och cron-mottagare; kör workflow_dispatch; verifiera det faktiska schemat via minst en körning med event=schedule; testa vald oberoende frånvarokontroll och verifiera avisering skickad/mottagen. Först då kan FULLY VERIFIED övervägas. Verklig schedule kan inte provas på utvecklingsbranch utan att ändra default-branch/aktivera produktion, vilket inte är tillåtet här.

Rollback av driftfunktionen: inaktivera endast den nya workflowen efter godkänt beslut. Inga databas-/frontendåterställningar behövs. Inget automatiskt resume, säsongsskifte, backupjobb eller notifieringskonto finns att återställa.

## Officiella källor, lästa 21 oktober 2026

- https://supabase.com/docs/guides/platform/free-project-pausing
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/changelog/cbc-tls-ciphers-deprecated
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule
- https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow
- https://docs.github.com/en/subscriptions-and-notifications/how-tos/managing-github-actions-notifications
- https://docs.github.com/en/actions/concepts/billing-and-usage
- https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization
- https://healthchecks.io/docs/ och https://healthchecks.io/

# Season Management v1 — slutlig releasegranskning, 19 oktober 2026

## Granskningsgrund och gränser

PR #1 förblir utkast; ingen merge, produktionsinstallation, ny produktionssäsong eller produktionsaktivering är godkänd eller utförd. Main-baseline är `c7952ce0e92225ede30831d09e7b1dfc1779bdf1`.

`01d63d91855219c3f7284419134553ecbdf24172` → `07c0cb76c53faf5196d52e2ff7967627ba4b23eb` ändrade endast fem dokumentations-/evidensfiler. Inga app-, SQL-, test- eller dependencyändringar fanns i detta mellanrum. Den tidigare gröna körningen bevisade implementationen men avsåg inte exakt dokumentations-HEAD.

Filfiltret i `.github/workflows/season-qa.yml` är borttaget. Alla PR-synkroniseringar mot main kör nu samma kostnadsfria QA, även när endast dokumentation eller frontend ändras. GameBook-/mobiltestet med kontrollerad parserutdata ingår nu också i CI. Slutresultatet för exakt denna commit ska läsas i PR:ns kontroller och verifieringssammanfattning; ingen äldre grön commit ska användas som ersättning.

## Konkreta granskningsfynd och korrigeringar

1. Befintlig champion med tomma metadata kunde få poäng/metric/value från den automatiskt beräknade vinnaren. Aktiveringen bevarar nu samtliga championfält exakt när en officiell champion redan finns, även nullvärden. Regressionstest använder en utsedd champion som inte är den beräknade vinnaren.
2. Vid samma poäng och samma aktuella handicap använde SQL och webbläsare olika namnsortering. Utan redan utsedd champion stoppas nu aktiveringen atomärt vid olöst förstaplats. Inga poängregler ändras och ingen ny godtycklig tie-break införs. Testet verifierar både stopp utan snapshot/statusbyte och att lägre handicap avgör korrekt.
3. Historiktestet jämför nu även nyfryst 2026-champion och poäng direkt med originalversionens Totalen, utöver tidigare historiska champions och sex kategorier.

Ändrade filer i denna granskning: `.github/workflows/season-qa.yml`, `22_season_management_v1.sql`, `tests/season-database.test.mjs`, `tests/season-history-qa.mjs` samt denna rapport. Befintliga rapporter får en hänvisning till denna senare granskning. Inga frontendfiler eller On Tour ändras.

## Historik och säkerhet

Den befintliga avgränsade tävlingskopian används enbart lokalt i isolerad PGlite: 16 säsonger, 222 omgångar, 1 525 resultat. Råkopian skickas inte till GitHub eller publika runners. Sex leaderboardkategorier 2026, alla omgångs-/resultatrader, champions 2011–2025 och statistik 2021–2026 jämförs med originalbaseline. Efter ändrat handicap ska snapshoten vara identisk. Ingen aktivering körs i produktion.

Nya RPC:er har explicit medlems-/adminverifiering i databasen, tom search_path och EXECUTE endast för authenticated; direkt snapshotåtkomst är återkallad och RLS aktiverad. Gemensamt transaktionslås i create/activate/publish och unikt partiellt index skyddar den ordinarie säsongsvägen. Tidigare direkta administratörsskrivningar via befintliga policies byggs inte om; säsongsskiften ska ske via RPC:erna. Publicerarens befintliga scoringloop och befintliga behörighetsmodell bevaras.

CI använder syntetiska data och riktiga separata lokala Supabase Auth-sessioner. Security Advisors avser lokal testdatabas; SQL-lint kräver samma fynd före/efter installation, utan nya fynd. Ett känt befintligt lintfynd i statistikens oanvända schemareservgren kvarstår uttryckligt redovisat.

## Releasebeslut och kvarvarande gränser

Efter grön körning på aktuell PR-HEAD och godkänd historikjämförelse: tekniskt GO för separat beslut om kontrollerad installation, utan att skapa eller aktivera någon säsong. Detta är en rekommendation, inte ett installationsmandat. Vid rött test gäller NO-GO tills orsaken är löst.

Verklig OpenAI-bildtolkning, fleranvändar-Realtime, OS-push och installerad PWA är fortsatt inte fullständigt omtestade. Kontrollerad GameBook-parserutdata bevisar gransknings-/publiceringsflödet, inte bildtolkningen. Lokalt schema är relevant CBO-del, inte full hosted produktionsklon. Inga nya produktionsverifieringar påstås i denna granskning.

Produktions-/rollbackplanen i `SEASON_MANAGEMENT_V1.md` och den skyddade `23_season_management_rollback.sql` gäller: separat installationsgodkännande, baselinekontroll/backup och installation utan säsongsbyte, därefter verkliga smoke tests. Rollback-SQL får bara användas före funktionens första användning; efter skapande/aktivering bevaras data och forward fix krävs. Skapande av FÖRBEREDD 2027 och senare aktivering kräver egna uttryckliga beslut.

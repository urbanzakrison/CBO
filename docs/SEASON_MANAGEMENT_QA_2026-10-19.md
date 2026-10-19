# CBO Season Management v1 – fördjupad QA, 19 oktober 2026


> Uppdatering: kostnadsfri GitHub Actions-/lokal Supabase-QA finns nu. Se `SEASON_MANAGEMENT_FREE_QA_2026-10-19.md`. Tidigare uppgifter om att betald staging krävs gäller inte längre kärnverifieringen; äldre miljöresultat nedan är historik.
**Beslut: fortsatt utkast. Inte godkänd för merge eller produktion.**

Granskad implementation: PR #1, commit `0c3c886a1a7272c8a640b9d0fd857ac18fc1abef`. Denna komplettering ändrar endast tester och dokumentation. Appkod och SQL-implementation är oförändrade.

## Resultat

| Kontroll | Resultat | Faktisk miljö |
| --- | --- | --- |
| Ursprungliga automatiska tester | 7/7 reproducerade | Isolerad PGlite/PostgreSQL |
| 2026: Totalen, Närvaro, Netto, Brutto, Effektivitet, Topp 8 | Exakt samma före installation, efter förberedelse, efter aktivering och efter senare HCP-ändring | Kopia av aktuella tävlingsdata, faktisk gammal/ny JS-beräkning |
| Samtliga omgångs- och resultatrader | Oförändrade efter testskiftet | Isolerad datakopia |
| Säsonger/champions före 2026 | Oförändrade inklusive ursprungliga fält | Isolerad datakopia |
| Statistik 2021–2026 | Exakt samma RPC-resultat före och efter | Inspekterad produktionsdefinition i testkopian |
| GameBook-granskning → publicering i 2027 | Godkänd: gäst med lägst netto undantas; lika netto avgörs med lägre SHCP; 4–3–2–1 poäng; omgång 1; dubblett stoppas | Playwright 390×844 mot isolerad SQL-backend |
| Vanlig medlem/okänd/anonym/inaktiv admin | Skapa/aktivera avvisas; UI döljer admin för medlem | SQL-rolltester samt webbläsare med lokal sessionsadapter |
| Supabase-staging | Blockerad: kräver Pro eller högre | Riktig Supabase-verktygsrespons; ingen branch skapad |
| Samtidig publicering/aktivering från separata PG-sessioner | Inte genomfört | Ingen tillgänglig servermiljö för sådant test |
| OpenAI-bildtolkning, verklig Supabase Auth, Realtime, OS-push | Inte nycertifierade | Kräver godkänd Supabase-staging och verkliga testklienter |

## Historiktestets underlag och metod

En avgränsad SELECT läste 16 säsonger, 15 spelarposter, 222 omgångar och 1 525 resultatrader från produktion. Exporten uteslöt `player_credentials`, faktiska auth-identiteter, Golf-ID, CBO-koder, nycklar och `rounds.created_by`. Inga produktionsuppgifter ändrades.

Tävlingsdata importerades i en isolerad testdatabas med de inspekterade SQL-definitionerna. En syntetisk lokal auth-identitet användes enbart i denna kopia. Säsongsskapande och aktivering utfördes endast i testkopian. Originaldataexporten ligger bland ignorerade testmellanresultat och ingår inte i PR:n.

`tests/season-history-qa.mjs` jämför den faktiska leaderboardberäkningen i main-commit `c7952ce…` med PR:ns faktiska beräkning; den ersätter inte beräkningen med en egen modell. Dessutom jämförs alla råa omgångs-/resultatrader, historiska säsongsfält och statistik-RPC:ns svar. Resultat och SHA-256 finns i `SEASON_MANAGEMENT_QA_EVIDENCE.json`, utan enskilda spelares data.

Körning med en motsvarande lokal, avgränsad export:

```sh
CBO_QA_HISTORY_FILE=test-results/production-readonly-data.json node tests/season-history-qa.mjs
npm test
CHROMIUM_EXECUTABLE_PATH=/path/to/chromium npm run test:browser
```

`tests/season-browser.mjs` använder nu riktiga `renderGameBookReview`, `applyGameBookReview`, `saveDraft`, dubblettkontroll och publicerings-RPC i testmiljön. Ingången är ett kontrollerat tolkningsresultat: fyra medlemmar och en gäst. Detta verifierar gransknings-/publiceringsdelen, **inte** anropet till OpenAI eller tolkning av en riktig bild. Inga produktionsanrop görs av webbläsartestet.

## Blockerande miljöförhållanden

1. Det fanns inga befintliga utvecklingsbrancher i Supabase-projektet. Ett försök att skapa `cbo-season-management-qa` misslyckades först med `Invalid or expired requestState`. En efterföljande branchlista var tom. Nästa försök gav `PaymentRequiredException: Branching is supported only on the Pro plan or above`. Ingen stagingbranch eller abonnemangsändring har genomförts.
2. Som kompletterande möjlighet förbereddes PostgreSQL 17.6-binärer lokalt, samma huvud-/underversion som den inspekterade produktionen. Serverstart stoppades innan någon databas initierades: `chown: Invalid argument` och `runuser: cannot set groups: Operation not permitted`. Inga säkerhetskontroller kringgicks. Det testet räknas inte som genomfört.
3. PGlite ger riktig SQL-exekvering men inte oberoende serveranslutningar. Sekventiell dubbelkörning, unikhetskrav, rollback och behörighetstest är godkända; dessa får inte beskrivas som ett genomfört samtidighetstest.

## Kvar till slutacceptans

Det behövs ett uttryckligen godkänt separat Supabase-testprojekt eller möjlighet till branching på Pro-plan. Byt inte abonnemang automatiskt och använd inte produktion för att kompensera för blockerad staging.

I den miljön återstår:

- Kontrollera/basera schemat på faktisk produktion: projektets migrationshistorik är inte en fullständig garanti för att äldre manuellt installerade tabeller/RPC:er följer med till en ny branch. Importera endast granskade beroenden och syntetiska testcredentials.
- Applicera release-SQL endast i staging och kör Supabase security advisors på de nya funktionerna/privilegierna.
- Testa vanlig medlem och admin via separata riktiga Supabase-sessioner.
- Låt två samtidiga create-anrop konkurrera: exakt ett ska lyckas. Testa två aktiveringar: exakt en ska lyckas och endast en säsong ska vara aktiv.
- Testa båda låsordningarna för publicering kontra aktivering: om publicering får låset först ska omgången finnas i utgående snapshot; om aktivering får låset först ska ett gammalt speldatum avvisas utan sparade resultat. Kontrollera att ett årskorrekt nytt anrop hamnar i nya säsongen.
- Kontrollera verklig GameBook-bild → OpenAI → granskning → publicering, samt befintlig Realtime/push/PWA med verkliga klienter. Undvik produktionsprenumerationer och produktionspush i testprojektet.
- Jämför fryst 2026-ställning och champions igen i staging, och granska manuellt ett eventuellt olöst toppläge med exakt lika poäng och handicap innan officiell champion fastställs.

När detta är godkänt lämnas ett separat produktionsförslag. Inget i denna QA-komplettering godkänner merge, produktionsinstallation, skapande av 2027 i produktion eller säsongsaktivering där. 2026 har inte avslutats i produktion.

# CBO PROJECT STATUS — FELSÄKERT LÄGE

**Datum:** 2026-09-11  
**Repository:** `urbanzakrison/CBO`  
**Branch:** `main`  
**Produktion:** GitHub Pages, CBO  
**Aktuell main vid dokumentation:** `315d477fcd228a222ec96fb46e3f5c21dea063bf`

## 1. Syfte med felsäkert läge

Projektet går nu in i ett **felsäkert utvecklingsläge**. Målet är att skydda verifierad produktion mot regressioner efter att ett isolerat testkonto fick ett auth-problem och en första felsökningsåtgärd felaktigt ändrade det gemensamma frontend-loginflödet.

Felsäkert läge betyder:

1. Aktuell `main` ska alltid läsas innan någon kodändring.
2. En ändring får endast beröra den funktion som faktiskt har ett verifierat fel eller ett uttryckligt nytt krav.
3. Stabil auth, push, GameBook, statistik, leaderboard, admin, Klubbhuset och CBO-affärslogik får inte ändras som bieffekt.
4. Före databas/RPC-felsökning kontrolleras faktisk funktion och signatur i `pg_proc`.
5. Före frontendändring jämförs den aktuella filen mot senast känd fungerande implementation för just den berörda funktionen.
6. Efter varje ändring görs ett minimalt riktat test. Verklig användare/produktion används när det är relevant.
7. Ingen äldre `index.html` får läggas ovanpå aktuell live-version.
8. Användaren ska inte manuellt klippa in kodsnuttar i `index.html`; frontendändringar ska göras från aktuell live-fil och levereras/committas som komplett kontrollerad ändring.
9. Credentials, service-role, VAPID private key och OpenAI key får aldrig exponeras i frontend, dokumentation eller chatt.
10. Om rotorsaken inte är bevisad ska den dokumenteras som hypotes, inte som faktum.
11. Om en ändring riskerar fungerande arkitektur: stoppa och isolera problemet först.

## 2. Senast verifierade stabila bas

CBO MASTER 4.6.5.3 från 2026-09-09 är fortsatt den dokumenterade VERIFIED funktionsbasen för den ordinarie CBO-appen. Den omfattar bland annat:

- Supabase Auth med Golf-ID + personlig CBO-kod
- server-side medlems- och adminverifiering
- leaderboard, historiska omgångar och statistik
- GameBook-import + OpenAI Edge Function
- admin/publicering, duplicate protection och gästlogik
- winner reactions
- push/PWA och WhatsApp
- historiska champions
- aktivitet/status och mobilnavigation
- Klubbhuset: text, bilder, reactions, Realtime, push och unread
- persistent `Kansliet informerar`
- Home-unread och gemensam `Senaste aktivitet`
- Admin → Lägg till medlem och TEST-medlem

Den tidigare 4.6.5.3-committen `19489934f6056a5b26fa144c8cbef258baf09e29` är historisk verifierad baseline. Fortsatt arbete ska dock **inte** återställa hela repot dit; aktuell `main` innehåller senare avsiktlig utveckling. Vid regression ska endast den berörda funktionen jämföras/återställas.

## 3. CBO-affärslogik — låst

- CBO-runda = 9 hål.
- Minst fyra CBO-medlemmar krävs för CBO-poäng/statistik; gäster räknas inte mot fyragränsen.
- CBO-etta 4 p, CBO-tvåa 3 p, CBO-trea 2 p, övriga deltagande medlemmar 1 p.
- Gäster 0 p och tar inte CBO-placeringar.
- Tie-break i omgång: lägre playing handicap/SHCP.
- Tie-break i Totalen: lägre aktuellt handicap.
- Leaderboard: Totalen → Närvaro → Netto → Brutto → Effektivitet → Topp 8.
- `Peter Timar` är normaliserad stavning.

## 4. On Tour — nu implementerat separat från CBO

On Tour är inte längre bara backlog. Det är en separat produktdel för golfresor/tävlingar som **aldrig får påverka** ordinarie CBO-poäng, närvaro, netto/brutto-statistik, Topp 8 eller leaderboard.

Datamodell:

- `cbo_tour_events`
- `cbo_tour_rounds`
- `cbo_tour_results`
- `cbo_tour_side_contests`

Principer:

- event → rounds → results
- samma datum kan ha flera rundor; identitet bygger på event + round_no
- gäster/icke-CBO-spelare kan finnas i resultat med nullable `player_id`
- historiskt HCP är visat playing handicap från källan
- okända värden = `null`; par får inte gissas
- primary metric följer GameBooks vänstra tävlingsform
- stroke: lägre vinner; stableford: högre vinner
- deterministiskt duplicate protection
- summary-bild skapar aldrig resultat-rader

Historisk On Tour QA är genomförd med 15 verifierade eventvinnare och utan kända dubletter i den genomförda auditten.

Produktionens `parse-gamebook-tour` v3 klassificerar summary/results/mixed/unknown och har server-side safety gate.

Adminflödet för framtida On Tour-event är implementerat i ordinarie Admin:

- destination CBO / On Tour
- **Nytt event** är default
- befintligt event är sekundär väg för nästa runda/komplettering
- rundutkast
- flera GameBook-bilder
- parser + preview/merge
- metadata-konflikter måste lösas före publicering
- duplicate check + publicering
- nästa runda i samma event

On Tour finns i huvudnavigationen och använder `on-tour.html` som medlemssida.

## 5. Senare produktionsfixar som ska bevaras

Efter 4.6.5.3 har följande avsiktliga ändringar lagts till och ska inte tappas:

- On Tour datamodell, historik, parser, adminimport och medlemssida.
- On Tour i huvudnavigationen.
- Statistik/Omgångar laddar nu data direkt vid första navigering till fliken, utan att användaren först måste byta år.
- Verifierad Golf-ID-loginfrontend återställd exakt efter ett misslyckat aliasförsök.

## 6. Auth — särskilt skyddsområde

Ordinarie login är återställd till verifierad modell:

- Golf-ID-fältet är numeriskt.
- Golf-ID normaliseras till 9 siffror.
- auth-email byggs server-/klientlogiskt som `<9 siffror>@cbo.local`.
- personlig CBO-kod används som Supabase Auth password.
- efter login verifieras medlemskopplingen via `cbo_current_player()`.

**Rör inte `auth-client.js` eller login-UI för att lösa ett enskilt medlemsproblem.**

### Gunilla testprofil — isolerat authproblem

Ett testkonto hade fungerande login och slutade därefter acceptera sin kod. Undersökningen visade:

- medlemmen och credentialkopplingen finns kvar
- auth user finns kvar och är confirmed
- senaste lyckade login skedde före en senare ändring av `auth.users.updated_at`
- `player_credentials.updated_at` ändrades inte samtidigt
- GitHub-loginflödet ändrades inte vid den tidpunkten
- audit-loggen gav ingen post som bevisar exakt operation

Därför är exakt auth-mutation **inte bevisad**. Ett passwordbyte/reset är en rimlig hypotes men får inte beskrivas som säker rotorsak.

En tidigare felsökningsändring som gjorde Golf-ID-fältet alfanumeriskt/aliasbaserat var fel väg och är helt återställd. Ordinarie användares login verifierades efter återställningen.

### Credentialarkitektur — viktig distinktion

Det finns två mekanismer som inte får blandas ihop:

1. Supabase Auth password — det som aktuell `auth-client.js` faktiskt använder vid login.
2. `code_hash` / `cbo_set_player_code` / `cbo_verify_credentials` — separat/legacy credentialmekanism.

Att bara uppdatera `code_hash` gör **inte** att aktuell Supabase Auth-login accepterar koden.

Adminfunktionen `admin-cbo-code` sätter/genererar Supabase Auth password för vald medlem server-side. Den får aldrig ersättas med frontendhantering av lösenord/service-role.

## 7. Självservice för CBO-kod — nytt, ännu inte VERIFIED som komplett produktflöde

På aktuell `main` finns nu två nya filer/komponenter för medlemssjälvservice:

- server-side Edge Function-källa för `member-cbo-code`
- `min-profil.html`

Syftet är att en **redan autentiserad** medlem ska kunna välja en ny egen CBO-kod utan admin och utan att kunna ändra någon annan medlems kod.

Säkerhetsprincip:

- medlem identifieras från sin session/JWT
- endast den egna auth-usern får ändras
- ingen service-role i frontend
- kod får inte loggas eller dokumenteras

**Status:** backend/sidan är tillagd, men hela produktflödet ska betraktas som `PENDING VERIFICATION`, inte VERIFIED. Ingen ingång i ordinarie `index.html` ska läggas till förrän funktionen testats isolerat med testmedlem och vanlig login efter kodbyte verifierats.

## 8. Exakt felsäkert nästa steg

Gör inte mer generell authutveckling nu.

Nästa testsekvens:

1. Använd Admin → Ny CBO-kod för TEST-medlemmen om fungerande kod saknas.
2. Verifiera vanlig login med Golf-ID + den nya koden.
3. Med aktiv session, öppna/testa `min-profil.html` och välj en ny kod.
4. Logga ut helt.
5. Verifiera vanlig login med den självvalda nya koden.
6. Verifiera att en annan ordinarie medlem fortfarande kan logga in oförändrat.
7. Först efter dessa tester kan självservice markeras VERIFIED och en liten länk/ingång läggas i ordinarie app.

Om steg 2 misslyckas: felsök endast Admin → Ny CBO-kod / Supabase Auth för testmedlemmen. Ändra inte frontend-login.

Om steg 3–5 misslyckas: felsök endast `member-cbo-code` / `min-profil.html`. Ändra inte ordinarie login.

## 9. GitHub-läge vid denna dokumentation

Aktuell `main` före detta dokumentationscommit var:

`315d477fcd228a222ec96fb46e3f5c21dea063bf` — `Add member CBO code self-service page`

När denna dokumentationsfil committas kommer `main` naturligtvis få en senare SHA. Vid fortsatt arbete ska alltid aktuell HEAD hämtas först.

## 10. Instruktion till ny utvecklingschatt

Läs denna fil först och behandla den som säkerhets-/statusöverlämning. Läs därefter befintlig CBO MASTER 4.6.5.3 / PROJECT RULES om de finns i projektkontexten.

Utgå från att allt markerat VERIFIED fungerar. Felsök inte om det utan ett nytt konkret symptom.

Det aktuella öppna spåret är **isolerad verifiering av medlemssjälvservice för CBO-kod**. Ändra inte `auth-client.js`, login-UI eller annan stabil arkitektur för detta.

On Tour är implementerat och separat från CBO. Fortsatt On Tour-utveckling får aldrig påverka ordinarie CBO-data.

Ett steg åt gången. Läs live `main` före varje ändring. Testa direkt. Dokumentera hypoteser som hypoteser och verifierade fakta som VERIFIED.
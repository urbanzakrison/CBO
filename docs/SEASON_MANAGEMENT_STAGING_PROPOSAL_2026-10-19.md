# CBO Season Management v1 — konkret stagingförslag och beslutspunkt


> Uppdatering: kostnadsfri GitHub Actions-/lokal Supabase-QA finns nu. Se `SEASON_MANAGEMENT_FREE_QA_2026-10-19.md`. Tidigare uppgifter om att betald staging krävs gäller inte längre kärnverifieringen; äldre miljöresultat nedan är historik.
Datum: 19 oktober 2026. Underlag: PR #1, head `4bdbacaca10558104cd1f1c87d6ee2fcaf5eb1d5`.

**Rekommendation: NO-GO för produktionsinstallation. Stopp före skapande av ny testmiljö enligt mandatets punkt 9.**

Detta är ett förslag för godkännande, inte en beställning eller genomförd installation. Inget nytt projekt har skapats, inget abonnemang ändrats och inga produktionstester eller produktionsändringar har gjorts i denna verifieringsomgång.

## 1. Inventering av faktisk åtkomst

| Resurs | Verifierat | Bedömning |
| --- | --- | --- |
| `lwymnhmwrinzuvmoqqif` / CBO | ACTIVE_HEALTHY, eu-west-1, PostgreSQL 17, befintlig produktion | Får inte användas som staging |
| `ipckaiidmofshqkiyecg` / ff65 | ACTIVE_HEALTHY, eu-west-1, annat känt applikationsprojekt | Inte en identifierad tom testmiljö; läses eller ändras inte för detta uppdrag |
| Tillgängliga organisationer | En: `pddkvmutbsymuffkvysk`, plan Free | Ingen separat QA-organisation tillgänglig |
| CBO branchlista | Endast `main`, markerad `is_default=true`, med produktionsprojektets project_ref | Detta är inte en separat stagingdatabas och ska inte användas som sådan |
| GitHub PR #1 | Open, draft, inte mergad; main fortfarande `c7952ce…` | Samma implementation och QA-head som tidigare |

Ingen lämplig befintlig testmiljö har identifierats inom den tillgängliga åtkomsten. Det finns därför inget skäl att inventera användardata i ff65 eller göra förändringar där. Inget nytt försök att skapa branch/projekt gjordes i denna omgång.

## 2. Kostnadsförutsättningar — kontrollerade mot officiella källor

Kontrollerat 19 oktober 2026:

- Free tillåter två aktiva gratisprojekt. Gränsen gäller över organisationer där användaren är Owner/Administrator. Båda synliga projektplatserna är redan upptagna; en ny Free-organisation löser alltså inte kvoten.
- Billing ligger på organisationsnivå. Free- och Pro-projekt kan inte blandas i samma organisation.
- Pro: från **25 USD/månad per organisation**, med **10 USD/månad i compute credits**.
- Micro: **0,01344 USD/timme**, ungefär 10 USD för en månad. Endast faktiskt körda timmar debiteras, med påbörjad timme avrundad uppåt. Compute är inte skyddad av Spend Cap.

Källor:

- https://supabase.com/pricing
- https://supabase.com/docs/guides/platform/billing-on-supabase
- https://supabase.com/docs/guides/platform/billing-faq
- https://supabase.com/docs/guides/platform/manage-your-usage/compute

Detta är offentliga listpriser och ett budgetunderlag, **inte ett kontospecifikt kostnadsgodkännande eller en offert**. Leverantörens get_cost-verktyg kräver att användaren anger/bekräftar organisationens ID innan det anropas. Ingen organisation har valts på användarens vägnar för ett betalt skapande. Exakt kostnad och faktureringsperiod ska kontrolleras mot den valda organisationen före skapandet. Inga kostnadsbekräftelser har registrerats.

### Föreslaget alternativ A: separat QA-organisation på Pro

En ny, uttryckligen godkänd separat organisation, exempelvis `CBO QA`, med ett enda tillfälligt Micro-projekt. CBO och ff65 ligger kvar oförändrade på befintlig Free-organisation.

**Förväntad Supabase-kostnad:** cirka **25 USD för en ordinarie månadsperiod**, exklusive eventuell moms/valutaväxling och externa tjänster. Ett QA-fönster på 72 timmar ger cirka 0,97 USD i Micro-compute, vilket ryms i organisationens 10 USD compute credits om dessa är tillgängliga. Räkna konservativt med planavgiften för en hel period; ingen korttidsrabatt eller automatisk återbetalning utlovas. En kvarlämnad Pro-organisation kan fortsätta kosta även efter att testprojektet tagits bort.

**Budget att godkänna:** planavgift upp till 25 USD för en faktureringsperiod, plus eventuell skatt; inga betalda tillägg eller nya externa API-kostnader utan nytt godkännande. Bekräfta listpris, tillgängliga credits, skatt och eventuell proportionering före beställning. Om villkoren inte motsvarar budgeten stoppas skapandet.

Detta alternativ ändrar inte abonnemanget för produktionsorganisationen. Verktygen som finns här saknar create-organization; den separata organisationen behöver tillhandahållas genom godkänt administrativt flöde och dess ID lämnas före get_cost och projektbeställning.

### Alternativ B: tillhandahållet befintligt testprojekt

Om användaren har ett testprojekt som inte syns via nuvarande anslutning kan dess projekt-ID/organisation och avsedda användning lämnas. Då kontrolleras åtkomst, tabeller/row counts, Auth/Storage/integrationer och att det inte används av andra system före någon skrivning. Ingen värdefull data rensas. Kostnaden fastställs mot det projektets organisation; 0 USD i extra grundkostnad kan inte antas utan denna kontroll.

**Inte föreslaget:** pausa/radera CBO eller ff65 för att frigöra en gratisplats, flytta produktionsprojekt eller uppgradera befintlig produktionsorganisation som en bieffekt. Det kräver annan, separat beställning.

## 3. Minsta projektkonfiguration

| Inställning | Föreslaget värde |
| --- | --- |
| Projektnamn | `cbo-season-qa-20261019` |
| Organisation | Separat, av användaren angiven/godkänd QA-organisation |
| Region | `eu-west-1`, samma region som produktion |
| Compute | Micro, ingen autoskalning eller extra compute |
| Databas | PostgreSQL 17 om tillgängligt; logga faktisk patchversion och kontrollera SQL-kompatibilitet |
| Livslängd | Initialt 72 timmar; stäng efter godkänd QA eller begär nytt beslut om förlängning |
| Frontend | Separat test-origin/preview; ingen publicering till GitHub Pages, ingen produktionskonfig i testpaketet |
| Auth | Två verkliga separata testkonton: syntetisk admin och medlem; därutöver okänt/utloggat testfall |
| Kapacitet | Litet syntetiskt basunderlag plus den redan avgränsade historikkopian; inga nya fullständiga produktionskopior |
| Tillval | Ingen custom domain, PITR, IPv4-tillägg, log drain, SMTP-leverans eller andra betalade tillägg |
| Kostnadsskydd | Spend Cap kvar på; kontrollera compute separat eftersom den inte täcks av cap |

För anslutning används stagingprojektets egna uppgifter. Testköraren måste kontrollera exakt tillåtet staging-project_ref, vägra CBO/ff65 och vägra oväntat hostnamn innan SQL, Auth- eller API-skrivning. Databasanslutning används bara server-side, över leverantörens stödda direkta/sessionbaserade anslutning, utan IPv4-tillägg om befintlig anslutning fungerar. Hemligheter ligger i tillfällig säker miljö, aldrig i repo, rapport, frontend eller chatt. Databaslösenord genereras vid skapandet och återges inte i leveransen.

## 4. Schema och beroenden — inga förändringar i apparkitekturen

Supabase tillhandahåller redan `auth`, rollerna och API-tjänsterna. **Kör inte `tests/fixtures/schema.sql` direkt i ett riktigt Supabase-projekt**: den filen återskapar plattformens delar för PGlite och är inte en stagingbootstrap.

Förbered och granska en stagingbootstrap för relevanta `public`-objekt utifrån de redan inspekterade produktionsdefinitionerna:

1. `players`, `player_credentials`, `seasons`, `season_players`, `rounds`, `round_results`, med faktiska typer, PK/FK, index, defaults och status-CHECK inklusive FÖRBEREDD.
2. Faktiska RLS-policyer och tillhörande läs-/adminhelpers, inklusive `cbo_current_player`, `is_cbo_member`, `is_cbo_admin`. Återskapa relevant befintlig logik, inte en förenklad ersättningsmodell. Eventuella beroendeskillnader rapporteras som miljöfel.
3. Inspekterade `cbo_live_leaderboard_data`, `cbo_season_stats`, `cbo_round_duplicate_check` och ursprunglig `cbo_publish_round`. Behörigheter/EXECUTE måste följa produktionsinventeringen; pg_get_functiondef ensam innehåller inte ACL.
4. Verifiera baslinjen innan granskad `22_season_management_v1.sql` körs i staging. Kör Security Advisors efter installationen och dokumentera fynd per nytt objekt. Historikens baslinje tas både före och efter installation/skifte.
5. Vid regression av Klubbhus/Realtime/push används separat granskade beroenden, privata testbuckets och testprenumerationer. Saknas dessa delar markeras testet BLOCKED, inte PASS.

CBO on Tour-filer och funktioner lämnas orörda; inget sådant schema skapas eller byggs om som del av säsongstestet. Ingen ny appfunktion implementeras.

## 5. Testidentiteter och dataseparering

- Skapa två syntetiska Supabase Auth-användare genom stagingprojektets behöriga serveradministration. Tilldela deras nya Auth-ID:n till syntetiska `players`/`player_credentials` enligt befintlig CBO-modell. Lagra aldrig riktiga medlemskonton eller deras credentials i staging.
- Använd testnamn, exempelvis `QA Admin` och `QA Member`, och två tydligt syntetiska Golf-ID i befintligt format. Koder/lösenord genereras slumpmässigt och dokumenteras inte. Återanvänd befintlig kodfunktion om den behövs; ersätt inte credentialarkitekturen med en testgenväg.
- Ytterligare två eller fler syntetiska medlemmar behövs för en officiell fyrmannarunda; en syntetisk gäst ska ha 0 p och inte ta placering.
- Verklig inloggning görs via befintlig auth-client/Supabase Auth i två separata klientkontexter. En lokal sessionsadapter räcker inte som stagingbevis.
- Den redan avgränsade historikkopian används för integritetstest med syntetiska Auth-kopplingar. Riktiga Auth-ID:n, Golf-ID, CBO-koder, privat Storage och pushprenumerationer importeras inte. Skapa inga kopplingar från testhändelser till produktion.
- Separata stagingnycklar för OpenAI och VAPID krävs om dessa flöden ska verifieras. OpenAI-anrop som kan kosta ingår inte i den föreslagna Supabase-budgeten. Saknas separat godkänd nyckel/budget förblir bildtolkning NOT RUN. Produktionsnycklar får inte användas som reserv.

## 6. Körordning efter miljögodkännande

1. Kontrollera project_ref/host och tomt, dedikerat användningsområde. Logga PG-version, migreringar, constraints, RLS, pg_proc-signaturer och ACL.
2. Installera basberoenden/testidentiteter; verifiera inloggning och baseline. Importera den säkra historikkopian separat från credentials.
3. Installera release-SQL i staging. Kör Advisors och autentiserade API-tester för admin, medlem, okänd och utloggad klient. Kontrollera RLS och nya RPC-privilegier direkt.
4. Använd minst två separata PostgreSQL-anslutningar och logga olika `pg_backend_pid()`. Samordna med explicita transaktionsbarriärer/lås, inte bara timing eller upprepade anrop i en anslutning. Testa två create, två activate och båda ordningarna publish/activate. Kontrollera slutstatus, snapshot, radantal och felår/dubbletter efter varje fall. Återställ endast syntetiska stagingdata mellan scenarier.
5. Kör mobil-E2E med riktiga testinloggningar: förbered 2027, 2026 fortsatt aktiv, aktivera i staging, tom ställning, omgång 1, GameBook-granskning, gäst-/poäng-/dubblettlogik, historik och navigation.
6. Kontrollera de sex kategorierna, samtliga historiska rader, champions och statistik före/efter. Ändra HCP endast i staging och bekräfta att fryst historik står fast.
7. Verifiera OpenAI/Realtime/push/PWA i den utsträckning separata godkända testtjänster/klienter finns. Kör inte produktionstester för att fylla luckor.
8. Sammanställ per test: PASS, FAIL, BLOCKED eller NOT RUN, med miljö och evidens. Endast när obligatoriska spärrar är lösta kan en ny GO/NO-GO-rekommendation lämnas. Ingen merge följer automatiskt.

## 7. Borttagning och kostnadsstopp

Vid godkännande av stagingförslaget ska även följande städning för just den nya QA-resursen ingå i mandatet:

- Spara testloggar, miljömanifest, Advisor-fynd och avidentifierade evidenshashar i PR; inga hemligheter eller råa credentials.
- Ta bort testpushprenumerationer från testklienter, avregistrera service worker/test-PWA, radera tillfälliga Auth-sessioner och säkert lokalt hemlighetsmaterial.
- Radera endast det verifierade nya stagingprojektet efter QA. Kontrollera project_ref igen innan borttagning; produktion och ff65 får aldrig vara mål.
- Återkalla eventuella separata OpenAI-testnycklar. Ta bort tillfällig preview/test-origin.
- Kontrollera uttryckligen att projektet är borttaget och compute-debiteringen stoppad. **Borttagning av projektet avslutar inte automatiskt Pro-organisationens planavgift.** Avsluta/nedgradera endast den separat skapade QA-organisationens abonnemang enligt godkända villkor och verifiera fakturastatus.
- Om QA inte kan slutföras inom 72 timmar: begär ett nytt beslut om förlängning eller genomför godkänd städning. Ingen osynlig pågående kostnad accepteras som standard.

## 8. Exakt beslut som krävs

Ange ett av följande:

**A.** Godkänn separat QA-organisation på Pro med ett enda Micro-projekt, ovanstående budget och 72-timmarsfönster samt städning inklusive att avsluta QA-abonnemanget. Tillhandahåll organisationens ID. Därefter hämtas kontospecifik kostnad och eventuellt nödvändig leverantörsbekräftelse innan projekt skapas. Detta godkänner inte ändringar i befintlig produktionsorganisation.

**B.** Tillhandahåll ett befintligt separat testprojekts ID och bekräfta att det är avsett för denna QA. Det inventeras först för värdefulla data och externa beroenden. Ingen data rensas för att göra plats.

Tills något av detta finns är staging och slutacceptans blockerade. Tidigare lokala testresultat gäller fortfarande för sin dokumenterade miljö, men har inte blivit Supabase-stagingtester. Rekommendationen för produktion är fortsatt **NO-GO**.

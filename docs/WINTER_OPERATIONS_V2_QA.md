# Winter Operations v2 — QA-protokoll

21 oktober 2026. Baseline main `4a96b7a5c70002f4dd1e99a7c369c3d8556e6d38`.
Ingen produktionsintegration, secret, konto, backup/export eller databasändring har utförts.

## Lokalt

- Health + heartbeat: 22/22 automatiska offline-tester PASS (inklusive v1-rapportkontrakt
  och avstängd/aktiverad men ofullständigt konfigurerad CLI).
- Befintliga Season Management-grundtester: 9/9 PASS lokalt.
- Manifest- och workflowgränstest PASS: ändrad, saknad, extra fil och osäkert filnamn
  upptäcks; DR-workflow är PR-only utan produktionssecret, deploy eller backup-artifact.
- GnuPG-rundtur kunde inte genomföras lokalt: gpg-agent startar inte i denna körmiljö.
  Testet markeras inte PASS eller hoppas över; samma obligatoriska test körs i isolerad
  standard GitHub-runner. Inga behörigheter ändras för att kringgå lokal begränsning.
- PostgreSQL/Docker finns inte lokalt. Riktig dump/restore + Auth/Storage körs därför
  i godkänd kostnadsfri ephemeral GitHub Actions-miljö, aldrig mot hosted produktion.
- Read-only liveprov 09:50:11 UTC: frontend PASS/200/5 685 ms, databas PASS/200/4 950 ms,
  ett försök vardera. Bevisar inte återställning eller oberoende larm.
- Källbackupens bytes, SHA-256 och 16/222/1 525 kontrollerades igen utan att dess
  data skickades till publik CI. Ingen senare backup identifierades vid lagringssökningen.

## CI

Referenskandidat `87e00fbfcf331fd06b6ce87ae43bd069f7e390ec`, samtliga tre workflows
completed/success. PR: https://github.com/urbanzakrison/CBO/pull/3 (utkast, ej mergad).

| Körning | Verifierat resultat |
| --- | --- |
| [39580923993](https://github.com/urbanzakrison/CBO/actions/runs/39580923993) — Winter v2 recovery | 24/24 offline-tester PASS inklusive faktisk GnuPG-rundtur, fel nyckel, korrupt paket och två krypterade kopior; verklig lokal Supabase-återställning PASS 09:59:01 UTC |
| [39580923920](https://github.com/urbanzakrison/CBO/actions/runs/39580923920) — Winter Health | Health/heartbeat 22/22 PASS; riktigt read-only frontend-/DB-prov och kompatibilitetsprov av v1-rapport PASS; ingen extern heartbeat skickad |
| [39580923949](https://github.com/urbanzakrison/CBO/actions/runs/39580923949) — Season QA | Grundtester 9/9, PostgreSQL-samtidighet 8/8, verklig lokal Auth/RLS, mobil/GameBook-granskning och lokala Security Advisors PASS |

Recovery-loggen verifierar: verklig pg_dump/pg_restore; fem återställda Auth-konton med
nya lösenordsinloggningar; medlems-/credential-hashrelationer; exakta 2026-rader,
snapshot/champion och sexkategoripayload; 2027 fortsatt aktiv; funktioner, index,
public-RLS och faktiska objektgrants lika före/efter; meddelanden/reactions/bildreferenser;
återläst privat PNG med rätt checksumma; medlem tillåten, anonym och okänd nekade;
medlem får inte skapa säsong eller läsa credentialtabellen. Inga produktionsdata används.

Logggranskning av recovery-jobb `119158035945`: inga omaskerade JWT-/secret-key- eller
private-key-markörer och inga testkontoadresser hittades. Loggen innehåller sanerad
PASS-sammanfattning, inte dumpar, kodhashar, lösenord eller bilder. Stack och privata
temporära testkopior rensades efter provet. Ingen backup-artifact laddades upp.

Efter denna referenskörning läggs bara dokumenterad testhärdning till: privat umask
före stackstart, explicit 0600-kontroll av testkopior och statiskt workflowgränstest.
Slutligt HEAD ska också få egen grön CI; dess exakta SHA/run-ID redovisas i PR-beskrivningen
efter faktisk körning, inte som ett förhandslöfte. Recovery-skriptets beteende ändras inte
av den avslutande dokumentations-/testhärdningen.

Utvecklingsfynd: det första utkastet av heartbeat jämförde `LIVE` med v1:s faktiska
`READ_ONLY_LIVE`. Det korrigerades före produktionsintegration och ett regressionstest
samt kompatibilitetsprov av riktig sanerad v1-rapport lades till. V1-kontrollen ändrades
inte. Inget felaktigt heartbeat skickades; integrationen har aldrig varit aktiverad.

Två misslyckade återställningskörningar behålls som spårbar utvecklingshistorik:
`39579986984` stoppade vid Auth-restore; `39580427831` återställde Auth men stoppade
vid public-restore med behörighetsfel. Testet korrigerades till users före identities
utan triggeravstängning, samt explicit återföring av verkliga objekt-ACL i stället för
plattformsägda default-ACL. Dessa rättigheter jämförs före/efter; ingen superuser- eller
hosted behörighet lades till. Referenskörningen ovan verifierar den korrigerade vägen.

## Ändringsscope och rekommendation

Exakta ändrade filer:

- `.github/workflows/cbo-winter-health.yml`
- `.github/workflows/cbo-winter-v2-qa.yml`
- `ops/winter-health.test.mjs`
- `ops/winter-heartbeat.mjs`
- `ops/winter-heartbeat.test.mjs`
- `ops/dr-bundle.mjs`
- `ops/dr-bundle.test.mjs`
- `ops/dr-local-qa.mjs`
- `docs/WINTER_OPERATIONS_V2.md`
- `docs/WINTER_OPERATIONS_V2_QA.md`

Produktionsdatabasändringar: INGA. Frontend-/Edge-/SQL-/Auth-/On Tour-filer: INGA.
Inga nya externa konton, produktionscredentials, integrationer, privata dataexporter,
betalda resurser eller merge. Supabase plan bekräftad Free/tier_free, ACTIVE_HEALTHY.
Main är fortsatt den angivna v1-baselinen. Ändringar finns bara i utvecklingsbranchen.

GO för granskning av utvecklingsleveransen när slutligt HEAD också är grönt.
NO-GO för FULLY VERIFIED oberoende avisering eller komplett produktions-DR: ägarens
godkännanden och verkliga privata backup-/återställnings-/mottagningsprov återstår.

## Inte verifierat i denna leverans

Verkligt Healthchecks-konto/ping/DOWN/leverans/mottagning; v2 i produktion; första
v1-schedule (väntas 22 oktober); full aktuell produktionsbackup; två verkliga privata
offsite-kopior; komplett ny hosted återställning; MFA/SSO/Vault/Edge-secrets;
verklig OpenAI-tolkning, fleranvändar-Realtime, OS-push och installerad PWA efter DR.

De föreslagna testerna använder syntetiska data och bevisar inte att de inventerade
produktionsluckorna är stängda. GO/NO-GO och nödvändiga beslut finns i designrapporten.

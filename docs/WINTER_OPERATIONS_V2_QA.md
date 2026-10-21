# Winter Operations v2 — QA-protokoll

21 oktober 2026. Baseline main `4a96b7a5c70002f4dd1e99a7c369c3d8556e6d38`.
Ingen produktionsintegration, secret, konto, backup/export eller databasändring har utförts.

## Lokalt

- Health + heartbeat: 20/20 automatiska offline-tester PASS.
- Manifesttest PASS: ändrad, saknad, extra fil och osäkert filnamn upptäcks.
- GnuPG-rundtur kunde inte genomföras lokalt: gpg-agent startar inte i denna körmiljö.
  Testet markeras inte PASS eller hoppas över; samma obligatoriska test körs i isolerad
  standard GitHub-runner. Inga behörigheter ändras för att kringgå lokal begränsning.
- PostgreSQL/Docker finns inte lokalt. Riktig dump/restore + Auth/Storage körs därför
  i godkänd kostnadsfri ephemeral GitHub Actions-miljö, aldrig mot hosted produktion.

## CI

Resultat, run-ID och kandidat-SHA kompletteras efter faktisk körning. Inga framtida
tester påstås vara godkända i förväg. `Winter v2 isolated recovery QA` måste bli grön
på aktuell PR-HEAD; befintlig Winter Health och Season QA ska också granskas.

## Inte verifierat i denna leverans

Verkligt Healthchecks-konto/ping/DOWN/leverans/mottagning; v2 i produktion; första
v1-schedule (väntas 22 oktober); full aktuell produktionsbackup; två verkliga privata
offsite-kopior; komplett ny hosted återställning; MFA/SSO/Vault/Edge-secrets;
verklig OpenAI-tolkning, fleranvändar-Realtime, OS-push och installerad PWA efter DR.

De föreslagna testerna använder syntetiska data och bevisar inte att de inventerade
produktionsluckorna är stängda. GO/NO-GO och nödvändiga beslut finns i designrapporten.

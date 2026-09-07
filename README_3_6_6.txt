CBO 3.6.6 – Clean Leaderboard

Ändring:
- De synliga verifieringsraderna för HCP/SHCP är borttagna.
- Tie-break-logiken är oförändrad och fortsätter i bakgrunden:
  1. Tävlingspoäng
  2. Senast kända SHCP från GameBook/CBO
  3. HCP-index som fallback
  4. Namn som teknisk sista sortering

Ingen ny SQL krävs jämfört med 3.6.5.
Kopiera fungerande config.js till mappen och öppna index.html.

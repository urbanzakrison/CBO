CBO 3.6.1 – HCP tie-break i Totalen

Ändring:
- Live-RPC returnerar current_hcp från players om kolumnen finns.
- Totalen sorteras:
  1) Tävlingspoäng fallande
  2) Aktuellt HCP stigande
  3) Namn alfabetiskt som teknisk sista sortering

Om current_hcp saknas på en spelare hamnar den spelaren sist bland spelare med samma poäng.

Gör:
1. Kör den uppdaterade 04_live_leaderboard_rpc.sql i Supabase SQL Editor.
2. Kopiera fungerande config.js till mappen.
3. Öppna index.html och kontrollera Totalen.

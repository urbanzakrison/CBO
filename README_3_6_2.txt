CBO 3.6.2 – Senast kända spelhandicap

Modell:
- Varje RoundResult kan lagra playing_hcp från GameBook-bilden.
- Senast kända playing_hcp för varje spelare hämtas automatiskt från senaste CBO-resultatet där värdet finns.
- Totalen sorteras:
  1. Tävlingspoäng fallande
  2. Senast kända spelhandicap stigande
  3. Namn alfabetiskt endast som teknisk sista sortering

Detta är medvetet en pragmatisk modell: handicap kan ha ändrats utanför CBO sedan senaste CBO-rundan.

Gör:
1. Kör 05_latest_playing_hcp.sql i Supabase SQL Editor.
2. Kör därefter den uppdaterade 04_live_leaderboard_rpc.sql.
3. Kopiera fungerande config.js till mappen.
4. Öppna index.html.

Obs: befintliga historiska round_results saknar playing_hcp tills vi fyller dem via kommande GameBook-import eller manuellt.

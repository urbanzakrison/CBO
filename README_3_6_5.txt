CBO 3.6.5 – HCP fallback

Ny tie-break-modell i Totalen:
1. Tävlingspoäng, högst först
2. Senast kända spelhandicap (playing_hcp) från senaste CBO/GameBook-runda
3. Om playing_hcp saknas: current_hcp_index från Golf-ID-underlaget
4. Namn som teknisk sista sortering

Filer:
- 06_current_hcp_index.sql: lägger till current_hcp_index och seedar alla 14 spelare.
- 04_live_leaderboard_rpc.sql: uppdaterad live-RPC med fallbacklogik.
- 05_latest_playing_hcp.sql: tidigare migration för playing_hcp på round_results.

Körordning:
1. Kör 06_current_hcp_index.sql
2. Kör uppdaterade 04_live_leaderboard_rpc.sql
3. Kopiera fungerande config.js till denna mapp
4. Öppna index.html och kontrollera Totalen

I verifieringsvyn visas för lika poäng om värdet kommer från:
- Senast kända SHCP
- HCP-index (fallback)

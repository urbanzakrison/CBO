CBO 3.7 – Live Omgångar

Nytt:
- 2026 Omgångar hämtas från Supabase, inte från statisk prototypdata.
- Admin kan publicera en ny omgång via server-RPC.
- Servern validerar adminrollen.
- Servern räknar official status (>=4 spelare).
- Servern placerar på netto, därefter lägst SHCP.
- Servern sätter CBO-poäng 4/3/2/1.
- playing_hcp sparas på varje round_result.
- Efter publicering hämtas live-data om och leaderboarden räknas om.

Kör:
1. Kör uppdaterade 04_live_leaderboard_rpc.sql.
2. Kör 07_live_round_write_rpc.sql.
3. Kopiera fungerande config.js till mappen.
4. Öppna index.html och logga in som Urban/admin.
5. Testa Admin -> Ny omgång -> Granska -> Publicera.

Rekommendation:
Testa INTE med ett skarpt nytt omgångsnummer förrän ni har en riktig CBO-omgång att registrera.

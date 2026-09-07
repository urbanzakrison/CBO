CBO 3.6.3 – rätt datumfält för SHCP

Verifierad rounds-struktur:
- id
- season_id
- round_no
- played_on
- course
- par9
- official
- recap
- created_by
- created_at

Ändring:
- senaste spelhandicap sorteras nu på rounds.played_on
- round_no används som sekundär sortering
- live-RPC använder round_no som omgångsnummer

Gör:
1. Kör 05_latest_playing_hcp.sql om den inte redan är körd.
2. Kör den uppdaterade 04_live_leaderboard_rpc.sql.
3. Kopiera fungerande config.js till denna mapp.
4. Öppna index.html och kontrollera Leaderboard.

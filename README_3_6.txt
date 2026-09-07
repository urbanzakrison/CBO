CBO 3.6 – Clean Live

2026 leaderboard använder nu EN serverfunktion (RPC) i Supabase.
Ingen 2026-fallback visas om live-hämtningen misslyckas.

Gör:
1. Kör 04_live_leaderboard_rpc.sql i Supabase SQL Editor.
2. Kopiera fungerande config.js från föregående version till denna mapp.
3. Öppna index.html och logga in.
4. Gå till Leaderboard.

Förväntat:
SUPABASE · LIVE · 163 RESULTAT
Johan Fagerholm 53
Martin Burefors 43
Urban Zakrison 29

Om RPC fallerar visas det riktiga serverfelet i leaderboarden.

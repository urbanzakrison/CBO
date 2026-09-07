CBO 4.5 – Live Publish

Bygger på godkända CBO 4.4.
- GameBook AI-import och granskningsflöde kvar.
- Datum/bana/par följer 4.3-fixen.
- Publicera omgången visar en sista bekräftelse.
- Efter bekräftelse anropas Supabase RPC cbo_publish_round.
- Avbryt skriver ingen data.
- Vid lyckad publicering laddas live leaderboard om.

VIKTIGT: använd endast Publicera på en riktig CBO-omgång.

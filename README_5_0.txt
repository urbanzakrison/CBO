CBO 5.0 – Player Experience

Bygger på CBO 4.5 Live Publish och behåller det verifierade flödet:
GameBook-bild -> Supabase Edge Function -> OpenAI -> granskning -> poäng -> cbo_publish_round.

Nytt i 5.0:
- Samlad spelarupplevelse: Hem, Leaderboard, Omgångar, Spelare och Admin.
- Officiell mästarhistorik 2011–2025 i Spelare-vyn.
- PWA-förberedelse: manifest.json och service worker.
- Produktionsstatus i Admin i stället för gammal prototyptext.
- Mobil metadata för iPhone/Android.

Viktigt:
- PWA/service worker aktiveras först när appen ligger på http/https, inte via file://.
- Edge Function parse-gamebook och dess secrets ändras inte av detta paket.
- Testa alltid publicering med bekräftelserutan före skarp användning.

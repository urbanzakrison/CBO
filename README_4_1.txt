CBO 4.1 – riktig AI-tolkning av GameBook-bilder

Detta paket ersätter test-fixtures med riktig serverbaserad bildtolkning.

ARKITEKTUR
Webbläsare -> Supabase Edge Function parse-gamebook -> OpenAI vision -> strukturerad lista:
{name, shcp, net}

Säkerhet:
- OPENAI_API_KEY ligger ENDAST som secret i Supabase Edge Functions.
- Nyckeln får aldrig läggas i config.js eller skickas till webbläsaren.
- Edge Function kräver en giltig Supabase-session och verifierar att användaren är CBO-admin.
- Endast aktiva CBO-spelare accepteras i resultatet.

FILER
supabase/functions/parse-gamebook/index.ts
  Edge Function som tolkar bilden.
index.html
  Anropar Edge Function för varje uppladdad bild, slår ihop spelare och tar bort dubletter.

FÖR ATT AKTIVERA
1. Skapa/deploya Supabase Edge Function med namnet:
   parse-gamebook

2. Lägg OPENAI_API_KEY som Supabase Edge Function-secret.
   Lägg INTE nyckeln i config.js.

3. Kopiera fungerande config.js till CBO 4.1-mappen.

4. Öppna index.html, logga in som Urban/admin och välj en GameBook-bild.

Förväntat:
- Varje bild visar "tolkar..." och därefter antal lästa spelare.
- Flera bilder slås ihop.
- Exakt samma bild återanvänder cache och skapar inte dubletter.
- Granskningslistan är redigerbar innan något publiceras.

Modell:
gpt-5.6-luna används för bildtolkningen för att hålla kostnaden låg.

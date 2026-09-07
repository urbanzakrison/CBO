CBO 3.9.1 – Image Fix

Felet i 3.9 var tekniskt:
GameBook-funktionerna låg felaktigt inuti en <script src="auth-client.js">-tagg.
När en script-tagg har src ignorerar webbläsaren inline-koden i taggen.

Fix:
- auth-client.js laddas i en korrekt stängd extern script-tagg.
- GameBook-funktionerna ligger i ett separat vanligt <script>-block.

Ingen SQL krävs.
Kopiera fungerande config.js till mappen och öppna index.html.
Välj samma GameBook-bild igen.

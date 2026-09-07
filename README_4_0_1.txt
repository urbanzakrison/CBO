CBO 4.0.1 – Duplicate Image Fix

Felet i 4.0:
Testparsern valde fixture efter bildnummer. Om samma GameBook-bild laddades två gånger
tolkades den därför som två olika bilder och gav felaktigt sju unika spelare.

Fix:
- Varje uppladdad bild får ett SHA-256-fingeravtryck i webbläsaren.
- Tolkningsresultatet cacheas per unik bild.
- Samma bild uppladdad igen återanvänder exakt samma spelarrader.
- Spelardubbletter slås därefter ihop på namn.

Förväntat test:
Ladda samma fyrspelarbild två gånger -> fortfarande 4 unika spelare, inte 7.

Ingen ny SQL krävs.
Kopiera fungerande config.js från 4.0.

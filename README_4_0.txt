CBO 4.0 – Multi Image Import

Nytt:
- Datum förväljs till dagens datum men är redigerbart.
- Bana förväljs till Hamra men är redigerbar fritext.
- En omgång kan ha flera GameBook-bilder.
- Knapp: "Lägg till ytterligare GameBook-bild".
- Spelare från flera bilder slås ihop till en enda granskningslista.
- Dubletter tas bort på spelarnamn.
- Granskningsvyn visar namn, SHCP, netto och beräknat brutto.
- "För över till omgången" använder de administrativa datum-/banafälten.
- Inget sparas förrän "Publicera omgången" trycks.

Utvecklingsläge:
De två testbilder som använts i arbetet har fixtures för att verifiera merge-flödet.
Nästa steg är att ersätta fixtures med riktig server/AI-bildtolkning som returnerar samma datastruktur.

Ingen ny SQL krävs jämfört med CBO 3.7.
Kopiera fungerande config.js från tidigare version.

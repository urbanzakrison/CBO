# CBO On Tour – särskiljningsregler v1.0
Beslut: 2026-10-16. Gäller kommande On Tour-event. Ordinarie CBO-poäng och leaderboard påverkas inte.

## Totalställning
1. Slagspel: lägsta sammanlagda nettoslag. Poängbogey: högsta sammanlagda poäng.
2. Vid lika totalresultat: lägre spelhandicap (SHCP) enligt GameBooks resultatbild för sista genomförda rundan.
3. Om samma SHCP: högre poängbogey på sista nio hålen (hål 10–18) i sista genomförda 18-hålsrundan, beräknat med registrerade hålslag, par, hålens handicapindex och respektive spelares SHCP.
4. Om fortfarande lika eller om säkert hålunderlag saknas: delad placering i appen tills ytterligare särskiljningsregel fastställts. Alfabetisk ordning eller tidigare angiven vinnare får inte avgöra placering.

Om sista rundan har endast 9 hål behöver arrangören fastställa vilken niohålssekvens som avses innan steg 3 kan användas; ingen tyst extrapolering.

## Datakvalitet och publicering
- GameBook är källa till historiskt spelhandicap; använd inte dagens exakta handicapindex.
- Hålbaserad särskiljning kräver verifierade hålresultat och stroke-index. Enbart totalresultat räcker inte.
- Behåll både resultat och beräkningsunderlag spårbart. Inga gissade värden.
- Eventvinnaren ska motsvara vinnaren av verifierad totalställning när eventet avslutas.
- Namn normaliseras till befintlig CBO-medlem och player_id där matchningen är säker; skydd mot dubbletter.
- Ändra inte fungerande Auth, CBO-statistik, GameBook-import eller annan arkitektur.

## Status
Regel BESLUTAD och dokumenterad. Nuvarande frontend i on-tour-preview.html implementerar totalresultat och sista rundans SHCP, men saknar hålbaserad särskiljning och underliggande hole-by-hole-data i eventdetail. Därför är steg 3 PENDING IMPLEMENTATION/VERIFICATION. Ingen produktionskod eller historisk resultatdata ändras av detta dokument.

## Exempel – Lundin Invitation 2026
Håkan Harrysson och Johan Fagerholm: 222 nettoslag, båda SHCP 19 i sista rundan. En tidigare bildbaserad beräkning angav 21 respektive 14 poäng för hål 10–18; detta ska återverifieras mot GameBook innan eventuell automatisk särskiljning publiceras.

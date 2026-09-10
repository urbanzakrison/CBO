# CBO On Tour – historiskt GameBook-källarkiv

Detta är källarkivet för historiska GameBook-skärmbilder som används för att bygga On Tour-historiken.

## Regler
- En mapp per event.
- Ladda upp originalskärmbilder utan att redigera värden.
- Flera bilder för samma runda är tillåtna och förväntade.
- Filnamn kan vara enkla: `r1-01.jpg`, `r1-02.jpg`, `r2-01.jpg` osv.
- Om rundan har flera resultatvyer kan filnamn gärna ange dem, t.ex. `r1-slagspel-01.jpg`, `r1-poangbogey-01.jpg`.
- Lägg inte Golf-ID, CBO-koder, API-nycklar eller andra credentials i detta arkiv.
- Data från dessa bilder ska endast användas för On Tour och får inte påverka ordinarie CBO-resultat, Totalen, Närvaro, statistik eller leaderboard.
- Saknade eller otydliga värden ska lämnas okända; de får inte gissas.

## Testflöde
Första verifieringen görs med `belek-2019/test-r1/`.
Ladda där upp alla GameBook-bilder som hör till Belek 2019, runda 1. När de finns i GitHub läser vi dem därifrån, extraherar resultatet, jämför mot källbilden och skapar först därefter importdata.

## Mappar
Mapparna under denna katalog motsvarar event/rundor där historiken fortfarande behöver kompletteras eller verifieras.

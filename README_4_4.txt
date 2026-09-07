CBO 4.4 – kontrollerat publiceringstest

- Bygger på CBO 4.3.
- AI/GameBook-import och datumfix är oförändrade.
- Knappen i granskningsvyn heter "Testa publicering".
- Testet bygger och validerar exakt den payload som senare skickas till cbo_publish_round.
- Ingen RPC körs och ingenting skrivs till rounds eller round_results.
- Vid godkänt test visas en bekräftelse med omgång, datum, bana, par och antal spelare.

När detta är verifierat kan riktig publicering återaktiveras.

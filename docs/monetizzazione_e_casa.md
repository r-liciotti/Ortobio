# Analisi: La Casa & Strategia di Monetizzazione (Android)

---

## 1. La Casa: Housing Stile *The Sims* a Blocchi (Multi-Piano & Sotterranei)

La Casa è principalmente una **zona di housing creativo**, costruita sullo **stesso motore a griglia** di Campo e Fattoria (zero codice duplicato), dove vedi **solo l'interno a blocchi** e hai libertà totale di progettazione.

### Costruzione & Espansione Stile *The Sims*
- **Partenza:** Inizi con una piccola casetta prefissata (es. `6×8` blocchi interni) con l'essenziale (Letto, una finestra, un piccolo tavolo).
- **Espansione blocco per blocco:** In Modalità Costruzione (a `0` energia e con il tempo in pausa) puoi **espandere la pianta** aggiungendo blocchi di pavimento, tracciare pareti interne per creare nuove stanze (camera, cucina, soggiorno, dispensa), inserire porte, finestre, pavimenti (legno, cotto, pietra) e mobili.
- **Spostamento libero:** Tutti i mobili e gli elementi utili si posizionano, ruotano e spostano liberamente sulla griglia.

### Piani Superiori e Sotterranei Multi-Livello
Un piccolo **selettore di piano (`▲ / ▼`)** sul lato destro dello schermo (comodo col pollice) permette di passare istantaneamente da un livello all'altro:
- **Piano Terra (`0`) & Piani Superiori (`+1`, `+2`…):** Sbloccabili posizionando una **scala interna** e pagando l'ampliamento. Dedicati soprattutto all'**housing** (camere, salotto, studio, veranda/semenzaio luminoso per le piantine).
- **Piani Sotterranei (`-1`, `-2`, `-3`… — Cantine):** Scavabili ed espandibili a blocchi come i piani superiori, perfetti per unire **housing** e **realismo contadino**:
  - **Cantina Vini & Olio (`-1`):** Temperatura fresca e costante dove piazzare **botti di legno** per invecchiare il Vino della tua vigna e scaffali per l'Olio EVO.
  - **Stagionatura & Conservazione (`-2`):** Scaffali per stagionare i **Formaggi** (latte di capra/mucca), conservare patate, aglio, mele e conserve durante l'inverno, o persino piccoli letti per **coltivare funghi** al fresco e al buio nei livelli più profondi!

### Elementi Utili (Piazzabili come Veri Mobili)

| Mobile Funzionale | Piano Ideale | Funzione per la Fattoria |
| :--- | :---: | :--- |
| **🛏️ Letto** | Terra / `+1` | Termina la giornata (Riepilogo incassi + crescita notturna + meteo di domani). |
| **📅 Calendario a Muro** | Qualsiasi | Vista completa della stagione, scadenze potature e meteo. |
| **🪟 Semenzaio da Finestra** | Terra / `+1` | Fa germinare in anticipo piantine estive al caldo a fine inverno. |
| **🍳 Cucina / Fornelli** | Terra | Prepara **Merende del Contadino** (ricaricano Energia) e conserve/marmellate. |
| **🍷 Botti & Scaffali Cantina** | Sotterranei (`-1`, `-2`) | Invecchiano il **Vino**, stagionano i **Formaggi** ed espongono Olio EVO e Miele. |

> [!NOTE]
> **Sviluppo incrementale:** Nella `v0.1`–`v0.2` la Casa parte semplicemente come 1 stanza piccola con il Letto; l'editor a blocchi stile *The Sims*, i piani superiori e i sotterranei multi-livello si aggiungono in modo pulito nelle milestone successive riusando lo stesso sistema di griglia e salvataggio!

---

## 2. Monetizzazione su Android (Google Play)

> [!IMPORTANT]
> **Cosa EVITARE assolutamente:** I giocatori che amano *Stardew Valley* e il realismo agricolo **odiano i timer pay-to-wait** ("aspetta 4 ore o paga gemme") e gli **annunci invasivi** tra una schermata e l'altra. Inserirli distruggerebbe le recensioni su Google Play.

Su Android (dove comprare un'app a scatola chiusa a €5 è più raro rispetto a iOS), i 3 modelli sani tra cui scegliere sono:

| Modello | Come Funziona | Pro | Contro |
| :--- | :--- | :--- | :--- |
| **1. Free-to-Start ("Try & Buy")** ⭐ *(Consigliato)* | Scarichi gratis e giochi **tutta la Primavera (28 giorni)** senza limiti e senza pubblicità. Poi 1 solo acquisto (**€3.99 – €5.99**) sblocca il gioco completo per sempre. | Abbatte la paura di comprare a scatola chiusa; zero pubblicità; zero valute premium; recensioni altissime. | Serve una Prima Stagione molto curata che faccia innamorare il giocatore. |
| **2. Free-to-Play Etico** | Tutto il gioco agricolo è gratis e senza timer. Guadagni da: **pack cosmetici** (mobili Casa, stili staccionate/tetti), **espansioni/DLC** (nuove valli/colture speciali) e **video premiati 100% opzionali** (es. +20 energia o meteo a 7 giorni). | Pubblico molto più ampio su Android; ottima sinergia con l'arredamento della Casa. | Richiede più contenuti cosmetici da produrre e gestione di SDK ads/IAP. |
| **3. Premium Puro (€4.99)** | Pagamento unico subito su Google Play, zero acquisti in-app. | Semplicissimo da implementare (zero SDK monetizzazione). | Molto difficile ottenere download su Android senza un forte marketing (TikTok/Reddit). |

### Scelta Pragmatica per lo Sviluppo
Non serve integrare nessun SDK di pagamento o pubblicità durante lo sviluppo iniziale (`v0.1` – `v0.4`): progettiamo il gioco **pulito e completo** senza timer artificiali, così al momento del lancio potrai scegliere in 1 giorno tra **Free-to-Start** (la scelta più pulita e redditizia per un indie su Android) o **F2P Etico**.

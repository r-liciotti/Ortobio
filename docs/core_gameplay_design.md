# Core Gameplay Design — Ortobio (Documento Condiviso)

> **Come usare questo documento:** Questo è il nostro documento operativo e vincolante sul gameplay. Ogni sezione ha **checkbox `[x]` / `[ ]`** e box **`✏️ Note Riccardo`** così puoi modificare, spuntare, tagliare o aggiungere le tue idee direttamente qui prima di passare al codice.

---

## 1. Identità & Regole d'Oro (Cosa È / Cosa NON È)

**Cos'è Ortobio:**
Un simulatore agricolo 2D pixel art verticale per Android, ispirato al calore e alla progressione di *Stardew Valley*, ma focalizzato al 100% su **orto, frutteti/vigna, allevamento circolare e casa personalizzabile** con controlli rapidi a una mano e un contadino animato che esegue fisicamente le azioni sulle zolle.

**Regole d'Oro di Semplicità (Cosa escludiamo per scelta):**
- [x] **Niente stress mortale da caldo:** il caldo rallenta solo leggermente le piante fredde, senza mai farle morire. Solo il **gelo invernale** mette a rischio le colture estive non protette.
- [x] **Niente miniere, combattimento o mostri:** i materiali di costruzione (Legna, Pietra, Fibre) arrivano dalla **bonifica del terreno** e dalla gestione della fattoria.
- [x] **Niente minigioco pesca o simulatore di appuntamenti con 30 NPC:** restiamo snelli e focalizzati sul lavoro contadino e sulla tenuta.
- [x] **Niente timer pay-to-wait o punizioni estreme:** gli animali non muoiono se salti un giorno; fare tardi la sera non ti fa perdere soldi.

> **✏️ Note Riccardo:**
> - *(Scrivi qui eventuali regole da aggiungere o cambiare)*

---

## 2. Il Micro-Loop: Come Funziona 1 Giornata Tipo

```text
[1. RISVEGLIO IN CASA]  → Controlli meteo di oggi + previsione di domani
         ↓
[2. CAMPO & FATTORIA]   → Vanghi/rastrelli/semini/annaffi/raccogli (col contadino animato)
                          Scegli come spendere i tuoi 100 punti Energia
         ↓
[3. GESTIONE RACCOLTI]  → I prodotti vanno nello ZAINO:
                          • Vendi (Cassetta di Spedizione o Mercato)
                          • Consegna a un Ordine della Bacheca / Traguardo della Valle
                          • Trasforma (Cantina/Frantoio/Cucina) o Mangia (+Energia)
         ↓
[4. SERA & SONNO]       → Vai a letto in Casa → Schermata RIEPILOGO GIORNALIERO
                          (incassi per prodotto, qualità ⭐, XP guadagnati, crescita notturna)
```

**Decisioni che rendono interessante la giornata:**
- **Pausa Intelligente:** il tempo scorre solo nel Campo/Fattoria in esplorazione/lavoro; si ferma su Mappa, Casa, Mercato, Almanacco e Costruzione.
- **Previsione Meteo di Domani:** consultabile al mattino (es. in Casa o Almanacco) per pianificare (*"Domani piove → oggi posso vangare più terreno invece di risparmiare energia per annaffiare"*).
- **Scelta di ritmo:** puoi andare a dormire quando vuoi appena hai finito le tue azioni.

> **✏️ Note Riccardo:**
> - *(Es. durata ideale di 1 giornata? Preferisci vendere sia nella Cassetta serale che direttamente al Mercato?)*

---

## 3. Regole Agronomiche Concrete (Leggibili & Strategiche)

### 3.1 Clima & Stagioni (28 giorni / stagione)
- **Stagione Ideale:** crescita `1.0×` + piena possibilità di ottenere qualità **Argento ⭐ / Oro ⭐⭐**.
- **Fuori Stagione (non gelido):** semina sempre permessa, crescita più lenta (`0.5×`), qualità al massimo Standard.
- **Gelo Critico (solo freddo sotto soglia minima della pianta):** danneggia le colture estive esposte (`-25 salute/giorno`) se non protette da **Telo TNT / Tunnel / Serra**.

### 3.2 Acqua & Pioggia
- **Zolla umida:** crescita piena (`1.0×`).
- **Zolla secca:** crescita rallentata (`0.25×`), la pianta **non muore** ma segnala sete (icona goccia).
- **Giorno di pioggia:** bagna automaticamente tutte le zolle (`0` energia spesa in annaffiatura!).
- **Ristagno prolungato** (solo dopo più giorni di eccesso): leggero rallentamento (`0.6×`), reso visivamente con piccole pozzanghere naturali.

### 3.3 Suolo Vivo, Rotazione & 3 Ammendanti Tattici
Ogni raccolto consuma parte della fertilità della zolla (visibile nel tono della terra). Per rigenerarla o potenziarla:
- **Rotazione con Legumi** (Piselli, Fagiolini, Fave): ricaricano automaticamente la fertilità della zolla (`+20/+25`).
- **3 Ammendanti semplici** (applicabili sulla zolla pronta prima di seminare — max 1 per zolla):
  - [ ] **Compost** *(prodotto da scarti/animali)*: rigenera fertilità e aumenta molto la probabilità di qualità **⭐ / ⭐⭐**.
  - [ ] **Humus Rapido**: accelera la crescita della coltura (`+25%` velocità).
  - [ ] **Pacciamatura di Paglia**: trattiene l'umidità per 2 giorni (riduce le annaffiature) e blocca le erbacce.

### 3.4 Qualità al Raccolto & Piccoli Picchi di Soddisfazione
- **3 Livelli di Qualità:**
  - **Standard** (`1.0×` prezzo)
  - **Argento ⭐** (`1.25×` prezzo)
  - **Oro ⭐⭐** (`1.5×` prezzo)
  - Determinati al momento del raccolto da: **Livello Contadino + Fertilità/Compost + Stagione Ideale**.
- [ ] **Ortaggi Giganti** *(v0.3+)*: piantare un quadrato `3×3` di alcune colture grandi (Cavolo, Zucca, Anguria) ben irrigate può fonderle in un ortaggio gigante da doppia resa!

> **✏️ Note Riccardo:**
> - *(Ti convincono i 3 livelli di qualità e i 3 ammendanti, o vuoi semplificare/cambiare qualcosa?)*

---

## 4. Progressione del Contadino (Livelli, XP & Specializzazioni)

Ogni azione produttiva (raccogliere ortaggi/frutta, curare animali, produrre olio/vino/formaggio) fa guadagnare **XP Contadino** (Livelli `1 → 10`):
- **Bonus automatico a ogni livello:** `-3%` costo energia sugli attrezzi + leggero aumento probabilità qualità **⭐ / ⭐⭐** + sblocco di nuove ricette/accessori (Spaventapasseri, Irrigatore, Compostiera, Botti, Serra).
- **Scelta di Specializzazione (come in *Stardew Valley*):**
  - **Livello 5** *(scegli 1)*:
    - [ ] **Ortolano:** ortaggi e frutta valgono `+15%`.
    - [ ] **Allevatore:** uova, latte, miele e tartufi valgono `+20%`.
  - **Livello 10** *(scegli 1)*:
    - [ ] **Artigiano:** prodotti trasformati (Vino, Olio EVO, Formaggi, Marmellate) valgono `+35%`.
    - [ ] **Agronomo:** tutte le colture crescono `+15%` più velocemente e consumano meno fertilità.

> **✏️ Note Riccardo:**
> - *(Vuoi un unico livello generale "Contadino" o rami separati tipo Orto / Animali / Artigianato?)*

---

## 5. Il Motore degli Obiettivi (Perché Continuo a Giocare)

Per dare sempre uno scopo chiaro a breve, medio e lungo termine:

### 5.1 Breve Termine — Bacheca Ordini del Paese *(Settimanali)*
- [ ] Ogni settimana compaiono **2–3 richieste concrete** al Mercato/Bacheca (es. *"Il fornaio cerca 6 Ravanelli entro 4 giorni → 180€ + 25 XP"*).
- Scopo: guida cosa seminare questa settimana e premia la varietà.

### 5.2 Medio/Lungo Termine — Traguardi della Valle *(stile Bundle di Stardew)*
- [ ] Cassette permanenti da completare consegnando i prodotti richiesti; ogni cassetta completata **sblocca una grande novità**:
  - **Cassetta dell'Orto Primaverile** → Sblocca **Accessori Avanzati / Irrigatori**
  - **Cassetta della Fattoria** → Sblocca la **Fattoria #1** (Pollaio & Recinti)
  - **Cassetta d'Autunno (Olive & Uva)** → Riapre il **Frantoio / Cantina**
  - **Cassetta Qualità Oro ⭐⭐** → Sblocca la **Serra Fredda** (o il **Campo #2**)

### 5.3 Ritmo & Collezionismo
- [ ] **Almanacco & Collezione:** registra ogni coltura/prodotto mai raccolto o venduto (con la stella massima raggiunta ⭐/⭐⭐).
- [ ] **Bonifica del Campo → Materiali:** il campo parte con i primi `10×8` blocchi puliti e il resto coperto da erba alta, rami e pietre; ripulirlo dà **Legna, Pietra e Fibre** per costruire recinti, compostiere e accessori.
- [ ] **Sagra / Fiera di Fine Stagione (Giorno 28)** *(v0.4+)*: evento stagionale dove esponi i tuoi 4–6 prodotti migliori e vinci semi rari / arredi esclusivi per la Casa.

> **✏️ Note Riccardo:**
> - *(Quali sblocchi ti piacerebbe legare ai Traguardi della Valle? Ti piace l'idea della Fiera di fine stagione?)*

---

## 6. Economia, Zaino & Rete Anti-Soft-Lock

- **Zaino / Magazzino:** conserva semi, raccolti (divisi per qualità), materiali (Legna, Pietra, Compost) e prodotti trasformati.
- **Vendita Doppia Scelta:**
  - **Cassetta di Spedizione** (nel Campo/Casa): metti dentro ciò che vuoi vendere e incassi nel **Riepilogo Serale** quando vai a dormire.
  - **Mercato del Paese:** vendita diretta immediata quando ti servono subito monete per comprare nuovi semi.
- **Cibo & Energia:** puoi mangiare i tuoi prodotti (o merende cucinate in Casa) per ricaricare energia durante la giornata.
- **Anti-Soft-Lock:** se finisci con `0 €`, `0` semi e `0` raccolti, il Mercato offre gratuitamente un piccolo sacchetto di semi base di stagione (+ raccolta spontanea sui bordi del campo).

> **✏️ Note Riccardo:**
> - *(Preferisci avere sia la Cassetta serale sia la vendita diretta al Mercato, o una sola delle due?)*

---

## 7. Mappa di Implementazione (Cosa Entra in Quale Versione)

Spunta o sposta liberamente le voci prima di avviare lo sviluppo della `v0.2`:

### `v0.2` — Il Loop Giocabile Completo (Priorità Immediata)
- [x] **Mappa Generale** (mini-pixel art: Casa, Campo #1, Mercato)
- [x] **Zaino + Economia Reale** (compri semi, raccogli nello zaino, vendi al Mercato o nella Cassetta)
- [x] **Casa Base + Letto + Riepilogo Serale** (incassi, crescita, meteo di domani)
- [x] **Qualità al Raccolto (`Standard / ⭐ / ⭐⭐`)** + **XP / Livello Contadino base**
- [x] **Bacheca Ordini v1** (2–3 richieste settimanali con ricompensa)
- [x] **Almanacco v1** (meteo oggi/domani + schede colture + registro collezione)
- [x] **Salvataggio Locale Automatico**

### `v0.3` — Profondità Agronomica & Risorse
- [ ] **Bonifica Campo** (erba alta, rami, pietre → Legna, Pietra, Fibre)
- [ ] **3 Ammendanti** (Compost, Humus rapido, Paglia) + **Accessori 1×1** (Irrigatore, Spaventapasseri, Telo TNT)
- [ ] **Traguardi della Valle (Bundle)** + **Primi Alberi** (Melo, Ulivo) + **10–12 colture**
- [ ] **Stagioni più riconoscibili visivamente** (fiori, foglie che cadono, neve a terra, dettagli stagionali)

### `v0.4` — Fattoria, Animali & Trasformazioni
- [ ] **Fattoria #1** con Recinti flood-fill, Pollaio, Galline, Compostiera
- [ ] **Arnie (Api)** + prime trasformazioni + **Sagra di Fine Stagione (G.28)**

### `v0.5+` — Casa Stile *The Sims*, Vigna & Endgame
- [ ] **Casa espandibile a blocchi** (piani `+1/+2` e **Sotterranei `-1/-2`** per Cantina Vini & Formaggi)
- [ ] **Vigna, Capre, Maiali, Mucche, Serra, Ortaggi Giganti, NPC aiutanti**

---

## 8. Spazio Libero Idee & Modifiche (Riccardo)

*(Usa liberamente questo spazio per annotare meccaniche nuove, modifiche al bilanciamento, idee su UI, grafica o feeling del gioco. Quando hai finito di modificarlo, dimmelo e lo rileggo prima di scrivere codice!)*

- 

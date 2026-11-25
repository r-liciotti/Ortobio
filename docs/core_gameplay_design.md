# Core Gameplay Design — Ortobio (Documento Condiviso)

> **Come usare questo documento:** Questo è il nostro documento operativo e vincolante sul gameplay. Ogni sezione ha **checkbox `[x]` / `[ ]`** e box **`✏️ Note Riccardo`** così puoi modificare, spuntare, tagliare o aggiungere le tue idee direttamente qui prima di passare al codice.

---

## 1. Identità & Regole d'Oro (Cosa È / Cosa NON È)

**Cos'è Ortobio:**
Un simulatore agricolo 2D pixel art verticale per Android, ispirato al calore e alla progressione di *Stardew Valley*, ma focalizzato al 100% su **orto, frutteti/vigna, allevamento circolare e casa personalizzabile** con controlli rapidi a una mano e un contadino animato che esegue fisicamente le azioni sulle zolle.

**Regole d'Oro di Semplicità e Design:**
- [x] **Sviluppo a Micro-Milestone iterativo:** invece di maxi-aggiornamenti, procediamo per **piccole versioni mirate** (1–2 meccaniche alla volta) per testare ogni idea dal vivo e correggere liberamente design, bilanciamento o stile grafico tra una prova e l'altra.
- [x] **Regola "Problema → Rimedio" sul Clima:** ogni volta che clima o stagione influiscono negativamente sull'orto (es. gelo invernale sulle sole specie sensibili), **deve sempre esistere un accessorio o accorgimento reale** per rimediare (Telo TNT, Tunnel, Serra, Pacciamatura, Rete ombreggiante, Irrigatore).
- [x] **Niente morti punitive da carenze o caldo:** se una zolla manca di nutrienti (o fa caldo), **la pianta NON muore**: cresce più lentamente e produce meno. Solo il **gelo critico** su specie sensibili non protette può danneggiarle.
- [x] **Produttività + Domanda/Offerta (niente stelle qualità):** curare bene la terra si riflette in **più prodotto raccolto** (non in 3 versioni con stelline dello stesso ortaggio); il prezzo varia in base alla **Domanda e Offerta del Villaggio**.
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
                          (incassi per prodotto, variazione prezzi domanda/offerta, XP, crescita notturna)
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
- **Stagione Ideale:** crescita `1.0×` e **produttività piena** (massimo raccolto per zolla).
- **Fuori Stagione (non gelido):** semina sempre permessa, crescita più lenta (`0.5×`) e resa leggermente ridotta.
- **Gelo Critico (solo freddo sotto soglia minima della pianta):** danneggia le colture estive esposte (`-25 salute/giorno`) se non protette da **Telo TNT / Tunnel / Serra**.

### 3.2 Acqua & Pioggia
- **Zolla umida:** crescita piena (`1.0×`).
- **Zolla secca:** crescita rallentata (`0.25×`), la pianta **non muore** ma segnala sete (icona goccia).
- **Giorno di pioggia:** bagna automaticamente tutte le zolle (`0` energia spesa in annaffiatura!).
- **Ristagno prolungato** (solo dopo più giorni di eccesso): leggero rallentamento (`0.6×`), reso visivamente con piccole pozzanghere naturali.

### 3.3 Suolo Vivo, Rotazione Reale (`N - P - K`) & Leggibilità
In agronomia reale la fertilità dell'orto ruota attorno ai **3 macro-elementi `N - P - K`** (semplici, reali e immediatamente utili per la rotazione):

| Elemento | Ruolo Botanico | Chi lo **Consuma di più** | Come si **Rigenera** |
| :--- | :--- | :--- | :--- |
| **`N` — Azoto** | Crescita di **Foglie** | Lattuga, Cavolo Verza, Spinaci, Bietola | **Legumi** (Piselli, Fagiolini, Fave — azotofissatori!), Pollina/Compost |
| **`P` — Fosforo** | **Radici, Bulbi & Fiori** | Ravanello, Carota, Cipolla, Patata, Aglio | Compost maturo, Letame, Riposo del terreno |
| **`K` — Potassio** | **Frutti & Sapore** | Pomodoro, Zucchina, Peperone, Melanzana, Zucca | Cenere di legna, Compost, Letame |

- **Diminuzione lenta e graduale (nessuna ansia):**
  - Ogni zolla parte ben nutrita (`N: 80, P: 80, K: 80` su `100`).
  - Un raccolto consuma solo una **piccola quota mirata** (es. `-10` / `-14` sull'elemento principale della coltura e `-3` sugli altri), così una zolla regge tranquillamente **3–5 raccolti pieni** prima che si noti un calo di produttività.
- **Effetto non punitivo:** se pianti una coltura su una zolla con l'elemento principale basso, **la pianta NON muore** — semplicemente **cresce più lentamente e produce meno pezzi**.
- **Scoperta Graduale & Strumento "Sonda Analisi Suolo" (sbloccabile più avanti):**
  - **All'inizio del gioco (`N-P-K` nascosti):** il giocatore **non vede** subito i valori di Azoto, Fosforo e Potassio (onboarding pulito e realistico: all'inizio capisci solo a occhio se la terra è più chiara/sfruttata o se rende meno pezzi).
  - **Sblocco successivo — Strumento `Sonda / Kit Analisi Suolo`:** uno strumento apposito acquistabile/sbloccabile più avanti. Usandolo sulle zolle (col contadino che fa l'analisi del terreno!), rivela i **valori reali `N - P - K`** della zolla analizzata (visibili nell'Ispettore e come vista cromatica sulle zolle analizzate), permettendoti di fare una rotazione mirata o applicare l'ammendante giusto!
- **Rimedi & Ammendanti** (applicabili sulla zolla pronta prima di seminare):
  - [x] **Rotazione colturale (Gratis):** alternare Foglie → Radici → Frutti → Legumi bilancia naturalmente `N-P-K`.
  - [x] **Compost / Letame:** ricarica tutti e 3 gli elementi (`N-P-K`) aumentando la **produttività** (più pezzi raccolti!).
  - [ ] **Cenere di legna / Humus:** ricarica mirata (`K` / crescita più rapida).
  - [ ] **Pacciamatura di Paglia:** trattiene l'umidità per 2 giorni e frena le erbacce.

### 3.4 Produttività (Resa in Quantità) & Ortaggi Giganti
- **Niente livelli di qualità (niente stelle Argento/Oro):** lo Zaino resta pulitissimo (1 solo slot per ogni ortaggio).
- **La cura della terra = Più Prodotto:** una zolla con `N-P-K` ricchi, irrigata bene e nella stagione ideale produce **più pezzi per raccolta** (es. `1×` in terreno povero → `2×` normale → `3–4×` in terreno ricco e ben curato!).
- [ ] **Ortaggi Giganti** *(v0.3+)*: piantare un quadrato `3×3` di alcune colture grandi (Cavolo, Zucca, Anguria) ben nutrite può fonderle in un ortaggio gigante da doppia resa!

> **✏️ Note Riccardo:**
> - *(Confermato: via le stelline di qualità, la cura aumenta i pezzi prodotti!)*

---

## 4. Doppio Binario di Progressione: Contadino (Punti Abilità) & Villaggio (Livelli a Monete)

La crescita del gioco si divide in **2 binari distinti e complementari**:

### 4.1 Livelli del Contadino → Punti Abilità & Build Personale
Ogni azione produttiva (raccogliere, curare animali, trasformare prodotti) fa guadagnare **XP Contadino**. Niente bonus automatici uguali per tutti: **a ogni livello ricevi Punti Abilità** da spendere liberamente per costruire la tua **build** (ogni caratteristica sale da `Lv. 0` a `Lv. 5` e al `Lv. 5` sblocca un **Talento Speciale**):

| Caratteristica | Effetto per ogni punto speso | Talento Speciale (a Lv. 5) |
| :--- | :--- | :--- |
| **Agilità** *(Movimento)* | `+12%` velocità di camminata del contadino tra le zolle | **Passo Svelto:** nessuna lentezza su terreno fangoso/bagnato |
| **Destrezza** *(Azione)* | `-10%` durata animazioni (vanga, rastrello, acqua, semina, raccolta) | **Mano Lesta:** `15%` di chance di lavorare gratis anche 1 zolla adiacente |
| **Resistenza** *(Energia)* | `+15` Energia Massima e minor fatica sui lavori pesanti | **Merenda Contadina:** i cibi ricaricano `+30%` energia in più |
| **Agronomia** *(Produttività)* | Più pezzi raccolti per zolla + minor consumo di `N-P-K` | **Terra Umida:** `20%` di chance che la zolla annaffiata resti umida il giorno dopo |
| **Selezione Semi** | `+6%` chance di recuperare 1 seme gratis al raccolto + crescita più rapida | **Semi Rustici:** le colture fuori stagione crescono più veloci |
| **Commercio & Fattoria** | `+5%` prezzi di vendita e resa animali/trasformazioni | **Fiuto del Mercato:** vedi in anticipo quale prodotto avrà **Domanda Alta domani** |

*(Possibilità di **ridistribuire i Punti Abilità** al Villaggio con una piccola spesa per cambiare build.)*

### 4.2 Livelli del Villaggio → Investimenti in Monete, Edifici & Cap NPC (Calibrazione Early → Mid → Late)
Il **Villaggio** ha un proprio **Livello (`Lv. 1 → Lv. 5`)** che si alza finanziando opere concrete del paese. L'assunzione di **NPC** arriva solo nel **Mid-Game (`Lv. 3+`)**, così nella prima parte di gioco si valorizza davvero il lavoro manuale del contadino e la sua build:

| Livello Villaggio | Fase | Negozi & Edifici Sbloccati | Cap NPC Assumibili | Impatto su Mercato & Tenuta |
| :--- | :--- | :--- | :---: | :--- |
| **Lv. 1 — Casale** *(Partenza)* | Early *(0–2h)* | • **Bancarella Semi** (semi base)<br>• **Bacheca Ordini** (2 ordini/sett.) | **0 NPC** | Domanda base; Campo #1, Casa base. |
| **Lv. 2 — Frazione Agricola** | Early-Mid *(2–5h)* | • **Bottega Agronomo** *(**Sonda Analisi Suolo**, **Telo TNT**, Compost, nuovi semi)*<br>• **Fabbro** *(attrezzi in Ferro)*<br>• **Falegname** *(recinti & espansioni base Casa)* | **0 NPC** *(lavori ancora tu con la tua build!)* | Domanda `+20%` più capiente; sblocca **Fattoria #1 (Pollaio/Galline)** e **Irrigatori base**. |
| **Lv. 3 — Piccolo Borgo** | **Mid-Game** *(5–10h)* | • **Mercato Coperto** *(+ Mercante Ambulante 1 volta/sett.)*<br>• **Vivaio** *(alberi **Melo**, **Ulivo**)*<br>• **Locanda del Borgo** *(apre il reclutamento NPC!)* | **1 NPC**<br>*(Bracciante Orto **oppure** Fattore)* | Domanda `+45%` e 3 ordini/sett.; sblocca **Campo #2** e **Stalla (Capre)**. |
| **Lv. 4 — Paese Fiorente** | Mid-Late *(10–16h)* | • **Frantoio & Cantina Sociale** *(**Olio EVO**, **Vino**)*<br>• **Caseificio** *(Formaggi)*<br>• **Fabbro Lv. 2** *(attrezzi in Acciaio)* | **3 NPC**<br>*(Bracciante, Fattore, **Artigiano**)* | Domanda `+75%`; sblocca **Vigna**, **Maiali**, **Piani Superiori Casa (`+1`)**. |
| **Lv. 5 — Consorzio & Tenuta** | Late-Game *(16h+)* | • **Consorzio Agrario** *(**Serra Fredda**, irrigazione a goccia)*<br>• **Architetto** *(**Sotterranei Casa `-1/-2`**)*<br>• **Piazza della Fiera** *(Fiera del Raccolto)* | **5 NPC**<br>*(+ **Venditore Bancarella** automatico)* | Domanda massima (mercanti esterni); sblocca **Mucche** e **Campo #3**. |

*(Gli NPC assunti alla Locanda guadagnano esperienza nel loro ruolo nel tempo, migliorando leggermente efficienza; ogni livello del Villaggio evolve anche visivamente sulla Mappa Generale.)*

> **✏️ Note Riccardo:**
> - *(Calibrato: 0 NPC fino a Lv. 2; Locanda e 1° NPC sbloccati in Mid-Game al Lv. 3!)*

---

## 5. Il Motore degli Obiettivi, Eventi & Fiere (Perché Continuo a Giocare)

Per dare sempre uno scopo chiaro a **breve, medio e lungo termine** senza ansia o penalità punitive (stile *Story of Seasons* + *Coral Island* + *Stardew Valley*):

### 5.1 Breve Termine — Bacheca Ordini del Paese *(Settimanali, Zero Ansia)*
- [x] Ogni settimana compaiono **2–3 richieste concrete** al Mercato/Bacheca (es. *"Il fornaio cerca 6 Ravanelli entro 4 giorni"*).
- **Zero penalità se scadono:** semplicemente si aggiornano con nuove richieste.
- **Ricompense variegate (non solo monete!):** `€`, **XP Contadino**, sacchi di **Compost**, **semi rari**, materiali (Legna/Pietra) o piccoli **arredi per la Casa**.

### 5.2 Medio/Lungo Termine — Traguardi della Valle *(stile Bundle)*
- [x] Cassette permanenti da completare consegnando i prodotti richiesti; ogni cassetta completata **sblocca grandi traguardi o agevolazioni** (es. *Cassetta di Primavera*, *Cassetta della Fattoria*, *Cassetta d'Autunno Olive & Uva*, *Cassetta del Grande Raccolto*).

### 5.3 Eventi Randomici Periodici *(Ogni 5–10 giorni — Sorprese & Opportunità)*
Eventi leggeri e vari che rompono la routine e premiano chi sa cogliere l'attimo:
- [x] **Boom di Mercato / Visite Speciali:** es. *"Carovana dei Mercanti"* (`+35%` su una categoria per 2 giorni) o *"Serata Speciale in Osteria"* (`+50%` su 1–2 ortaggi specifici) → si lega direttamente alla **Domanda/Offerta** e premia chi conserva scorte nello Zaino!
- [x] **Settimana a Tema (Micro-Sfida opzionale):** es. *"Settimana delle Radici"* → vendere radici/bulbi dà `+20%` XP Contadino extra.
- [x] **Sorprese Naturali nell'Orto:** eventi rari positivi (es. *"Rugiada Rigenerante"* che bagna tutto e ricarica leggermente `N-P-K`, o *"Passaggio d'Api"* `+25%` produttività per un giorno) e piccole sfide preannunciate sempre contrastabili con accessori.

### 5.4 Sagre & Fiere di Fine Stagione (Giorno 28) + Premio "Marchio del Borgo"
- [x] **1 Fiera a fine stagione** dove esponi i tuoi prodotti migliori (o partecipi a una sfida stagionale):
  - **Premio "Marchio del Borgo"** *(ispirato a Story of Seasons)*: il prodotto con cui vinci ottiene un riconoscimento permanente (`Bronzo / Argento / Oro`) che ne **aumenta stabilmente la richiesta e il prezzo al Mercato (`+10% / +20%`)**!
  - **Premi extra:** XP Contadino, semi rari e **trofei/arredi esclusivi da esporre in Casa** (con piccolo premio di consolazione anche se non arrivi 1°).

### 5.5 Ritmo & Collezionismo
- [x] **Almanacco & Collezione:** registra ogni coltura/prodotto mai raccolto o venduto (totale pezzi prodotti + eventuali Marchi vinti alle Fiere).
- [x] **Bonifica del Campo → Materiali:** ripulire il campo da erba alta, rami e pietre dà **Legna, Pietra e Fibre** per costruire recinti, compostiere e accessori.

> **✏️ Note Riccardo:**
> - *(Confermato: Bacheca + Traguardi + Eventi randomici + Sagre con premio permanente sul prezzo/richiesta!)*

---

## 6. Economia Dinamica, Bancarella al Mercato, Zaino & Anti-Soft-Lock

### 6.1 La Tua Bancarella al Mercato (Vendita Visiva agli NPC del Villaggio)
Al posto di un semplice pulsante "Vendi", al Mercato del Villaggio gestisci una **tua postazione/bancarella fisica** in pixel art:
- **Come funziona:** posizioni i tuoi prodotti dentro le **Cassette** esposte sul banco. Durante la giornata **gli NPC del villaggio passano davanti alla tua bancarella** e comprano ciò che desiderano in base alla **Domanda & Offerta del giorno** (i prodotti molto richiesti vanno a ruba a prezzo alto; quelli con bassa domanda si vendono più lentamente). La sera il **Riepilogo Giornaliero** ti mostra tutto l'incasso della bancarella!
- **Progressione di Banco & Cassette (Potenziabili):**
  - **Livello del Banco (Postazione):** aumenta il numero massimo di cassette esponibili contemporaneamente (es. `Lv. 1: 3 cassette` → `Lv. 2: 5` → `Lv. 3: 7` → `Lv. 4: 9 cassette`!).
  - **Livello delle Cassette:** aumenta la capienza di ciascuna cassetta (es. `Lv. 1: 6 prodotti` → `Lv. 2: 10` → `Lv. 3: 15` → `Lv. 4: 20 prodotti`!) e sui livelli alti migliora la conservazione dei prodotti esposti.
- **5 Tipologie di Cassette / Espositori (Raggruppate per Categoria):**
  1. **Cassetta di Legno *(Orto & Frutta Fresca)*** *(disponibile da subito)*: tutti gli ortaggi, radici, legumi, aromatiche e frutta degli alberi.
  2. **Banco Fresco *(Uova, Latte & Formaggi)***: uova, latte, burro, formaggi freschi e stagionati.
  3. **Scaffale Vasetti *(Conserve, Marmellate & Miele)***: miele, marmellate, sughi, sott'oli ed essiccati (senza scadenza).
  4. **Rastrelliera Bottiglie *(Olio EVO, Vino & Succhi)***: bottiglie di olio extravergine, vino, sidro e succhi.
  5. **Banco Specialità / Carni & Salumi** *(predisposto per eventuali prodotti animali avanzati in futuro)*.
- **Domanda & Offerta del Villaggio:**
  - Ogni giorno ogni prodotto ha una domanda chiara: **Bassa (`0.75×`)**, **Normale (`1.0×`)**, **Alta (`1.3×`)**, **Richiestissimo (`1.6×` ▲)**.
  - Esporre/vendere sempre lo stesso prodotto in grandi quantità satura temporaneamente il villaggio (abbassandone il prezzo), premiando chi **ruota le colture (`N-P-K`)** e varia l'esposizione sulla bancarella!
  - *(Opzionale emergenza)* Il **Mercante all'ingrosso** può comunque ritirare merce istantaneamente a prezzo ridotto (`80%`) se ti servono monete al volo, ma **la tua Bancarella resta sempre il canale più redditizio**.
- **Zaino / Magazzino (Semplice, niente equipaggiamento attrezzi):**
  - Gli **attrezzi** (Vanga, Rastrello, Annaffiatoio, Sonda, ecc.) restano **sempre pronti nella barra `Lavora`** e si potenziano direttamente al Fabbro (`Vecchio → Ferro → Acciaio`) senza doverli spostare/equipaggiare nello Zaino.
  - Lo **Zaino / Magazzino** conserva solo: **Semi**, **Raccolti** (1 solo slot pulito per prodotto), **Concimi/Accessori** e **Materiali** (Legna, Pietra, Fibre).
- **Cibo & Energia:** puoi mangiare i tuoi prodotti (o merende cucinate in Casa) per ricaricare energia durante la giornata.
- **Anti-Soft-Lock:** se finisci con `0 €`, `0` semi e `0` raccolti, il Mercato offre gratuitamente un piccolo sacchetto di semi base di stagione (+ raccolta spontanea sui bordi del campo).

### 6.2 Semi, Attrezzature, Freschezza & Raffinazione (Decisioni Confermate)

**Nuove Categorie di Semi:**
- [x] **Concime Verde (Sovescio):** es. *Trifoglio* o *Senape* — costano pochissimo, crescono in 3–4 giorni e, interrandoli con la Vanga, **rigenerano profondamente `N-P-K`** sulla zolla.
- [x] **Piante Compagne (Leggere & Facoltative):** es. *Calendula*, *Basilico* — bonus leggero sulle zolle adiacenti senza mai complicare l'orto né diventare obbligatorie.
- [x] **Semi Rari & Varietà Antiche (Mercante Ambulante & Premi Sagre):** es. *Zafferano*, *Pomodoro Cuore di Bue*, *Carciofo* (perenne), *Fragoline di Bosco*.

**Freschezza & Raffinazione (Equilibrio Domanda/Offerta):**
- [x] **Scadenza / Freschezza dei Prodotti Freschi:** i raccolti freschi non restano eterni nello Zaino (es. ortaggi delicati ~5–7 gg; radici/zucche ~14–21 gg), impedendo di accumulare tutto all'infinito aspettando il picco di domanda!
  - Se scadono diventano **Scarti Vegetali** utili per la **Compostiera** (zero spreco punitivo).
  - La **Cantina Sotterranea (`-2`)** in Casa ne prolunga la freschezza.
- [x] **Conserve & Prodotti Raffinati:** trasformare i raccolti freschi in **Conserve, Marmellate, Sughi, Olio EVO, Vino, Formaggi** elimina la scadenza e **aumenta il valore di vendita**.

**Attrezzature & Concimi Mirati:**
- [x] **Sonda Analisi Suolo `Lv. 1` (1 zolla) → `Lv. 2` (`3×3` a Villaggio Lv. 4):** per analizzare velocemente le aiuole.
- [x] **Concimi Semplici per `N-P-K`:** *Compost* (completo `N+P+K`), *Concime Foglie (`N`)*, *Concime Radici (`P`)*, *Concime Frutti / Cenere (`K`)* — nomi immediati e leggibili.
- [x] **Rimedi Clima progressivi:** *Campana di Vetro* (`1×1`) → *Telo TNT* (`1×1`) → *Tunnel Basso* (`1×4`) → *Serra Fredda* (`4×4`); *Barometro / Stazione Meteo* in Casa (previsioni a 2–3 giorni).
- [x] **Automazione:** *Irrigatore Base (`3×3`)* → *Irrigazione a Goccia*.

> **✏️ Note Riccardo:**
> - *(Tutte le 8 decisioni confermate e integrate!)*

---

## 7. Piano a Micro-Milestone (Sintesi — Dettaglio in `piano_sviluppo_incrementale.md`)

Ogni micro-milestone testa **1–2 meccaniche concrete** in Godot prima di aggiungere la successiva:

- **Fase A (Campo & Agronomia):**
  - `v0.1` *(Completata ✅)*: Campo `10×30`, blocchi arrotondati 3D, 3 semi, contadino animato `24×28` con coda azioni.
  - `v0.2a`: **`N-P-K` lenti** (nascosti di default) + **Produttività in pezzi** + **Piselli** + **Concime Verde (Trifoglio)** + **Compost** + **Sonda Analisi Suolo `Lv. 1`**.
  - `v0.2b`: **Rimedi Clima** (`Telo TNT`, `Campana di Vetro`, `Irrigatore 3×3`) + **Concimi semplici `N/P/K`**.
- **Fase B (Loop Completo & Progressione):**
  - `v0.3a`: **Zaino con Freschezza** + **Bancarella al Mercato** (Cassette potenziabili + Clienti NPC + **Domanda/Offerta**).
  - `v0.3b`: **Mappa Generale** + **Casa base** (Letto, **Riepilogo Serale**, Barometro) + **Salvataggio locale**.
  - `v0.3c`: **Build Contadino** (6 caratteristiche + Talenti Lv. 5) + **Villaggio `Lv. 1 → Lv. 2`**.
  - `v0.3d`: **Bacheca Ordini** + **Eventi Randomici** + **Almanacco v1**.
- **Fase C (Espansione & Fattoria):**
  - `v0.4a`: Bonifica Campo (Legna/Pietra/Fibre) + 10–12 colture (Piante Compagne) + **Polish visivo Stagioni**.
  - `v0.4b`: Alberi `2×2` (**Melo**, **Ulivo**) + **Traguardi della Valle (Bundle)**.
  - `v0.4c`: **Fattoria #1** (Recinti flood-fill, Pollaio, Galline, Compostiera) + **Banco Fresco** in Bancarella.
- **Fase D (Mid/Late-Game):**
  - `v0.5a`: **Villaggio `Lv. 3`** + **Locanda (1° NPC)** + Mercante Ambulante + **Sagra Fine Stagione (`Marchio del Borgo`)**.
  - `v0.5b`: **Conserve / Olio EVO / Vino / Formaggi** (senza scadenza!) + nuove Cassette Bancarella + Vigna & Animali avanzati (`Lv. 4–5`).
  - `v0.5c`: **Casa stile *The Sims* multi-piano + Sotterranei (`-1/-2`)** + Serra Fredda + polish Android.

---

## 8. Spazio Libero Idee & Modifiche (Riccardo)

*(Usa liberamente questo spazio per annotare meccaniche nuove, modifiche al bilanciamento, idee su UI, grafica o feeling del gioco. Quando hai finito di modificarlo, dimmelo e lo rileggo prima di scrivere codice!)*

- 

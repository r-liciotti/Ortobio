# Analisi: Tempo, Energia ed Economia

Questo documento definisce come scorre la giornata del contadino, come funziona la fatica e come si regge l'economia del gioco, mantenendo il tono **rilassante, mobile-friendly e realistico**.

---

## 1. Come Scorre il Tempo? (Tempo Reale + Pausa Intelligente)

Il gioco usa un **orologio in tempo reale** per dare ritmo, atmosfera (alba → giorno → tramonto → sera) e immersione, ma progettato apposta per non creare mai ansia su mobile:

- **Pausa Intelligente Automatica:**
  - Il tempo **scorre** solo mentre sei attivo nel **Campo** o nella **Fattoria** (Modalità Esplora/Lavoro).
  - Il tempo **si ferma automaticamente** quando sei sulla **Mappa Generale**, in **Casa**, al **Mercato**, nell'**Almanacco**, nello **Zaino** o in **Modalità Costruzione** (quando posizioni recinti, ricoveri e accessori).
- **Velocità della Giornata Regolabile (Impostazioni):**
  - Il giocatore può scegliere il proprio ritmo preferito (es. **Normale ~12–15 min**, **Lunga ~20 min**, **Rilassata ~30 min** per giornata).
- **Fine Giornata Dolce:** Puoi andare a dormire in Casa in qualsiasi momento quando hai finito i lavori; se si fa tardissimo (es. mezzanotte), il contadino torna a casa a dormire con una leggera stanchezza il mattino seguente (nessuna penalità punitiva o perdita di soldi).

---

## 2. Sistema di Energia (Scuola A/B — Energia Leggera & Scalabile)

L'energia serve a dare peso ai lavori faticosi e a guidare la progressione nelle prime ore, **senza mai bloccare il divertimento** quando la fattoria cresce.

### Costi Differenziati (Solo Lavori Pesanti)
- **Azioni Leggere (`0` energia):** Raccogliere ortaggi/frutta/uova, seminare, ispezionare zolle, progettare/spostare accessori e recinti.
- **Lavori Pesanti (consumano energia):**
  - **Vangare / Bonificare rovi e pietre:** `4` energia.
  - **Zappare erbacce / Rastrellare / Potare alberi:** `2–3` energia.
  - **Annaffiare a mano:** `2` energia (0 se piove o se c'è un irrigatore).
  - **Accudire / Pulire stalle grandi:** `2–3` energia.

### Come si Scala su Più Campi e Fattorie (Mid/Late Game)
Quando i campi e gli animali aumentano, tempo ed energia non diventano un collo di bottiglia grazie a **4 livelli di progressione**:
1. **Crescita del Contadino & Cibo:** L'energia massima aumenta col tempo (`100 → 150 → 200+`) e mangiare i prodotti della tua fattoria (mele, uova, formaggio, pane e olio) ricarica subito la barra durante la giornata.
2. **Attrezzatura Migliore:** Attrezzi potenziati (Ferro → Acciaio) riducono la fatica (`-30%` / `-50%`) e lavorano **più blocchi contemporaneamente** (risparmiando sia tempo reale che energia).
3. **Sistemi di Automazione:** **Irrigatori / irrigazione a goccia** nel Campo e **Mangiatoie/Abbeveratoi capienti** nella Fattoria eliminano il lavoro ripetitivo quotidiano.
4. **Assunzione di NPC (Braccianti / Aiutanti):** Nelle fasi avanzate puoi assumere NPC (con una paga giornaliera o stagionale) da assegnare a un Campo o a una Fattoria specifica (es. *"Bracciante Orto"* che annaffia/raccoglie, *"Fattore"* che nutre e pulisce gli animali), trasformando il giocatore da piccolo ortolano a vero gestore di una tenuta agricola.

---

## 3. Economia Iniziale & Curva Finanziaria

### Partenza (Giorno 1 — Primavera)
- **Monete iniziali:** `150 🪙`
- **Dotazione:** 1 Campo (con i primi `10×10` blocchi già puliti, il resto coperto da erba alta/cespugli/pietre), Casa base arredabile, 4 attrezzi vecchi, `5` semi di Ravanello in omaggio.
- **Obiettivo della prima settimana:** Raccogliere i primi ravanelli (4 gg) e lattughe (7 gg), capire il ciclo del meteo, iniziare a mettere da parte soldi per semi estivi e il primo albero/accessorio.

### Equilibrio tra Entrate (Sources) e Spese (Sinks)

| Fascia di Gioco | Entrate Principali (*Sources*) | Obiettivi di Spesa (*Sinks*) |
| :--- | :--- | :--- |
| **Inizio (Ore 0–2)** | Ortaggi veloci (Ravanello, Lattuga, Carota, Piselli) | Semi di stagione, primi attrezzi (Zappa, Cesoie), primi 1–2 Spaventapasseri |
| **Medio (Ore 2–8)** | Ortaggi estivi scalari (Pomodori, Zucchine), Uova, Miele, prime Mele | Irrigatori, Teli TNT, Pollaio + Recinto + Galline, Compostiera, primi Ulivi |
| **Avanzato (Ore 8–20+)** | **Olio EVO, Vino invecchiato, Formaggi, Tartufi**, raccolti di qualità Pregiata ⭐ | Vigna, Stalla + Capre/Maiali/Mucche, Serra fredda, nuovi Campi sulla Mappa Generale, Arredamento Casa |

### Dinamica dei Prezzi al Mercato (Realismo Leggero)
Per premiare chi pianifica bene senza complicare l'interfaccia:
- **Prezzo Base** fisso e leggibile nell'Almanacco.
- **Bonus Qualità:** Scarsa `0.7×` | Standard `1.0×` | Pregiata ⭐ `1.4×`.
- **Richiesta della Settimana (Opzionale in v0.3+):** Ogni settimana il Mercato evidenzia 2 prodotti molto richiesti (`+25%` prezzo) — spinge il giocatore a variare le colture!

---

## 4. Rete di Sicurezza Anti-Fallimento (*No Soft-Lock*)

Cosa succede se un giocatore spende tutte le monete per piantare pomodori in inverno e gli muoiono tutti dal freddo? Il gioco **non deve mai bloccarsi**:

1. **Raccolta Spontanea (Foraging):** Sui blocchi non ancora bonificati del Campo (o nella Mappa) ricrescono periodicamente erbe selvatiche, legnetti, sassi o bacche vendibili al Mercato per recuperare subito `20–30 🪙`.
2. **Semi Gratuiti da Piante a Seme:** Come definito nel Punto 1, alcune piante (es. lattuga andata a seme, girasoli) rilasciano semi propri.
3. **Aiuto del Mercante:** Se il giocatore si trova con `0 🪙`, `0` semi e `0` raccolti, il Mercato offre gratuitamente un piccolo sacchetto di semi base (es. 3 semi di Ravanello o Cavolo in base alla stagione) per ripartire subito.

# Catalogo & Bilanciamento Agronomico (v2)

Questo documento definisce il modello agronomico del gioco su stagioni confermate da **28 giorni** (1 anno = 112 giorni), bilanciato intorno a una regola d'oro: **realismo autentico ma zero burocrazia**.

---

## 1. Il Giusto Compromesso: Realismo Senza Complicare

Per restare piacevole su Android (sessioni brevi e rilassanti), il realismo va **mostrato visivamente**, non trasformato in tabelle o micromanagement punitivo.

| Meccanica | Cosa **TENIAMO** (Autentico e Divertente) | Cosa **SEMPLIFICHIAMO** (Evitiamo stress) |
| :--- | :--- | :--- |
| **Suolo** | 3 stati visivi chiari: *Incolto*, *Vangato*, *Pronto*; 3 livelli di fertilità (*Povero / Normale / Ricco*) visibili dal colore della terra. | Niente chimica complessa (no valori separati di Azoto/Fosforo/Potassio/pH). |
| **Irrigazione** | Terra asciutta (chiara) vs umida (scura); se piove non serve annaffiare; ristagno solo dopo giorni di pioggia/eccesso. | Niente litri d'acqua precisi da dosare pianta per pianta. |
| **Fuori Stagione** | Libertà di piantare sempre; fuori stagione la pianta cresce piano, rende meno o soffre il gelo (con icone chiare: goccia, fiocco di neve, foglia gialla). | Le piante non muoiono istantaneamente in 1 giorno di freddo leggero: danno sempre un segnale visivo prima. |
| **Rotazione** | Un semplice bonus/malus automatico se alterni i legumi o cambi famiglia sullo stesso appezzamento. | Nessun obbligo punitivo: la terra resta comunque coltivabile. |
| **Animali** | Cibo, acqua/pascolo, raccolta prodotti, pulizia periodica (che dà compost/letame). | Gli animali **non muoiono** se salti un giorno: diventano solo tristi e producono meno finché non li accudisci. |

---

## 2. Progressione Spalmata nelle Ore di Gioco

Tutto il contenuto si sblocca in modo organico seguendo il ritmo della fattoria, così il giocatore impara una cosa alla volta senza mai sentirsi sopraffatto:

- **Ore 0–1 (Il Primo Orto):** Solo 4 attrezzi base (Vanga, Rastrello, Annaffiatoio, Zappa) e 4 semi semplici di stagione (Ravanello, Lattuga, Carota, Piselli). Impari ciclo giorno/notte, acqua e vendita al mercatino.
- **Ore 1–3 (Ritmo delle Stagioni & Erbacce):** Arriva il primo cambio di temperatura/meteo, compaiono le erbacce e si sblocca l'**Almanacco del Contadino**. Si ampliano i semi (Pomodoro, Zucchina, Patata, Fragola) e si impianta il **primo albero da frutto** (Melo o Ciliegio).
- **Ore 3–6 (Primo Allevamento & Circolarità):** Sblocco del **Pollaio (Galline)** + **Compostiera** (impari a rigenerare la terra col concime) e delle **Arnie (Api)** che potenziano orto e alberi. Compaiono i primi **Teli TNT** per proteggere le piante dal freddo.
- **Ore 6–12 (Arboricoltura, Vigna & Stalla):** Sblocco delle **Cesoie da potatura**, dell'**Uliveto** (con accesso al Frantoio per l'Olio EVO) e dei **Filari di Vigna** (vendemmia + piccola cantina per il Vino). Si costruisce la stalla per **Capre** e **Maiali**.
- **Ore 12–20+ (Fattoria Completa & Maestria):** Sblocco della **Mucca** (caseificio avanzato), **Irrigazione a goccia** (per ridurre il lavoro ripetitivo negli orti grandi), **Serra fredda** (per coltivare ortaggi estivi anche in inverno) e colture pregiate/speciali.

---

## 3. Calendario, Stagioni e Clima (28 Giorni/Stagione)

| Stagione | Temp. Media Giorno | Temp. Minima Notte | Eventi Meteo Tipici |
| :--- | :---: | :---: | :--- |
| **Primavera** | 14°C – 22°C | 6°C – 12°C | Piogge frequenti, rare *gelate tardive* (Giorni 1–7: 0°C) |
| **Estate** | 25°C – 34°C | 16°C – 22°C | Sole, siccità, *ondate di calore* (38°C+), temporali |
| **Autunno** | 12°C – 20°C | 5°C – 11°C | Piogge, nebbia, primi freddi a fine stagione |
| **Inverno** | 2°C – 9°C | -4°C – 3°C | *Gelate notturne*, neve, giornate brevi |

**Protezioni Microclimatiche (sbloccabili):**
- **Telo TNT:** `+4°C` sulla minima notturna (salva dalle gelate leggere).
- **Tunnel basso:** `+6°C` e protezione da grandine/vento.
- **Serra fredda:** `+9°C` giorno / `+7°C` notte (mai sotto `+3°C`), ideale per coltivare fuori stagione.
- **Rete ombreggiante:** `-5°C` in estate (per coltivare insalate e spinaci anche ad agosto).

---

## 4. Formula di Crescita e Fuori Stagione

$$\text{Avanzamento Giornaliero} = 1.0 \times F_{\text{temp}} \times F_{\text{acqua}} \times F_{\text{suolo}}$$

- **$F_{\text{temp}}$:** `1.0` in fascia ottimale | `0.4` in fascia tollerata (crescita lenta + resa ridotta del 30–40%) | `0.0` + perdita salute (`-25 HP/giorno`) in fascia critica (gelo o caldo estremo).
- **$F_{\text{acqua}}$:** `1.0` se umido | `0.25` se secco | `0.6` in ristagno prolungato.
- **$F_{\text{suolo}}$:** `0.6` (terra povera) → `1.0` (normale) → `1.15` (concimata/rotata); `-25%` se invasa da erbacce.

---

## 5. Catalogo Ortaggi & Semi (24 Colture)

| Coltura | Famiglia | Stagione Ideale | Temp. Ottimale | Critica (Gelo / Caldo) | Giorni | Raccolta | Acqua | Suolo | Seme / Vendita |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- | :---: | :---: | :---: |
| **Ravanello** | Brassicacee | Prim / Aut | 12–22°C | < 0°C / > 28°C | 4 gg | Unica | Media | -5 | 10 / 25 |
| **Lattuga** | Foglie | Prim / Aut | 12–20°C | < 2°C / > 26°C* | 7 gg | Unica | Alta | -8 | 15 / 40 |
| **Bietola** | Foglie | Prim / Aut / Inv | 8–22°C | < -4°C / > 30°C | 8 gg | Scalare (×3) | Media | -10 | 20 / 22 |
| **Spinacio** | Foglie | Aut / Inv | 6–16°C | < -5°C / > 24°C* | 8 gg | Scalare (×3) | Media | -8 | 20 / 22 |
| **Carota** | Radici | Prim / Aut | 14–22°C | < -2°C / > 30°C | 10 gg | Unica | Media | -10 | 20 / 55 |
| **Fragola** | Frutti di bosco | Primavera | 14–24°C | < 0°C / > 32°C | 12 gg | Scalare (perenne) | Alta | -12 | 55 / 32 |
| **Piselli** | **Legumi** | Primavera | 12–20°C | < 0°C / > 27°C | 10 gg | Scalare (ogni 3g) | Media | **+20** | 30 / 25 |
| **Patata** | Solanacee | Prim / Est | 15–24°C | < 2°C / > 32°C | 14 gg | Unica (×4) | Media | -18 | 35 / 22 (×4) |
| **Cipolla** | Bulbi | Prim / Est | 14–25°C | < -3°C / > 34°C | 14 gg | Unica | Bassa | -10 | 25 / 65 |
| **Pomodoro** | Solanacee | Estate | 20–30°C | < 6°C / > 38°C | 12 gg | Scalare (ogni 3g) | Alta | -20 | 45 / 35 |
| **Zucchina** | Cucurbitacee | Estate | 20–30°C | < 8°C / > 37°C | 10 gg | Scalare (ogni 2g) | Alta | -18 | 40 / 28 |
| **Cetriolo** | Cucurbitacee | Estate | 20–30°C | < 8°C / > 36°C | 9 gg | Scalare (ogni 2g) | Alta | -15 | 35 / 24 |
| **Peperone** | Solanacee | Estate | 22–32°C | < 8°C / > 38°C | 15 gg | Scalare (ogni 4g) | Media | -18 | 50 / 45 |
| **Melanzana** | Solanacee | Estate | 22–32°C | < 9°C / > 38°C | 15 gg | Scalare (ogni 4g) | Media | -20 | 50 / 48 |
| **Peperoncino** | Solanacee | Estate | 22–34°C | < 8°C / > 40°C | 14 gg | Scalare (ogni 3g) | Bassa | -12 | 40 / 32 |
| **Fagiolini** | **Legumi** | Estate | 18–28°C | < 7°C / > 35°C | 9 gg | Scalare (ogni 3g) | Media | **+20** | 30 / 26 |
| **Anguria** | Cucurbitacee | Estate | 24–34°C | < 10°C / > 40°C | 18 gg | Unica (grande) | Alta | -25 | 70 / 230 |
| **Girasole** | Cereali/Semi | Estate | 18–32°C | < 4°C / > 38°C | 12 gg | Unica (+semi galline) | Bassa | -15 | 25 / 70 |
| **Zucca** | Cucurbitacee | Est → Aut | 18–28°C | < 5°C / > 36°C | 22 gg | Unica (grande) | Media | -25 | 60 / 220 |
| **Finocchio** | Ombrellifere | Autunno | 12–20°C | < 0°C / > 28°C | 12 gg | Unica | Media | -12 | 25 / 75 |
| **Broccolo** | Brassicacee | Aut / Inv | 6–18°C | < -5°C / > 26°C | 13 gg | Unica | Media | -15 | 30 / 85 |
| **Cavolo Verza** | Brassicacee | Aut / Inv | 4–16°C | < -8°C / > 25°C | 14 gg | Unica | Media | -15 | 30 / 95 |
| **Porro** | Bulbi | Aut / Inv | 4–18°C | < -10°C / > 28°C | 16 gg | Unica | Media | -12 | 30 / 90 |
| **Fave** | **Legumi** | Aut / Inv | 5–18°C | < -4°C / > 26°C | 18 gg | Scalare (×3) | Bassa | **+25** | 25 / 30 |
| **Aglio** | Bulbi | Aut → Prim | 4–22°C | < -10°C / > 33°C | 35 gg** | Unica | Bassa | -8 | 30 / 110 |
| **Basilico** | Aromatiche | Estate | 20–30°C | < 10°C / > 36°C | 6 gg | Scalare (foglie) | Alta | -5 | 20 / 18 |

*(Totale: 26 colture pronte, divise in modo equilibrato su tutte e 4 le stagioni, inclusa una selezione invernale reale che rende giocabile e interessante anche l'inverno!)*

---

## 6. Alberi da Frutto & Vigna (Arboricoltura e Filari)

| Pianta | Spazio / Tipo | Maturazione | Potatura | Fioritura | Raccolta | Freddo / Secco | Prodotto & Trasformazione |
| :--- | :--- | :---: | :--- | :--- | :--- | :---: | :--- |
| **Vigna (Vite)** | **Filare** (1×N tile collegati) | 28 gg | **Inverno** (indispensabile) | Tarda Primavera | **Autunno** (Vendemmia) | Alta / Alta | **Uva** → **Mosto / Vino** (Cantina/Botti), Uva passa |
| **Melo** | Albero (`2×2`) | 28 gg | Inverno | Primavera | Fine Est. / Autunno | Alta / Media | **Mele** → Sidro, Marmellata |
| **Ulivo** | Albero (`2×2`) | 42 gg | Fine Inverno | Tarda Primavera | Autunno | Media (-5°C) / **Altissima** | **Olive** → **Olio Extravergine** (Frantoio) |
| **Ciliegio** | Albero (`2×2`) | 28 gg | Inverno | Inizio Primavera | Tarda Primavera | Alta / Media | **Ciliegie** → Confettura |
| **Pesco** | Albero (`2×2`) | 24 gg | Inverno | Primavera | Estate | Media / Media | **Pesche** → Succo, Sciroppate |
| **Fico** | Albero (`2×2`) | 28 gg | Inverno (leggera) | 2 cicli | Inizio + Fine Estate | Media / Alta | **Fichi** → Fichi secchi |
| **Limone** | Albero (`2×2`) | 28 gg | Primavera | Prim. + Aut. | Inverno / Primavera | **Bassa** (< 0°C soffre) | **Limoni** → Marmellata, Limoncello |

### Focus: La Vigna (Filari)
- A differenza degli alberi singoli, la **Vigna** si pianta in **filari continui** con pali e fili di ferro (visivamente bellissima in 2D pixel art!).
- **Ciclo autentico ma snello:**
  1. **Inverno:** Potatura dei tralci secchi con le cesoie (`+35%` qualità dell'uva).
  2. **Primavera/Estate:** Crescita foglie e grappoli; solo se piove molto per più giorni può servire 1 trattamento di rame/zolfo (semplice tap con spruzzatore).
  3. **Autunno:** **Vendemmia!** I grappoli si portano alla pressa/botte per produrre **Vino** (che può anche invecchiare in botte per aumentare di valore).

---

## 7. Allevamento Circolare Completo (5 Animali)

| Animale | Ricovero | Alimentazione | Produzione Principale | Ruolo Ecologico / Circolarità | Sblocco Consigliato |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Gallina** | Pollaio | Granaglie / Girasole / Scarti orto | **Uova** (1/giorno) | **Pollina** → Compost ricco (`+40 fertilità`) | Ore 3–5 |
| **Api (Arnia)** | Arnia in legno | Fiori dell'orto e alberi vicini | **Miele** (ogni 6 gg in Prim-Est) | **Impollinazione (+25% resa)** a orto e frutteto nel raggio | Ore 4–6 |
| **Capra** | Stalla piccola | Erba/Pascolo (Prim-Aut), Fieno (Inv) | **Latte di capra** → Formaggio fresco | **Letame** (`+35 fertilità`), mangia anche erbacce/potature | Ore 6–9 |
| **Maiale** | Recinto / Porcile | **Scarti dell'orto, frutta caduta, patate/zucche** | **Tartufi** (se pascola vicino agli alberi in Autunno) + prodotti di fattoria* | **Riciclatore perfetto:** trasforma ortaggi stressati/fuori stagione in ottimo **Letame** e risorse! | Ore 8–12 |
| **Mucca** | Stalla grande | Molto Pascolo (Prim-Aut) / Fieno (Inv) | **Latte vaccino abbondante** → Burro, Formaggio stagionato | **Grande produttrice di Letame** (sostiene orti grandi e vigneti) | Ore 12–16 |

*\*Nota di tono (cozy vs realismo):* Come in *Stardew Valley*, il maiale può essere gestito in chiave cozy (cerca tartufi sotto gli alberi e ricicla gli scarti producendo letame prezioso) senza dover inserire la macellazione, che su mobile restringerebbe il pubblico e il rating PEGI.

---

## 8. Schema JSON Aggiornato (Esempio con Vigna)

```json
{
  "crops": [
    {
      "id": "pomodoro",
      "name": "Pomodoro",
      "family": "solanacee",
      "ideal_seasons": ["estate"],
      "temp": { "germination_min": 14, "critical_min": 6, "optimal_min": 20, "optimal_max": 30, "critical_max": 38 },
      "growth_days": 12,
      "multi_harvest": true,
      "regrow_days": 3,
      "water_need": "high",
      "soil_fertility_delta": -20,
      "seed_price": 45,
      "sell_price": 35
    }
  ],
  "perennials": [
    {
      "id": "vigna",
      "name": "Vite da Vino",
      "type": "trellis_row",
      "maturity_days": 28,
      "prune_season": "inverno",
      "bloom_season": "primavera",
      "harvest_season": "autunno",
      "frost_tolerance_c": -12,
      "drought_resistant": true,
      "base_yield": 8,
      "product_id": "uva",
      "processed_product_id": "vino"
    },
    {
      "id": "ulivo",
      "name": "Ulivo",
      "type": "tree_2x2",
      "maturity_days": 42,
      "prune_season": "inverno",
      "bloom_season": "primavera",
      "harvest_season": "autunno",
      "frost_tolerance_c": -5,
      "drought_resistant": true,
      "base_yield": 12,
      "product_id": "olive",
      "processed_product_id": "olio_evo"
    }
  ]
}
```

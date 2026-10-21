# Car Evolve 3D — Monete, cancelli di evoluzione e ostacoli

Giochino mobile 3D hyper-casual in **Godot 4.3+**, ispirato al genere di
Car Evolve. Ambiente 3D giocabile con pista, bordi laterali rialzati, terreno
verde, cielo con prospettiva verso l'orizzonte, illuminazione con ombre leggere
e auto stilizzata costruita con mesh semplici.

La meccanica principale è giocabile: **coppie di cancelli** che evolvono o
fanno regredire l'auto, **ostacoli** da schivare e **monete** da raccogliere
lungo la pista. Il giocatore sceglie quale cancello attraversare sterzando,
evitando coni, barriere, restringimenti e blocchi mobili; ogni moneta raccolta
aggiorna il totale della corsa e il saldo locale permanente. Il livello di
evoluzione (`evolution_level`) cambia con limiti minimo e massimo e ogni livello
ha il **proprio modello 3D**: dal rottame all'hypercar futuristica.

## Requisiti

- Godot 4.3 o superiore (edizione standard, senza Mono)
- Nessun asset esterno: tutto è generato con primitive 3D e materiali condivisi
- Funziona offline (nessuna risorsa remota, nessun servizio)

## Esecuzione

```bash
godot --editor --path .               # apre l'editor; avvia il progetto con F5
godot --path .                        # avvia direttamente la scena principale
godot --headless --path . --import    # importa/valida le risorse da CLI
```

La scena principale è `scenes/Main.tscn` (già impostata in `project.godot`).

## Cancelli ed evoluzione

- Ogni fila è una **coppia di cancelli affiancati** che si dividono la
  carreggiata: uno positivo (verde `+1`, blu `+2`) e uno rosso negativo (`-1`).
- Il punto di separazione cambia a ogni fila, quindi a volte conviene sterzare
  a sinistra e a volte a destra: entrambe le opzioni sono sempre raggiungibili
  entro i limiti laterali dell'asfalto.
- Il valore è scritto sopra ogni arcata (`+2`, `-1`, ...) ed è leggibile da
  lontano: la prima fila nasce a 70 m, le successive ogni 48 m.
- L'attraversamento è rilevato in 3D: si calcola dove il segmento percorso
  dall'auto interseca il piano verticale del cancello e si verifica che la X
  di intersezione cada dentro il varco. Funziona anche con passi grandi,
  movimento diagonale in un solo frame e ovviamente a qualsiasi frame rate.
- L'effetto viene applicato **una sola volta**: il cancello e il suo compagno
  di fila si spengono subito dopo l'attraversamento e non possono riattivarsi.
- Il livello è centralizzato in `GameManager.evolution_level` e si modifica
  solo con `GameManager.apply_evolution()`: i limiti sono
  `GameConfig.EVOLUTION_MIN_LEVEL` (0) e `EVOLUTION_MAX_LEVEL` (5), l'avvio è
  a 1. L'HUD mostra `EVOLUZIONE n/5` e un messaggio di feedback.
- L'auto reagisce al livello **cambiando modello**: ogni livello ha la propria
  silhouette, i propri colori e le proprie statistiche (vedi
  [Evoluzioni visive dell'auto](#evoluzioni-visive-dellauto)). La barra di
  cinque spie continua a indicare a colpo d'occhio il livello raggiunto.

## Evoluzioni visive dell'auto

`evolution_level` (0..5) è l'unica fonte di verità: da quel numero derivano
il modello 3D mostrato, il nome a schermo, i colori e le statistiche di gioco.
Non esiste uno stato visivo separato, quindi l'aspetto non può restare
indietro rispetto al livello reale.

| Livello | Stadio | Silhouette | Velocità | Sterzo |
| --- | --- | --- | --- | --- |
| 0 | ROTTAME | microcar sgangherata, alta e corta, ruota di scorta sul tetto | ×0.85 | ×0.85 |
| 1 | UTILITARIA | compatta a due volumi, spigolosa, tetto alto (partenza) | ×1.00 | ×1.00 |
| 2 | BERLINA | tre volumi, più lunga, abitacolo vetrato e profili cromati | ×1.12 | ×1.10 |
| 3 | SPORTIVA | coupé bassa, cofano lungo, coda fastback, doppio scarico | ×1.24 | ×1.20 |
| 4 | SUPERCAR | larghissima, motore centrale, prese d'aria, grande alettone | ×1.36 | ×1.30 |
| 5 | HYPERCAR | targa bassa, cupola in vetro, pinne, barre e pattini luminosi | ×1.50 | ×1.45 |

Ogni stadio cambia proporzioni, volumi e dettagli (non solo il colore): i
test verificano che i sei ingombri siano tutti diversi.

### Come funziona il cambio di stadio

1. `GameManager.apply_evolution()` aggiorna `evolution_level` (con i limiti
   min/max) ed emette `evolution_changed(livello, delta, profile)`.
2. `CarController` riceve il segnale, applica le **statistiche** dello stadio
   (velocità = `forward_speed × speed_multiplier`, reattività dello sterzo =
   `lateral_response × handling_multiplier`, limiti laterali ricalcolati
   sull'ingombro reale) e chiede al direttore di aggiornare il modello.
3. `CarEvolutionDirector` (nodo `CarVisual`, figlio dell'auto) sostituisce
   **subito** il modello e avvia una breve animazione (≈0,55 s): scalatura
   rapida con rimbalzo, lampo di luce, lampeggio delle parti emissive e onda
   d'urto a terra.
4. `HUD` mostra nome e statistiche dello stadio; il nome fa un "pop" al centro
   dello schermo.

L'animazione non blocca nulla: gira in `_process` su un nodo figlio e non
tocca input, posizione, sterzo o velocità. Richiedere lo stesso livello è una
no-op (nessuna ricostruzione, nessuna animazione).

### Sostituire i modelli provvisori (pronto per il futuro)

I blockout attuali sono generati da `CarModelBuilder` con primitive
(BoxMesh/CylinderMesh/SphereMesh). Per passare a modelli veri **non serve
riscrivere la logica di evoluzione**: i cancelli, l'HUD, `GameManager` e i
test non conoscono la geometria.

- **Singolo livello**: impostare `CarEvolutionProfile.model_scene` con la
  scena (o il `.glb` importato). La radice deve essere un `Node3D` rivolto
  verso -Z.
- **Tutti i livelli**: compilare `config/car_model_library.tres` (risorsa
  `CarModelLibrary`), che ha uno slot `PackedScene` per livello: gli slot
  vuoti continuano a usare il blockout procedurale.

Contratto dei modelli esterni: radice `Node3D`, rivolta verso -Z, con le
ruote come figli che iniziano per `Wheel` (oppure nel gruppo `car_wheel`).
Le ruote vengono cercate dopo l'inserimento nell'albero e collegate
automaticamente a rotazione e sterzata.

### Dove si tarano gli stadi

| Parametro | Dove | Effetto |
| --- | --- | --- |
| `EVOLUTION_STAGE_NAMES` | `GameConfig.gd` | nome mostrato nell'HUD per livello |
| `EVOLUTION_COLORS` | `GameConfig.gd` | colore della carrozzeria per livello |
| `EVOLUTION_SPEED_MULTIPLIERS` | `GameConfig.gd` | moltiplicatore di velocità per livello |
| `EVOLUTION_HANDLING_MULTIPLIERS` | `GameConfig.gd` | moltiplicatore della reattività dello sterzo |
| `EVOLUTION_TRANSFORM_DURATION` | `GameConfig.gd` | durata dell'animazione di trasformazione |
| proporzioni e silhouette | `CarEvolutionCatalog._apply_shape()` | dimensioni di ogni stadio (metri) |

### Taratura dei cancelli (`scripts/core/GameConfig.gd`)

| Costante | Default | Effetto |
| --- | --- | --- |
| `GATE_FIRST_ROW_DISTANCE` | 70 m | Distanza della prima fila dall'avvio |
| `GATE_ROW_SPACING` | 48 m | Distanza tra due file consecutive |
| `GATE_ROW_COUNT` | 3 | File mantenute in gioco (riciclate in fondo) |
| `GATE_PASSED_OFFSET` | 26 m | Quando una fila superata torna davanti |
| `GATE_MIN_WIDTH` | 2.4 m | Larghezza minima di un varco (passaggio sempre possibile) |
| `GATE_HEIGHT` | 2.75 m | Altezza dell'arcata, per la visibilità da lontano |
| `GATE_SPLIT_PATTERN` | `[-1.3, 0, 1.3, 0.7, -0.7]` | Posizione della separazione tra i due cancelli |
| `GATE_POSITIVE_PATTERN` | `[1, 2, 1, 2, 1]` | Valori dei cancelli positivi (2 = blu) |
| `EVOLUTION_MIN_LEVEL` / `MAX_LEVEL` | 0 / 5 | Limiti del livello di evoluzione |

I cancelli non sono figli dei segmenti di pista (che vengono riciclati sotto
l'auto): sono nodi in coordinate mondo gestiti da `GateManager`, così restano
fermi rispetto alla strada e non si sovrappongono mai.

## Ostacoli (Fase 3)

Ogni corridoio di cancelli ha **una fila di ostacoli** ancorata 24 m oltre il
piano dei cancelli (`OBSTACLE_CORRIDOR_OFFSET`): le due meccaniche non si
sovrappongono mai (distanza minima 16 m garantita) e le file di ostacoli
restano distanziate di 48 m tra loro. `ObstacleManager` genera, rileva gli
urti e ricicla le file in modo deterministico, in coordinate mondo come i
cancelli.

### I quattro tipi

| Tipo | Formazione | Comportamento | Penalità (una sola) |
| --- | --- | --- | --- |
| Coni | fila di coni da un lato | **non solidi**: l'auto passa, il cono si abbatte (animazione di caduta) | velocità ×0.75 per 0.55 s |
| Barriera | blocco largo da un lato | **solida**: l'auto si ferma sulla faccia, la sfonda dopo l'urto (detriti) | velocità ×0.45 per 1.15 s |
| Restringimento | due muri con varco centrale | **solidi**: passaggio di precisione | velocità ×0.55 per 0.95 s |
| Blocco mobile | blocco che fa la spola sulla carreggiata | **solido e predicibile**: moto a pendolo, si abbatte dopo 3 contatti | **−1 livello di evoluzione** |

- **Mai entrambe le penalità**: ogni pezzo ha un solo canale configurato
  (`penalty_kind`), applicato una volta per collisione (cooldown 0.8 s). La
  regressione passa da `GameManager.apply_evolution()`, il rallentamento da
  `CarController.apply_speed_penalty()` (tiene la frazione peggiore, recupera
  con plateau + curva morbida).
- **Nessun attraversamento dei solidi**: la collisione è un test segmento/rect
  sottopassato (substep ≤ 0.35 m) contro il rect dell'ostacolo allargato
  dell'ingombro reale dell'auto ruotata; i blocchi mobili sono interpolati tra
  la posizione precedente e la corrente. All'urto l'auto viene riportata sulla
  faccia di contatto (o spinta lateralmente se è il blocco a scorrerle addosso).
- **Feedback di collisione**: scuotimento dell'auto (0.38 s), lampeggio rosso
  dell'HUD, messaggio `URTO! ...`, effetto 3D di scintille/urto e animazione
  del pezzo (cono abbattuto, barriera/muro sfondati con detriti).
- **Varchi sempre sufficienti**: il varco più largo di ogni fila è ≥
  `OBSTACLE_GAP_MIN` (2.6 m) e l'ingombro massimo dell'auto è ≈ 2.31 m; i
  blocchi mobili lasciano sempre ≥ 5.5 m liberi. Tra due file c'è sempre il
  tempo di attraversare l'intera carreggiata anche alla velocità peggiore.

### Difficoltà progressiva

La difficoltà sale con la distanza percorsa: 0 fino a 150 m
(`OBSTACLE_EASY_DISTANCE`), poi cresce fino a 1 a 1200 m
(`OBSTACLE_RAMP_DISTANCE`). Con la difficoltà:

- i varchi si restringono da 3.6 m a 2.6 m (mai sotto il minimo);
- a ≥ 0.30 compaiono i **restringimenti**, a ≥ 0.55 i **blocchi mobili**
  (prima solo coni e barriere);
- i blocchi mobili accelerano da 1.5 a 2.8 m/s (velocità comunque contenute).

La generazione è deterministica (hash del seriale della fila): stessa fila,
stesso layout, verificabile dai test.

### Taratura degli ostacoli (`scripts/core/GameConfig.gd`)

Tutti i parametri sono nella sezione `OBSTACLE_*`: distanze di ancoraggio e
clearance, larghezze dei varchi (`OBSTACLE_GAP_WIDE`/`GAP_MIN`), curve di
difficoltà (`OBSTACLE_EASY_DISTANCE`/`RAMP_DISTANCE`/`TIER_NARROW`/
`TIER_MOVING`), velocità dei mobili (`MOVING_SPEED_SLOW`/`FAST`), penalità per
tipo (`CONE_/BARRIER_/WALL_SPEED_FACTOR` e `_DURATION`,
`MOVING_EVOLUTION_STEP`), feedback (`SHAKE_*`, colori) e dimensioni dei pezzi
(`*_HALF_EXTENTS`). La velocità massima dell'auto resta quella di
`driving_tuning.tres` (14 m/s × moltiplicatore di stadio): la progressione è
controllata e non dipende dagli ostacoli.

## Monete e punteggio

`CoinManager` mantiene un pool di monete davanti all'auto e lo ricicla lungo
la pista. Il layout usa posizioni laterali alternate; il pickup è rilevato con
la distanza minima tra il percorso dell'auto nel frame e la moneta, quindi non
si perde una raccolta tra due frame. Ogni `Coin` passa atomicamente da
**disponibile** a **raccolta**: le collisioni successive vengono ignorate.
La moneta sale e si restringe in un'animazione, mentre l'HUD aggiorna subito il
contatore e fa un breve pop.

Sono due valori distinti:

- `GameManager.session_coins`: monete raccolte nella corsa corrente, mostrate
  come **MONETE CORSA** e usate nel calcolo del punteggio finale;
- `GameManager.permanent_coins`: saldo accumulato tra le corse, mostrato come
  **SALDO PERMANENTE** e salvato in `user://giocomobile_save.cfg` tramite
  `ConfigFile` di Godot. Se il file non esiste al primo avvio, il saldo parte
  da zero e viene creato un file valido. Ogni pickup salva subito il saldo,
  senza aspettare la chiusura o una schermata negozio.

Quando viene chiamato `GameManager.end_game()`, il riepilogo HUD mostra il
punteggio finale calcolato così:

```
floor(distanza_m × SCORE_POINTS_PER_METER)
+ livello_massimo × SCORE_POINTS_PER_EVOLUTION_LEVEL
+ monete_corsa × SCORE_POINTS_PER_COIN
```

I valori predefiniti sono 10 punti per metro, 250 per ogni livello massimo
dell'auto raggiunto e 50 per moneta. Spawn, spaziatura, corsie, raggio di
raccolta, valore delle monete, animazione e pesi del punteggio si configurano
nella sezione **Monete e punteggio** di `scripts/core/GameConfig.gd`. Non è
presente un negozio: traguardo e ricompense raccolte sono gestiti dal ciclo di
partita descritto qui sotto.

## Ciclo completo della partita

La scena principale parte da un menu verticale con titolo, saldo permanente e
pulsante touch **GIOCA**. Il menu non avvia la corsa toccando lo sfondo. Dopo
GIOCA compare un conto alla rovescia di circa 2,4 secondi (3, 2, 1), poi l'auto
parte automaticamente. Il traguardo è fissato a **800 m** (`RUN_DISTANCE_METERS`)
e la progressione viene congelata al raggiungimento della distanza massima.

La schermata finale distingue la vittoria dal game over e mostra punteggio,
distanza, monete raccolte, livello finale dell'auto, picco evolutivo e saldo
permanente. **RIGIOCA** ripristina auto, pista, cancelli, ostacoli, monete e dati
di corsa; **MENU** riporta al menu. Il saldo permanente resta salvato tra replay
e riavvii. Le collisioni previste dal progetto applicano penalità non letali;
`GameManager.fail_run()` è disponibile come punto d'ingresso per una futura
collisione fatale o condizione di sconfitta.

Il pulsante **PAUSA** in alto a destra congela la scena e apre i controlli
**RIPRENDI** e **MENU**. La UI continua a ricevere input mentre il mondo è
fermato. La progressione e i pickup sono validi solo nello stato di corsa:
una volta conclusa la partita non possono modificare il riepilogo o duplicare
ricompense.

Il flusso è gestito da stati espliciti in `GameManager` (`IDLE`, `COUNTDOWN`,
`PLAYING`, `PAUSED`, `FINISHED`) e da un esito (`VICTORY` o `DEFEAT`), non da
flag indipendenti.

## Controlli

- **Smartphone**: dal menu premi **GIOCA**, poi trascina il dito a
destra/sinistra per sterzare. Premi **PAUSA** per fermarti e **RIPRENDI** per
continuare.
- **Desktop (test)**: premi **GIOCA**, trascina con il tasto sinistro del
mouse oppure usa le frecce ←/→ o i tasti A/D. **Esc** mette in pausa e riprende.
- Dopo l'avvio l'auto avanza sempre da sola lungo la pista. Quando il dito
  (o il mouse) viene rilasciato mantiene la posizione laterale raggiunta;
  nessuna inerzia residua e nessun ritorno al centro.
- Lo sterzo è relativo al trascinamento, interpolato nel tempo e limitato
  all'asfalto: l'auto (compresi gli angoli durante la sterzata) non può
  oltrepassare i cordoli.
- La telecamera segue l'auto lateralmente, quindi l'auto resta stabile al
  centro dell'inquadratura ed è la pista a scorrere.

## Taratura dei controlli

Tutti i parametri di guida sono centralizzati in
`config/driving_tuning.tres` (risorsa `DrivingTuning`, modificabile anche
dall'inspector di Godot). Non serve toccare la logica negli script.

| Parametro | Unità | Default | Effetto |
| --- | --- | --- | --- |
| `forward_speed` | m/s | 14.0 | Velocità di avanzamento automatico |
| `drag_sensitivity` | m / larghezza schermo | 7.0 | Metri percorsi trascinando l'intera larghezza dello schermo |
| `keyboard_lateral_speed` | m/s | 11.0 | Velocità dello sterzo con frecce/A-D |
| `lateral_response` | 1/s | 22.0 | Reattività dell'interpolazione laterale (più alta = più immediata) |
| `max_lateral_speed` | m/s | 26.0 | Limite di sicurezza contro scatti (0 = nessun limite) |

Il drag viene normalizzato sulla larghezza del viewport (540 px nel progetto),
quindi la stessa corsa del dito produce lo stesso spostamento su telefoni con
risoluzioni diverse. L'avanzamento e lo sterzo usano il tempo delta e
un'interpolazione esponenziale: il comportamento non dipende dagli FPS.

I limiti laterali non sono un numero fisso: `CarController` li calcola
dall'ingombro reale dell'auto ruotata al massimo (`CAR_HALF_WIDTH`,
`CAR_HALF_LENGTH`, `CAR_MAX_STEER_YAW`, `CAR_EDGE_MARGIN` in `GameConfig.gd`).
Le ruote sono la parte più larga, quindi anche l'ingombro massimo resta dentro
la carreggiata.

## Rifinitura visiva e audio (Fase 5)

La passata di rifinitura non cambia nessuna regola: distanze, valori dei
cancelli, penalità, monete, punteggio e stati del gioco restano quelli
descritti sopra. Sono cambiati solo materiali, illuminazione, modelli, UI,
animazioni e suoni — tutti generati a runtime, senza asset esterni.

### Materiali, luci e ombre

- `GameConfig.gd` contiene l'intera palette (`COLOR_*`): asfalto e prato,
  cordoli, alberi, carrozzeria per stadio, cancelli, ostacoli, traguardo e UI.
- `MaterialFactory.gd` crea e mette in cache i materiali condivisi: vernice
  con clearcoat, vetro, cerchioni, materiali emissivi "unici" (per le parti che
  lampeggiano) e materiali traslucidi per pannelli e onde.
- `GameRoot.gd` imposta cielo procedurale, esposizione FILMIC, leggera
  saturazione e nebbia di profondità morbida; il sole ha ombre a due split con
  distanza ridotta, quindi restano nitide attorno all'auto senza costare
  quanto una shadow map lunga. **Niente SSAO, niente glow**: su telefoni di
  fascia media costano più di quanto rendano.

### Pista e scenografia

- I segmenti alternano due toni d'asfalto e hanno cordoli bicolore, fascia
  chiara di bordo, linee di corsia e catarifrangenti.
- Erba e fiori sono `MultiMesh` (un draw call per tipo e per segmento), con
  alberi low-poly e cespugli distribuiti fuori dai cordoli.
- Il traguardo (`scripts/track/FinishLine.gd`) è **solo scenografia**: una
  striscia a scacchiera, due piloni e un arco con la scritta "TRAGUARDO",
  posizionato da `GameRoot` a `car.z - RUN_DISTANCE_METERS` a ogni corsa. La
  vittoria resta decisa da `GameManager`.

### Cancelli, monete e ostacoli

- I cancelli sono verdi/blu (positivi) e rossi (negativi), con piloni,
  striscia luminosa, trave, soglia sull'asfalto, pannello traslucido e un
  cartello "pillola" sempre rivolto alla telecamera con il valore (`+1`,
  `+2`, `-1`). All'attraversamento l'arcata fa un piccolo pop, il pannello
  svanisce e parte un'onda a terra: nessuna luce aggiuntiva.
- Le monete hanno disco, anello e rilievo centrale; ruotano e galleggiano.
  Alla raccolta compaiono un anello luminoso in espansione e un pop sul
  contatore, senza particelle.
- Ogni ostacolo ha dettagli coerenti (bande bianche sul cono, strisce e
  catarifrangenti sulla barriera, strisce diagonali sul blocco, fascia
  luminosa sul blocco mobile). L'urto resta non invasivo: scuotimento breve
  dell'auto, flash HUD tenue, anello a terra con quattro scintille.

### Auto: sei silhouette leggibili

`CarModelBuilder.gd` costruisce sei modelli distinti (rottame, utilitaria,
berlina, coupé, supercar, hypercar) con proporzioni diverse — non solo colore:
minicar alta e corta, hatchback compatta, berlina a tre volumi, coupé bassa,
supercar a cuneo, hypercar bassissima con pinne e barre luminose. Ogni stadio
ha vernice con clearcoat, vetri, cerchioni, mozzoni, targa, luci diurne e una
barra di spie che si accende fino al livello corrente.

La trasformazione (`CarEvolutionDirector.gd`) dura circa mezzo secondo:
scala con rimbalzo, leggero squash e saltello, lampo di luce breve e onda a
terra. Tutto avviene in `_process` e non tocca input, velocità o posizione:
i comandi restano reattivi durante l'animazione.

### Interfaccia

`scripts/ui/UITheme.gd` raccoglie lo stile (tipografia con outline, pulsanti
touch da almeno 72 px, pannelli arrotondati, barre di progresso, icone
procedurali); `HUD.gd` compone il layout verticale:

1. barra di stato in alto: distanza, monete, barra di avanzamento, livello,
   saldo e cinque spie colorate;
2. pila "stadio attuale" con nome grande, sottolineatura animata e statistiche;
3. pillola di feedback per cancelli e urti (svanisce da sola in ~1,4 s);
4. suggerimento di sterzo in basso, visibile solo durante la corsa.

Menu, countdown, pausa e riepilogo compaiono in dissolvenza + scala morbida;
i testi chiave hanno un piccolo "pop". Nessuna animazione blocca i pulsanti e
tutte durano meno di mezzo secondo.

### Audio procedurale e silenziamento

`scripts/core/SfxDirector.gd` sintetizza in PCM16 mono 22 kHz, una sola volta
all'avvio, sei effetti brevi: moneta, evoluzione, regressione, urto, vittoria,
sconfitta e click dei pulsanti. Usa un pool di sei `AudioStreamPlayer`
riutilizzati, un intervallo minimo tra due monete (niente raffiche) e nessun
file audio da importare.

Lo stato dell'audio è persistente in `user://giocomobile_audio.cfg` e si
attiva/disattiva dai pulsanti **AUDIO ON/OFF** del HUD, del menu e della pausa;
in modalità muto nessun suono viene avviato e i player attivi vengono fermati.
Per cambiare volume o timbro: `AUDIO_SFX_VOLUME_DB`, `AUDIO_VOICE_COUNT`,
`AUDIO_SAMPLE_RATE`, `AUDIO_COIN_MIN_INTERVAL` in `GameConfig.gd`.

### Taratura rapida della rifinitura

| Parametro | Dove | Effetto |
| --- | --- | --- |
| `UI_APPEAR_DURATION` / `UI_POP_DURATION` | `GameConfig.gd` | durata di comparsa pannelli e pop dei testi |
| `GATE_FLASH_DURATION` / `GATE_FLASH_ALPHA` | `GameConfig.gd` | lampo a schermo all'attraversamento |
| `EVOLUTION_TRANSFORM_DURATION` | `GameConfig.gd` | durata della trasformazione dell'auto |
| `OBSTACLE_IMPACT_DURATION` / `OBSTACLE_MAX_EFFECTS` | `GameConfig.gd` | durata e numero massimo di effetti d'urto |
| `GOLD_ENERGY_*`, `SHOCKWAVE_*`, `FLASH_LIGHT_*` | `FinishLine.gd`, `CarEvolutionDirector.gd` | intensità di bagliori e onde |
| `AUDIO_*` | `GameConfig.gd` | volume, voci, campionamento e rata delle monete |

## Verifica manuale (dopo la rifinitura)

Con il motore disponibile, oltre ai test headless:

1. **Menu**: titolo, striscia a scacchiera, saldo, GIOCA grande e pulsante
   audio; la card compare in dissolvenza. Il pulsante audio cambia testo e
   colore e resta memorizzato dopo il riavvio.
2. **Corsa**: l'auto resta al centro, la pista scorre, lo stadio in alto è
   leggibile, le cinque spie colorate corrispondono al livello.
3. **Cancelli**: si distinguono a colpo d'occhio verde/blu e rosso; il valore è
   leggibile a 30-40 m; attraversandone uno compaiono pop, onda a terra e
   pillola di feedback; l'altro cancello della coppia si spegne.
4. **Evoluzione**: passando di livello il modello cambia subito, con pop,
   saltello, lampo breve e suono; sterzo e velocità rispondono durante
   l'animazione. Cinque stadi chiaramente diversi.
5. **Monete**: rotazione e galleggiamento fluidi; alla raccolta anello
   luminoso, pop del contatore e blip breve (non ripetuto a raffica).
6. **Ostacoli**: ogni tipo è riconoscibile; l'urto dà scuotimento, flash
   tenue, messaggio "URTO!" e un effetto a terra che si spegne da solo.
7. **Traguardo**: l'arco a scacchiera compare davanti all'auto, la scritta è
   leggibile; la vittoria arriva esattamente a 800 m, con jingle breve.
8. **Riepilogo e pausa**: card che compaiono in dissolvenza, testi non
   troncati, RIGIOCA/MENU/RIPRENDI reattivi; nessun suono in modalità muto.
9. **Prestazioni**: su un telefono di fascia media la corsa resta fluida
   (nessun glow, nessun SSAO, effetti limitati e a vita breve).

## Struttura

```
project.godot            # orientamento portrait 9:16 (540x960), renderer mobile
config/
  driving_tuning.tres    # parametri centralizzati di velocità e sensibilità
  car_model_library.tres # slot (opzionali) dei modelli 3D definitivi per livello
scenes/
  Main.tscn              # scena principale: cielo, sole con ombre, camera, sottosistemi
  Car.tscn               # auto del giocatore: CarController + nodo CarVisual (modello)
  HUD.tscn               # UI touch-first (CanvasLayer): menu, corsa e riepilogo finale
scripts/
  core/
    GameConfig.gd        # dimensioni pista/auto, camera, palette colori
    DrivingTuning.gd     # risorsa dei parametri di guida (velocità/sensibilità)
    GameRoot.gd          # bootstrap: cielo procedurale, luce/ombre, camera, audio, traguardo
    MaterialFactory.gd   # materiali low-poly condivisi e cachiati
    SfxDirector.gd       # effetti sonori procedurali (PCM16) con mute persistente
  gameplay/
    GameManager.gd       # FSM: menu, countdown, corsa, pausa, esito e ricompense
    CoinWalletStore.gd   # saldo persistente con ConfigFile in user://
  input/
    InputManager.gd      # input laterale unificato (touch, mouse, tastiera)
  player/
    CarController.gd     # avanzamento automatico + sterzo fluido entro i bordi pista
    CarEvolutionProfile.gd  # un stadio: nome, colori, statistiche, proporzioni, silhouette
    CarEvolutionCatalog.gd  # registro: evolution_level -> profilo (dati + taratura)
    CarModelBuilder.gd   # blockout procedurale dei 6 stadi (primitive + materiali)
    CarModelLibrary.gd   # punto di sostituzione: scena esterna oppure blockout
    CarEvolutionDirector.gd # nodo CarVisual: modello corrente + animazione di trasformazione
    CarModel.gd          # compatibilità: apply_evolution_level() delega al direttore
  track/
    TrackManager.gd      # generazione e riciclo segmenti verso l'orizzonte
    TrackSegment.gd      # segmento: asfalto alternato, cordoli, prato, erba/fiori in MultiMesh
    GateManager.gd       # file di cancelli: spawn, rilevamento 3D, effetti, riciclo
    GateRow.gd           # coppia di cancelli su un piano (struttura dati)
    EvolutionGate.gd     # un cancello: geometria, colore, valore e spegnimento
    ObstacleManager.gd   # file di ostacoli: generazione, collisioni solide, penalità, riciclo
    ObstacleRow.gd       # una fila di ostacoli su un piano (struttura dati + varchi)
    Obstacle.gd          # un ostacolo: tipo, stato, rect di collisione, animazioni
    CoinManager.gd       # generazione, pickup continuo e riciclo delle monete
    Coin.gd              # moneta 3D, stato anti-duplicato, raccolta e onda luminosa
    FinishLine.gd        # traguardo decorativo: scacchiera, piloni, arco e bagliore
  ui/
    HUD.gd               # layout verticale: stato, stadio, feedback, menu, pausa, riepilogo
    UITheme.gd           # stile condiviso: etichette, pulsanti, pannelli, icone procedurali
tests/
  TestRunner.tscn        # test headless di integrazione
  TestRunner.gd          # guida, cancelli, ostacoli, ricompense e ciclo menu-corsa-risultato
```

## Test

```bash
godot --headless --path . --import          # una volta, per scansionare le classi
godot --headless --path . res://tests/TestRunner.tscn
```

Controlli statici eseguibili anche senza il motore installato
(gdtoolkit 4.x: `pip install gdtoolkit==4.5.0`):

```bash
find scripts tests -name '*.gd' -print0 | xargs -0 -n1 gdparse   # sintassi
gdlint scripts tests                                             # lint (.gdlintrc)
```

L'audit del progetto e il piano di refactoring (mantenere / correggere /
sostituire) sono documentati in [`REFACTORING_PLAN.md`](REFACTORING_PLAN.md).

Il test simula `InputEventScreenTouch`/`InputEventScreenDrag` e gli eventi mouse,
verifica il menu GIOCA e il countdown, poi prova avanzamento automatico, drag touch e mouse,
mantenimento della posizione al rilascio, precedenza del touch sul mouse
emulato, bordi destro/sinistro (anche con drag violenti), auto centrata
nell'inquadratura, riciclo contiguo dei segmenti e indipendenza dagli FPS
(30/60/120 Hz simulati).

Per la fase 2 verifica inoltre: coppie di cancelli affiancati senza
sovrapposizioni, entrambe le opzioni raggiungibili, valori e colori coerenti,
distanza di visibilità della prima fila, attraversamento positivo/negativo,
applicazione dell'effetto una sola volta (anche con passi 3D grandi e
diagonali), limiti min/max di `evolution_level`, spegnimento della coppia,
riciclo delle file senza cancelli orfani e aggiornamento visivo dell'auto.

Sulle evoluzioni visive verifica che: ogni livello abbia un profilo valido con
nome, silhouette e statistiche non peggiori; i sei stadi abbiano sei
ingombri diversi (quindi non cambia solo il colore), quattro ruote collegate
e tante spie accese quanto il livello; il modello venga sostituito
immediatamente al cambio di livello (anche attraversando un cancello
positivo o negativo); l'animazione parta, termini da sola e riporti scala e
luci ai valori di riposo; durante la trasformazione lo sterzo continui a
rispondere e l'auto conservi posizione laterale, inclinazione, velocità e
avanzamento; richieste fuori range e richieste ripetute non producano stati
inconsulti; direttore, metadati e `evolution_level` coincidano sempre.

Per la fase 3 (ostacoli) verifica che: le file restino ancorate ai corridoi
dei cancelli con distanze e varchi legali e senza ostacoli orfani; la curva di
difficoltà sia monotona, satura a 1 e introduca i tipi gradualmente; la
barriera arresti l'auto esattamente sulla faccia (mai attraversata), si
sfondi e applichi solo la penalità di velocità, con recupero completo; i coni
si abbattano con animazione e penalità leggera; il blocco mobile resti in
carreggiata con moto predicibile, tolga **esattamente un livello** di
evoluzione senza toccare la velocità e si abbatta dopo più contatti senza
mai bloccare la corsa; il restringimento si attraversi senza urti mirando al
varco e penalizzi solo la velocità se colpito; ogni tipo applichi **una sola**
penalità (velocità XOR evoluzione); il feedback (scuotimento, lampeggio HUD,
messaggio, effetti 3D) parta all'urto e decada da solo a riposo; i blocchi
mobili a difficoltà massima siano sempre schivabili con il giusto tempo; il
riciclo rigeneri file integre senza orfani; e — la prova di giocabilità —
**1500 m con difficoltà da 0 a 1 e 600 m a difficoltà massima** percorsi da
un pilota automatico predittivo con **zero collisioni**, zero compenetrazioni,
layout sempre legale, nessun blocco della corsa, cancelli positivi fino al
livello massimo.
Per il sistema di ricompense verifica inoltre: pool e generazione delle monete,
pickup continuo quando il percorso attraversa una moneta, aggiornamento immediato
dell'HUD, protezione da doppie collisioni, animazione, inizializzazione del
primo salvataggio assente, ricaricamento del saldo in un nuovo manager, separazione
del contatore di corsa dal saldo permanente e formula del punteggio finale.
Verifica anche il ciclo completo: pausa/ripresa, traguardo e vittoria,
schermata di sconfitta, protezione dei risultati, replay con reset del mondo e
ritorno al menu senza perdere il saldo. Esce con codice 0 se tutte le verifiche
passano.

## Build di prova Android

È presente un preset Godot in `export_presets.cfg` chiamato **Android Test (APK)**:
produce `build/android/GiocoMobile-debug.apk`, usa l'orientamento portrait del
progetto e include l'ABI `arm64-v8a`. Il package ID `com.example.giocomobile`
e il nome `GiocoMobile - Test` sono valori provvisori per prove locali, non
identificano una pubblicazione. Il preset non contiene chiavi di firma private
e non è una configurazione di rilascio verificata.

### Strumenti necessari

- Godot 4.x standard (non Mono), con le **Export Templates della stessa
  versione** installate tramite `Editor > Manage Export Templates`.
- JDK 17.
- Android SDK: Android SDK Platform-Tools (per `adb`), Android SDK Build-Tools
  e una Android SDK Platform installata. Impostare i percorsi di JDK e SDK in
  `Editor > Editor Settings > Export > Android`; usare le versioni consigliate
  dalla documentazione della versione Godot installata.
- Un telefono Android arm64 per la prova. Per installazione via USB: abilitare
  Opzioni sviluppatore e Debug USB, installare `adb` tramite Platform-Tools e
  autorizzare il computer sul telefono.

### Generare e installare l'APK

1. Aprire il progetto nell'editor Godot 4.x e verificare che le Export
   Templates corrispondano esattamente alla versione dell'editor.
2. Configurare i percorsi di JDK e Android SDK nelle preferenze Export >
   Android; assicurarsi che i componenti SDK richiesti siano installati.
3. Aprire `Project > Export`, selezionare **Android Test (APK)** e usare
   **Export Project**. Per una prova locale mantenere attiva l'esportazione
   Debug (non esportare un AAB). L'APK deve comparire in
   `build/android/GiocoMobile-debug.apk`.
4. Collegare il telefono e verificare il collegamento:

   ```bash
   adb devices
   adb install -r build/android/GiocoMobile-debug.apk
   ```

   In alternativa, trasferire l'APK sul telefono e aprirlo; Android potrebbe
   richiedere di autorizzare l'installazione da quella sorgente.
5. Avviare **GiocoMobile - Test** e provare menu, input touch, pausa/ripresa,
   una corsa, collisioni, raccolta monete, saldo dopo riavvio e replay in
   orientamento verticale. Il saldo usa lo spazio privato dell'app; cancellare
   dati/disinstallare l'app può eliminarlo.

Per pubblicare, sostituire l'ID `com.example.giocomobile` con un package ID
controllato dal progetto, scegliere versioni/build number appropriati e usare
una chiave di firma release conservata fuori dal repository. Queste modifiche
non sono necessarie per l'APK locale di test. La configurazione presente non
attesta una build eseguita, un'installazione su dispositivo o una verifica di
compatibilità con specifici modelli Android.

## Roadmap

- Fase 3 (completata): cancelli, ostacoli, monete, saldo locale permanente e
  calcolo del punteggio; restano i modelli definitivi delle evoluzioni (già
  sostituibili senza toccare la logica: vedi "Sostituire i modelli")
- Fase 4 (completata): menu, countdown, traguardo, esiti, pausa e replay
- Fase 5 (in corso): rifinitura visiva, UI, animazioni e audio procedurale
  completati; restano il salvataggio del record di punteggio e l'export
  Android/iOS

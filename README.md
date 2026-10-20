# Car Evolve 3D — Cancelli di evoluzione (Fase 2)

Giochino mobile 3D hyper-casual in **Godot 4.3+**, ispirato al genere di
Car Evolve. Ambiente 3D giocabile con pista, bordi laterali rialzati, terreno
verde, cielo con prospettiva verso l'orizzonte, illuminazione con ombre leggere
e auto stilizzata costruita con mesh semplici.

In questa fase è giocabile la meccanica principale: **coppie di cancelli**
che evolvono o fanno regredire l'auto. Il giocatore sceglie quale attraversare
sterzando, e il livello di evoluzione (`evolution_level`) cambia con limiti
minimo e massimo. Ogni livello ha il **proprio modello 3D**: dal rottame
all'hypercar futuristica.

## Requisiti

- Godot 4.3 o superiore (edizione standard, senza Mono)
- Nessun asset esterno: tutto è generato con primitive 3D e materiali condivisi
- Funziona offline (nessuna risorsa remota, nessun servizio)

## Esecuzione

```bash
godot --path .                        # apre l'editor; avvia la scena con F5
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

## Controlli

- **Smartphone**: trascina il dito a destra/sinistra per sterzare, senza
  sollevarlo per mantenere il controllo continuo.
- **Desktop (test)**: tasto sinistro del mouse trascinato; in alternativa
  frecce ←/→ oppure tasti A/D.
- Primo tocco/clic/tasto direzionale: avvia la corsa.
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

## Struttura

```
project.godot            # orientamento portrait 9:16 (540x960), renderer mobile
config/
  driving_tuning.tres    # parametri centralizzati di velocità e sensibilità
  car_model_library.tres # slot (opzionali) dei modelli 3D definitivi per livello
scenes/
  Main.tscn              # scena principale: cielo, sole con ombre, camera, sottosistemi
  Car.tscn               # auto del giocatore: CarController + nodo CarVisual (modello)
  HUD.tscn               # interfaccia minimale (CanvasLayer)
scripts/
  core/
    GameConfig.gd        # dimensioni pista/auto, camera, palette colori
    DrivingTuning.gd     # risorsa dei parametri di guida (velocità/sensibilità)
    GameRoot.gd          # bootstrap: cielo procedurale, luce/ombre, camera prospettica
    MaterialFactory.gd   # materiali low-poly condivisi e cachiati
  gameplay/
    GameManager.gd       # stato di gioco, punteggio e evolution_level centralizzato
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
    TrackSegment.gd      # segmento con pista grigia, cordoli laterali, prato e decorazioni
    GateManager.gd       # file di cancelli: spawn, rilevamento 3D, effetti, riciclo
    GateRow.gd           # coppia di cancelli su un piano (struttura dati)
    EvolutionGate.gd     # un cancello: geometria, colore, valore e spegnimento
  ui/
    HUD.gd               # distanza, monete, stadio di evoluzione (nome e statistiche), feedback
tests/
  TestRunner.tscn        # test headless di integrazione dei controlli
  TestRunner.gd          # touch/mouse, bordi, camera, pista, FPS, cancelli, evoluzione, modelli
```

## Test

```bash
godot --headless --path . --import          # una volta, per scansionare le classi
godot --headless --path . res://tests/TestRunner.tscn
```

Il test simula `InputEventScreenTouch`/`InputEventScreenDrag` e gli eventi mouse,
avvia la partita e verifica: avanzamento automatico, drag touch e mouse,
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
Esce con codice 0 se tutte le verifiche passano.

## Roadmap (fasi successive, non ancora implementate)

- Fase 3: ostacoli, monete raccoglibili, modelli definitivi delle evoluzioni
  (già sostituibili senza toccare la logica: vedi "Sostituire i modelli")
- Fase 4: traguardo, fine partita, schermata di riepilogo
- Fase 5: audio, salvataggio locale del punteggio, export Android/iOS

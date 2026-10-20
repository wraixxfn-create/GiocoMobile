# Car Evolve 3D — Cancelli di evoluzione (Fase 2)

Giochino mobile 3D hyper-casual in **Godot 4.3+**, ispirato al genere di
Car Evolve. Ambiente 3D giocabile con pista, bordi laterali rialzati, terreno
verde, cielo con prospettiva verso l'orizzonte, illuminazione con ombre leggere
e auto stilizzata gialla e nera costruita con mesh semplici.

In questa fase è giocabile la meccanica principale: **coppie di cancelli**
che evolvono o fanno regredire l'auto. Il giocatore sceglie quale attraversare
sterzando, e il livello di evoluzione (`evolution_level`) cambia con limiti
minimo e massimo.

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
- L'auto reagisce al livello cambiando colore della carrozzeria e accendendo
  una barra di cinque spie sul tetto. Funziona con il modello blockout attuale
  (`CarModel.apply_evolution_level()`): quando arriveranno i modelli definitivi
  basterà mantenere quella chiamata.

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
scenes/
  Main.tscn              # scena principale: cielo, sole con ombre, camera, sottosistemi
  Car.tscn               # auto del giocatore (usa driving_tuning.tres)
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
    CarModel.gd          # auto stilizzata gialla e nera realizzata con mesh semplici
  track/
    TrackManager.gd      # generazione e riciclo segmenti verso l'orizzonte
    TrackSegment.gd      # segmento con pista grigia, cordoli laterali, prato e decorazioni
    GateManager.gd       # file di cancelli: spawn, rilevamento 3D, effetti, riciclo
    GateRow.gd           # coppia di cancelli su un piano (struttura dati)
    EvolutionGate.gd     # un cancello: geometria, colore, valore e spegnimento
  ui/
    HUD.gd               # distanza, monete, livello di evoluzione e feedback cancelli
tests/
  TestRunner.tscn        # test headless di integrazione dei controlli
  TestRunner.gd          # touch/mouse, bordi, camera, pista, FPS, cancelli, evoluzione
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
Esce con codice 0 se tutte le verifiche passano.

## Roadmap (fasi successive, non ancora implementate)

- Fase 3: ostacoli, monete raccoglibili, modelli definitivi delle evoluzioni
- Fase 4: traguardo, fine partita, schermata di riepilogo
- Fase 5: audio, salvataggio locale del punteggio, export Android/iOS

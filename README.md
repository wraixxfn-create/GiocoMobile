# Car Evolve 3D — Blockout 3D giocabile (Fase 1)

Giochino mobile 3D hyper-casual in **Godot 4.3+**, ispirato al genere di
Car Evolve. Ambiente 3D giocabile con pista, bordi laterali rialzati, terreno
verde, cielo con prospettiva verso l'orizzonte, illuminazione con ombre leggere
e auto stilizzata gialla e nera costruita con mesh semplici.

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
    GameManager.gd       # stato di gioco (IDLE/PLAYING/FINISHED), distanza e punteggio
  input/
    InputManager.gd      # input laterale unificato (touch, mouse, tastiera)
  player/
    CarController.gd     # avanzamento automatico + sterzo fluido entro i bordi pista
    CarModel.gd          # auto stilizzata gialla e nera realizzata con mesh semplici
  track/
    TrackManager.gd      # generazione e riciclo segmenti verso l'orizzonte
    TrackSegment.gd      # segmento con pista grigia, cordoli laterali, prato e decorazioni
  ui/
    HUD.gd               # etichette distanza/monete e indicazioni di gioco
tests/
  TestRunner.tscn        # test headless di integrazione dei controlli
  TestRunner.gd          # touch/mouse simulati, bordi, camera, pista, FPS
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
(30/60/120 Hz simulati). Esce con codice 0 se tutte le verifiche passano.

## Roadmap (fasi successive, non ancora implementate)

- Fase 2: cancelli bonus/penalità, ostacoli, monete raccoglibili
- Fase 3: evoluzioni dell'auto (aspetto e statistiche)
- Fase 4: traguardo, fine partita, schermata di riepilogo
- Fase 5: audio, salvataggio locale del punteggio, export Android/iOS

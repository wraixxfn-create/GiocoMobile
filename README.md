# Car Evolve 3D — fondazioni

Giochino mobile 3D hyper-casual in **Godot 4.3+**, ispirato al genere di
Car Evolve. Fase 1: struttura del progetto, scene iniziali e fondamenta
del gameplay (auto in movimento automatico + sterzo touch).

## Requisiti

- Godot 4.3 o superiore (edizione standard, senza Mono)
- Nessun asset esterno: tutto è generato con primitive 3D e materiali del progetto
- Funziona offline (nessuna risorsa remota, nessun servizio)

## Esecuzione

```bash
godot --path .            # apre l'editor; la scena principale parte con F5
godot --headless --path . --import   # importa/valida le risorse da CLI
```

La scena principale è `scenes/Main.tscn` (già impostata in `project.godot`).

## Controlli

- **Smartphone**: trascina il dito a destra/sinistra per sterzare
- **Desktop (test)**: frecce ←/→ o A/D; clic trascinato con il mouse
- Primo tocco/clic: avvia la partita

## Struttura

```
project.godot            # orientamento portrait 9:16, renderer mobile, scena principale
scenes/
  Main.tscn              # scena principale: ambiente, luce, camera, sottosistemi
  Car.tscn               # auto del giocatore
  HUD.tscn               # interfaccia (CanvasLayer)
scripts/
  core/
    GameConfig.gd        # costanti centralizzate: dimensioni, velocità, colori
    GameRoot.gd          # bootstrap: luce, ambiente, camera e collegamenti
    MaterialFactory.gd   # materiali low-poly creati e cachiati nel progetto
  gameplay/
    GameManager.gd       # stato di gioco (IDLE/PLAYING/FINISHED), distanza e punteggio
  input/
    InputManager.gd      # input laterale unificato (touch, mouse, tastiera)
  player/
    CarController.gd     # movimento: avanzamento automatico + sterzo laterale
    CarModel.gd          # costruttore dell'auto low-poly da primitive
  track/
    TrackManager.gd      # generazione e riciclo segmenti (pista infinita)
    TrackSegment.gd      # un segmento: strada, corsie, bordi, decorazioni
  ui/
    HUD.gd               # etichette distanza/monete e hint
```

## Roadmap (fasi successive, non ancora implementate)

- Fase 2: cancelli bonus/penalità, ostacoli, monete raccoglibili
- Fase 3: evoluzioni dell'auto (aspetto e statistiche)
- Fase 4: traguardo, fine partita, schermata di riepilogo
- Fase 5: audio, persistence locale del punteggio, export Android/iOS

## Note

- Risoluzione di progetto 540x960 (9:16) con stretch `canvas_items`/`keep`:
  l'UI e la 3D si adattano proporzionalmente allo schermo del telefono.
- Renderer `mobile` per prestazioni su smartphone.
- Le decorazioni della pista sono generate con seme deterministico per segmento.

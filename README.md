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

- **Smartphone**: trascina il dito a destra/sinistra per sterzare
- **Desktop (test)**: frecce ←/→ oppure tasti A/D; clic trascinato con il mouse
- Primo tocco/clic/tasto direzionale: avvia la corsa

## Struttura

```
project.godot            # orientamento portrait 9:16 (540x960), renderer mobile
scenes/
  Main.tscn              # scena principale: cielo, sole con ombre, camera, sottosistemi
  Car.tscn               # auto del giocatore
  HUD.tscn               # interfaccia minimale (CanvasLayer)
scripts/
  core/
    GameConfig.gd        # parametri centrali: dimensioni, velocità, camera, palette colori
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
```

## Roadmap (fasi successive, non ancora implementate)

- Fase 2: cancelli bonus/penalità, ostacoli, monete raccoglibili
- Fase 3: evoluzioni dell'auto (aspetto e statistiche)
- Fase 4: traguardo, fine partita, schermata di riepilogo
- Fase 5: audio, salvataggio locale del punteggio, export Android/iOS

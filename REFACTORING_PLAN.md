# Piano di refactoring — audit del 2026-10-21

Audit completo del progetto eseguito su tutti i file (28 script GDScript per
~10.800 righe, 3 scene, 2 risorse, configurazione progetto e preset di export)
prima di qualsiasi modifica. Questo documento classifica ogni sistema in
**mantenere / correggere / sostituire** e riporta cosa è già stato fatto in
questa fase di stabilizzazione (solo pulizia e stabilità, nessuna nuova
funzionalità).

## Metodi di verifica usati in questa fase

| Controllo | Strumento | Esito |
| --- | --- | --- |
| Sintassi GDScript (tutti i 28 file) | `gdparse` 4.5.0 (gdtoolkit) | OK prima e dopo le modifiche |
| Lint strutturale/stile | `gdlint` 4.5.0 + `.gdlintrc` | 15 problemi → 0 |
| Riferimenti incrociati (scene→script, `res://` path, gruppi, alias rimossi) | grep/analisi manuale | nessun riferimento mancante |
| Esecuzione progetto e `tests/TestRunner.tscn` | **non eseguibile qui**: nessun binario Godot disponibile in questo ambiente (i download ufficiali passano da host non raggiungibili) | da rilanciare su macchina con Godot 4.3+ |

> Non è stato dichiarato testato ciò che non è stato eseguito: la suite di
> integrazione esiste ed era verde in passato, ma in questa sessione non è
> stato possibile avviarla. Le modifiche applicate sono a comportamento
> invariato (spostamento di costanti con valori identici, deleghe equivalenti,
> rimozioni di codice mai richiamato, riordini senza effetto semantico).

---

## 1. MANTENERE — sistemi funzionanti, solidi e ben testati

Questi sistemi non vanno toccati nel redesign: sono il "contratto" su cui si
innesteranno i nuovi contenuti visivi.

- **GameManager** (`scripts/gameplay/`): FSM autoritativa (menu → countdown →
  corsa → pausa → esito), guardie anti-doppia applicazione (finish_run,
  collect_coin, apply_evolution), punteggio calcolato una sola volta, distanza
  misurata sullo spostamento reale dell'auto.
- **CoinWalletStore**: salvataggio locale ConfigFile robusto (file assente o
  corrotto → saldo zero + warning), scritto in modo sincrono a ogni moneta.
- **InputManager**: touch/mouse/tastiera unificati, precedenza del touch sul
  mouse emulato, reset dei gesti su cambio stato e perdita di focus, ESC per
  pausa/ripresa.
- **CarController**: sterzo a punto target con interpolazione esponenziale
  (identica a 30/60/120 FPS), passo fisico limitato (anti-tunneling), limiti
  laterali derivati dall'ingombro reale dell'auto ruotata, penalità di velocità
  con plateau + recupero morbido, scuotimento puramente visivo.
- **GateManager / GateRow / EvolutionGate**: attraversamento rilevato in 3D
  (segmento auto ∩ piano cancello, esatto anche con passi grandi e diagonali),
  effetto applicato una sola volta, coppia di cancelli spenta atomicamente,
  file riciclate in coordinate mondo senza orfani.
- **ObstacleManager / ObstacleRow / Obstacle**: collisioni analitiche swept
  (metodo degli slab + substep ≤ 0.35 m, blocchi mobili interpolati),
  risoluzione sulla faccia di contatto (mai attraversamenti), **esattamente una
  penalità per urto** (velocità XOR evoluzione), fairness garantita per
  costruzione (varchi ≥ 2,6 m, distanze minime, difficoltà monotòna), effetti
  d'impatto limitati e autogestiti.
- **CoinManager / Coin**: pickup continuo (distanza punto-segmento, niente
  tunneling), pool riciclato senza allocazioni a ogni replay, stato
  anti-doppia raccolta.
- **TrackManager / TrackSegment**: riciclo contiguo dei segmenti, decorazioni
  deterministiche per seme, MultiMesh per erba/fiori (2 draw call/segmento).
- **MaterialFactory / UITheme / SfxDirector**: materiali condivisi in cache
  (con varianti "unique" per le animazioni, così un effetto non si propaga mai
  ad altri oggetti), stile UI centralizzato, audio procedurale PCM16 con pool
  di voci e mute persistente.
- **Separazione logica/visivi dell'auto** (già pronta per il redesign):
  `CarEvolutionProfile` (dati) → `CarEvolutionCatalog` (livello → profilo) →
  `CarModelLibrary` (scena esterna o modello procedurale) → `CarEvolutionDirector`
  (sostituzione modello + animazione) → `CarModelBuilder` + `CarBodyFactory`
  (modello procedurale scolpito, da scartare quando arrivano i modelli veri).
- **TestRunner**: suite di integrazione headless molto ampia (input, FPS
  independence, cancelli, ostacoli, monete, salvataggio, ciclo completo,
  autopilot 1500 m + 600 m a difficoltà massima). Va conservata come rete di
  sicurezza del redesign.
- **Configurazione**: `project.godot` (portrait 9:16, renderer mobile),
  `driving_tuning.tres` (taratura guidabile dall'inspector),
  `car_model_library.tres` (slot modelli definitivi), preset export Android.

## 2. CORREGGERE

### 2a. Già corretto in questa fase (modifiche minime, comportamento invariato)

| # | Problema riscontrato | Intervento | File |
| --- | --- | --- | --- |
| 1 | **Dipendenza circolare tra script**: `CarModel` (costanti nodo/meta/ruota) ↔ `CarEvolutionDirector` (le referenziava, ed era a sua volta referenziato da `CarModel` come tipo). Le dipendenze circolari tra script GDScript sono fragili in caricamento/export. | Costanti canonicali spostate in `CarEvolutionDirector`; `CarModel` le aliasa (dipendenza a senso unico) e il gameplay (`CarController`) ora parla direttamente col direttore | `CarEvolutionDirector.gd`, `CarModel.gd`, `CarController.gd` |
| 2 | **Logica duplicata**: `CarModel.find_director()` e `CarEvolutionDirector.find_on()` implementavano la stessa ricerca | `find_director()` delega a `find_on()` (una sola implementazione) | `CarModel.gd` |
| 3 | **Codice morto**: alias `GameManager.coins` (getter) e `GameManager.add_coins()` — zero chiamanti nel progetto (test inclusi); costanti `CarModel.WHEEL_WIDTH/WHEEL_BASE_X/WHEEL_BASE_Z` mai lette | Rimossi. Restano `end_game()`/`fail_run()` (usati dai test) | `GameManager.gd`, `CarModel.gd` |
| 4 | **Lint (gdlint)**: ordine definizioni in `GameManager` (enum prima dei signal), 3 righe >100 caratteri in `TestRunner.gd` | Riordinato (signals → enums, come da style guide Godot) e righe wrappate | `GameManager.gd`, `TestRunner.gd` |
| 5 | **Nessuna configurazione lint**: scostamenti non motivati | Aggiunto `.gdlintrc` con sole 2 deroghe documentate: `max-file-lines` (suite di test volutamente monolitica, suddivisione prevista al punto 2b) e `max-returns` (stile a guard clause diffuso nel progetto) | `.gdlintrc` |
| 6 | **Export mobile**: preset Android attivo ma compressione texture ETC2/ASTC disabilitata (oggi innocua — tutte le texture sono generate a runtime — ma qualsiasi asset importato in futuro non funzionerebbe su dispositivo) | `textures/vram_compression/import_etc2_astc=true` | `project.godot` |

### 2b. Da correggere nella prossima fase (serve il motore per verificarle)

1. **Spawn oltre il traguardo**: negli ultimi metri le file di cancelli/ostacoli
   riciclate possono comparire visivamente oltre l'arco del traguardo (nessun
   impatto gameplay: la corsa finisce sulla linea). Clamp dello spawn a
   `RUN_DISTANCE_METERS`.
2. **Duplicazione parametri camera**: `Main.tscn` imposta transform/fov/near/far
   che `GameRoot._setup_camera()/_update_camera()` sovrascrivono subito dopo.
   Rendere `GameConfig` l'unica fonte (la scena mantiene solo una posa di
   preview) o viceversa, comunque una sola fonte di verità.
3. **`TestRunner.gd` monolitico (2700 righe)**: spezzare in moduli per fase
   (input, gates, obstacles, coins, cycle) con un runner unico; oggi il limite
   è derogato in `.gdlintrc` proprio perché la suddivisione è pianificata qui.
4. **Segnale `score_updated` mai connesso**: o lo si collega (es. record di
   punteggio, già in roadmap) o lo si rimuove.
5. **Micro-chiarimenti**: `HUD._hide_feedback()` imposta
   `_feedback_label.visible = true` (ridondante, confonde la lettura);
   gruppo `finish_line` assegnato in scena ma mai usato (GameRoot usa il
   percorso nodo); `SfxDirector.add_to_group()` duplica il gruppo già
   assegnato in `Main.tscn` (idempotente, ma ridondante).
6. **Rientrare nei limiti lint pieni** (`max-returns`) ristrutturando
   `_unhandled_input` e `_obstacle_layout_valid` in predicati più piccoli —
   intervento opzionale e solo con la suite di test eseguibile.

## 3. SOSTITUIRE — il redesign visivo (senza riscrivere il gameplay)

La causa del "non raggiunge la qualità desiderata" è il reparto visivo, che
oggi è interamente procedurale a primitive. L'architettura consente già di
sostituirlo pezzo per pezzo: la logica di gioco non conosce la geometria.

| Priorità | Cosa | Come si sostituisce | Cosa NON si tocca |
| --- | --- | --- | --- |
| 1 | **Modelli auto (6 stadi)** — oggi modello procedurale scolpito (`CarModelBuilder` + `CarBodyFactory`, vedi `docs/CAR_MODEL.md`); resta il candidato alla sostituzione con asset modellati a mano | Modelli reali (.glb) negli slot di `config/car_model_library.tres` oppure `CarEvolutionProfile.model_scene`. Contratto: radice `Node3D` rivolta verso -Z, ruote nominate `Wheel*` o nel gruppo `car_wheel` (vengono collegate automaticamente a rotazione/sterzata) | `GameManager`, `GateManager`, HUD, test: non conoscono la geometria |
| 2 | **Ambiente/pista** — `TrackSegment` costruisce tutto in codice (asfalto, cordoli, prato, alberi, colline) | Scene di segmento tematizzate (es. `.tscn` per bioma) mantenendo il contratto di riciclo: lunghezza 40 m, carreggiata 7,8 m, cordoli alle stesse X, origine sul piano di guida | `TrackManager` (riciclo), manager di cancelli/ostacoli/monete (coordinate mondo) |
| 3 | **Cancelli e ostacoli** — `_build()` procedurali dentro `EvolutionGate`/`Obstacle` | Estrarre la costruzione visiva in scene istanziate dai nodi esistenti; i dati (span, `collision_rect`, `crossing_x`, penalità, animazioni di stato) restano negli script | Rilevamento 3D, penalità singola, fairness, cooldown |
| 4 | **UI/HUD** — ~900 righe di nodi Control creati in codice | Migrare il layout in `HUD.tscn` (+ `Theme` resource) conservando **esattamente** l'API pubblica (`set_distance`, `set_state`, `set_evolution`, segnali `play_requested`…) usata da `GameRoot` e dai test | Contratto segnali/metodi con GameRoot e TestRunner |
| 5 | **Effetti** — anelli/scintille/lampi a primitive (urto, trasformazione, pickup) | `GPUParticles3D`/shader nei punti di innesco esistenti (sono già isolati in `_spawn_impact`, `_build_effects`, `_animate_burst`) | Punti di innesco e durate (tarate in `GameConfig`) |
| 6 | **Audio** — blip sintetizzati | Asset reali, mantenendo l'API `SfxDirector` (play_coin/play_evolution/…) e il mute persistente | API e pool di voci |

Regola del redesign: **ogni sostituzione avviene per contratto** (nomi di
gruppi, API pubbliche, dimensioni in `GameConfig`), mai per modifica della
logica; a ogni passo si rilancia `tests/TestRunner.tscn`, che deve restare
verde (verifica anche ingombri, varchi e giocabilità con autopilot).

---

## Stato finale di questa fase

- Funzionalità conservate: tutte (nessuna rimozione di comportamento; rimossi
  solo 2 alias e 3 costanti senza alcun chiamante).
- Struttura: dipendenza circolare eliminata, duplicazioni ridotte, lint verde,
  piano documentato (questo file).
- Avviabilità: le modifiche sono verificabili sintatticamente (gdparse/gdlint
  OK); la prova di avvio con Godot 4.3+ (`godot --headless --path . --import`
  e `godot --headless --path . res://tests/TestRunner.tscn`) **non è eseguibile
  in questo ambiente** e va rilanciata come primo passo della fase successiva.

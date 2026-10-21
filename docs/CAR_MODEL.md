# Modello Modulare dell'Auto ed Evoluzione Fisica

L'auto del giocatore non è un monoblocco indivisibile ma un **veicolo modulare
composto da 8 slot fisici indipendenti**, progettato per supportare sia
l'evoluzione di stadio sia la sostituzione chirurgica di un singolo componente
senza mai ricostruire la gerarchia del veicolo.

---

## 1. Architettura a tre strati

| Strato | Script | Ruolo |
| :--- | :--- | :--- |
| **1. Dati puri (`Resource`)** | `scripts/vehicle/data/*.gd` + `config/parts/**/*.tres` + `config/loadouts/*.tres` | Identificativo univoco (`StringName`), livello richiesto, scena 3D opzionale (`PackedScene`), rarità opzionale, modificatori di gameplay (`CarGameplayModifiers`), regole di compatibilità (`CarPartCompatibility`) e parametri geometrici (`CarPartVisualSpec`). Zero logica di gioco. |
| **2. Logica e montaggio (`VehicleRig`)** | `scripts/vehicle/VehicleRig.gd`, `CarBodySockets.gd`, `CarMountPoint3D.gd`, `CarCompatibilityValidator.gd`, `CarStatsAggregator.gd`, `CarPartRegistry.gd` | Gestisce l'ossatura permanente (`SprungChassis`, 7 socket `Anchor_*` e 4 perni `Wheel0..3`), valida compatibilità e ingombri, sostituisce un singolo slot per volta e ricalcola velocità, sterzo, raggio ruota e collisioni. |
| **3. Integrazione gameplay** | `CarEvolutionDirector.gd`, `CarController.gd`, `ObstacleManager.gd`, `CarShowroom.gd` | Sincronizza guida, sterzata, rotolamento ruote, limiti di carreggiata, collisioni AABB spazzate con gli ostacoli e feedback visivo di trasformazione. |

Nessun componente installato viene mai identificato tramite controlli sul nome
dei nodi (`Node.name`): lo stato equipaggiato è mantenuto esclusivamente nella
mappa tipizzata `_equipped_parts: Dictionary` (`CarPartSlot.Type -> CarPartDefinition`).

---

## 2. Gli 8 slot componenti del veicolo

| Slot (`CarPartSlot.Type`) | Ruolo fisico | Tag socket |
| :--- | :--- | :--- |
| `BODY` (`0`) | Scocca portante, abitacolo, cristalli, fari, pianale e passaruota | Definisce i socket per tutti gli altri slot |
| `BUMPER_FRONT` (`1`) | Fascia frontale, prese d'aria, splitter, canard o bull-bar | `front_fascia` |
| `BUMPER_REAR` (`2`) | Fascia posteriore, estrattore o canali Venturi | `rear_fascia` |
| `WHEELS` (`3`) | Set di 4 ruote complete (pneumatico, cerchio, disco freno, pinza) montate sui 4 mozzi | `wheel_hub` |
| `ENGINE` (`4`) | Gruppo meccanico visibile: cupolino aspirato, twin-turbo, blower V8 o vano centrale V8/V12 | `hood_bay` *(stadi 0–3)* oppure `mid_bay` *(stadi 4–5)* |
| `EXHAUST` (`5`) | Terminale di scarico singolo, doppio cromato, quadruplo titanio o triplo centrale | `rear_exhaust` |
| `SPOILER` (`6`) | Ducktail integrato, alettone GT su piloni, biplano swan-neck o portapacchi | `spoiler_mount` |
| `AERO` (`7`) | Minigonne laterali, paratie verticali, prese NACA e convogliatori Venturi | `aero_sill` |

---

## 3. Convenzioni metriche per modelli 3D definitivi (`.glb` / `.tscn`)

Qualsiasi componente procedurale può essere sostituito da un modello 3D d'artista
assegnando `model_scene` nella risorsa `.tres` corrispondente (senza modificare
alcuna riga di codice):

- **Unità**: `1 unità = 1 metro`.
- **Orientamento veicolo**: muso verso **`-Z`**, coda verso **`+Z`**, alto **`+Y`**, destra **`+X`**.
- **Origine scocca (`Slot.BODY`)**: `Y = 0` a quota asfalto con ruote standard, centro carreggiata `X = 0`, metà passo `Z = 0`.
  - Inserire nodi `CarMountPoint3D` figli per dichiarare in modo tipizzato la posizione e i `mount_tags` dei punti di aggancio dei vari slot e dei 4 mozzi (`hub_index = 0..3`).
- **Origine componenti periferici (`BUMPER_*`, `ENGINE`, `EXHAUST`, `SPOILER`, `AERO`)**: origine locale `(0, 0, 0)` coincidente con il punto di fissaggio sulla scocca.
- **Origine singola ruota (`Slot.WHEELS`)**: centro del mozzo `(0, 0, 0)` con lato esterno rivolto verso **`+X`** (`VehicleRig` specchia automaticamente le ruote sinistre a `rotation.y = PI` mantenendo gli assi di rotolamento `rotation.x` e sterzata `rotation.y` sul nodo mozzo padre).

---

## 4. Stato attuale degli asset e piano di miglioramento futuro

Non essendo presenti nella repository mesh `.glb`/`.fbx` poligonali scolpite da
artisti 3D, tutti i **36 componenti** attualmente nel catalogo `config/parts/`
sono marcati esplicitamente con `is_procedural_prototype = true` e
documentati nel campo `asset_upgrade_notes` di ciascuna risorsa `.tres`
(interrogabili a runtime tramite `CarPartRegistry.prototype_parts()`).

### Prototipi modulari inclusi e priorità di sostituzione artistica

1. **Priorità Alta — Carrozzerie (`config/parts/body/*.tres`, 6 varianti)**:
   - `body_wreck`, `body_hatchback`, `body_sedan`, `body_coupe`, `body_supercar`, `body_hypercar`.
   - *Miglioramento consigliato*: mesh low-poly dedicate (1.500–3.000 triangoli) con tagli portiere/cofano scolpiti, gruppi di smoothing netti, normal/AO map baked e nodi `CarMountPoint3D` espliciti.
2. **Priorità Alta — Set di Ruote (`config/parts/wheels/*.tres`, 4 varianti — 3 stradali/racing + 1 base)**:
   - `wheels_classic_5spoke`, `wheels_sport_multispoke`, `wheels_racing_turbofan`, `wheels_steel_stamped`.
   - *Miglioramento consigliato*: cerchi low-poly con razze smussate, dadi mozzo dedicati e texture normal/roughness per battistrada e dischi freno forati.
3. **Priorità Media — Paraurti Anteriori e Posteriori (`config/parts/bumper_front/*.tres` + `bumper_rear/*.tres`, 4 + 4 varianti)**:
   - Anteriori: `bumper_front_street`, `bumper_front_splitter`, `bumper_front_gt_aero`, `bumper_front_bullbar`.
   - Posteriori: `bumper_rear_street`, `bumper_rear_diffuser`, `bumper_rear_gt_venturi`, `bumper_rear_raw`.
   - *Miglioramento consigliato*: griglie a nido d'ape su alpha/normal map e raccordi smussati con i parafanghi.
4. **Priorità Media — Spoiler (`config/parts/spoiler/*.tres`, 5 varianti — 3 aerodinamiche + 2 base)**:
   - `spoiler_ducktail`, `spoiler_gt_wing`, `spoiler_biplane_swan` (+ `spoiler_none`, `spoiler_wreck_rack`).
   - *Miglioramento consigliato*: profili alari camberati con staffe CNC traforate e texture fibra di carbonio.
5. **Priorità Normale — Motori, Scarichi ed Aerodinamica (`config/parts/engine/`, `exhaust/`, `aero/`)**:
   - Motori (5): `engine_hood_aspirated`, `engine_hood_twinturbo`, `engine_hood_blower`, `engine_mid_v8_bay`, `engine_mid_hyper_v12`.
   - Scarichi (4): `exhaust_single_steel`, `exhaust_dual_chrome`, `exhaust_quad_titanium`, `exhaust_center_triple`.
   - Kit Aero (4): `aero_none`, `aero_street_skirts`, `aero_track_skirts`, `aero_hyper_venturi`.
   - *Miglioramento consigliato*: cablaggi/tubazioni baked su normal map per i vani motore e sfumatura termica anodizzata per i terminali in titanio.

---

## 5. Verifica rapida in Showroom e nei Test

- **Showroom interattivo**: aprire `res://scenes/dev/CarShowroom.tscn` e premere **F6** per ruotare/zoomare attorno al veicolo, cambiare stadio (`< STADIO / STADIO >` o tasti `1..6`) e sostituire dal vivo i singoli slot compatibili verificando in tempo reale statistiche e ingombri.
- **Suite automatica**: eseguire `res://tests/TestRunner.tscn` (include `CarCustomizationTests.gd`).

# Modello visivo dell'auto principale

Questo documento descrive come è fatto il nuovo modello dell'auto, come
ritoccarlo e come sostituirlo in futuro con un asset modellato in Blender.

## In breve

Il modello è **procedurale e scolpito**: non più cubi assemblati, ma
superfici continue generate da curve di progetto. Scocca e abitacolo sono
"loft" di sezioni trasversali lungo l'asse dell'auto (come si disegna una
carrozzeria vera: profilo laterale + sezioni), le ruote sono solidi di
rivoluzione con pneumatico, cerchio a razze e mozzo, i dettagli sono parti
distinte con nome e pivot propri.

Ogni stadio di evoluzione (0 rottame → 5 hypercar) usa la stessa
costruzione con un proprio **blueprint** (curve di cofano/cintura/tetto,
larghezze, opzioni come alettone o cerchi in acciaio) e le proporzioni del
`CarEvolutionProfile` esistente. Risultato: sei silhouette davvero diverse
ma con la stessa qualità di superficie.

| File | Ruolo |
| --- | --- |
| `scripts/player/CarBodyFactory.gd` | Geometria: loft multimateriale, lathe, arco di toro, capsula, curve Catmull-Rom. Nessuna logica di gioco. |
| `scripts/player/CarModelBuilder.gd` | Blueprint per silhouette + assemblaggio di scocca, abitacolo, ruote, dettagli, spie. Stessa interfaccia di prima (`build(profile)`). |
| `scenes/MainCar.tscn` + `scripts/player/MainCarVisual.gd` | **Scena dedicata all'auto** (solo visiva, `@tool`): apribile in editor, `level` cambiabile da inspector. |
| `scenes/CarShowroom.tscn` + `scripts/dev/CarShowroom.gd` | **Scena di presentazione temporanea**: studio neutro, podio, 3 luci, orbita con trascinamento, cambio stadio con pulsanti o tasti 1–6. |

## Come è costruita la carrozzeria

- **Curve 1D di progetto** (normalizzate, `zn` 0 = muso, 1 = coda): altezza
  del colmo (`body_top`), larghezza (`body_w`), fondo del pianale. Sono
  interpolate con Catmull-Rom e campionate in ~45 stazioni.
- **Sezione trasversale**: mezza-sezione da (0,0) a (0,1) — fondo piatto,
  fianchi pieni, spalla, colmo arrotondato — specchiata sull'altro lato.
- **Passaruota veri**: il fondo della sezione si solleva con un arco di
  cerchio sopra ogni ruota, ma **solo verso i fianchi** (peso `smoothstep`
  su |x|): il pianale centrale resta basso e non si vede "attraverso"
  l'auto. Sulle auto basse, dove la ruota è più alta della linea di
  cintura, un secondo sollevamento crea la **spalla del parafango**
  (muscolosa su coupé/supercar/hypercar, assente sulle altre).
- **Fasce di materiale dallo stesso loft**: sotto una soglia di sezione la
  superficie è rivestimento scuro (cladding), sopra è vernice. Per
  l'abitacolo: vetro ovunque, ma **tetto e montanti A/B/C in vernice**.
  Le normali sono calcolate sulla griglia intera, quindi la luce non ha
  cuciture ai confini dei materiali.
- **Ruote**: profilo tornito (spalle arrotondate, battistrada), barile
  scuro, anello del cerchio, cinque razze, mozzo e borchia; il rottame ha
  cerchi in acciaio pieni. I pozzi scuri chiudono la vista nei passaruota;
  il profilo del passaruota è un arco di toro con tappi.
- **Dettagli nominati**: fari con guscio e lente emissiva (barra luminosa
  sulla hypercar), fanali, paraurti tondeggianti (in tinta o splitter),
  presa d'aria con distintivo, pannello di coda, targa, specchietti con
  braccio e vetro, maniglie, scarichi, pinna antenna, spoiler a labbro o
  alettone con piloni dimensionati sul piano di coda, ruota di scorta e
  barre sul tetto del rottame. La barra di spie dell'evoluzione è
  invariata (è un elemento di lettura del gioco), ora su una slitta scura.

Gerarchia prodotta per ogni stadio:

```
Stage_N
├─ Body
│  ├─ BodyPaint, BodyTrim, CabinGlass, CabinPaint
│  ├─ ArchFL..ArchRR, WellFL..WellRR
│  ├─ BumperFront/Rear, Intake, Badge, TailPanel, PlateRear
│  ├─ Headlight*, Taillight* (o HeadBar/TailBar)
│  ├─ Mirror*, Handle*, Exhaust*, SharkFin, SpoilerLip | Wing*, ...
│  └─ EvolutionPips → PipBase, Pip0..Pip4
├─ Wheel0  (anteriore sinistra)  → Tire, RimBarrel, RimLip, Spoke0..4, Hub, HubCap
├─ Wheel1  (anteriore destra)
├─ Wheel2  (posteriore sinistra)
└─ Wheel3  (posteriore destra)
```

I perni `WheelN` hanno rotazione identità a riposo: è il contratto che il
`CarController` si aspetta (rotazione X = rotolamento, Y = sterzo sulle
anteriori). La specchiatura destra/sinistra è **nella geometria**, non nel
pivot. Attenzione ai nomi: nessun altro nodo deve iniziare per `Wheel`
(è il criterio con cui `CarModelLibrary.resolve_wheels()` trova le ruote).

## Materiali e palette

Invariati i punti di taratura esistenti: colori per stadio da
`CarEvolutionCatalog` (derivati da `GameConfig.EVOLUTION_COLORS`),
materiali da `MaterialFactory` (vernice con clearcoat, roughness 0.22 —
lucida ma non a specchio; vetri 0.06/0.55; plastiche scure 0.45; cerchi
0.20/0.80; pneumatici 0.94). Fari, fanali e spie accese usano materiali
emissivi **unici per modello**, così il lampo di trasformazione li anima
senza toccare altro.

## Come ritoccare il modello

- **Proporzioni** (lunghezza, larghezza, tetto, ruote, interasse):
  `CarEvolutionCatalog._apply_shape()` — sono le stesse misure che
  alimentano ingombri e limiti laterali del gameplay.
- **Carattere della silhouette**: `_blueprint_for()` in
  `CarModelBuilder.gd` — curve `body_top`/`body_w`/`glass_top`/`glass_w`,
  `glass_span` e `roof_range` (dove sta l'abitacolo e dove il tetto è
  piano), montanti, soglia del rivestimento scuro (`clad_split`), stile
  fari/paraurti/spoiler.
- **Forma della sezione**: `BODY_SECTION` / `GLASS_SECTION` in cima a
  `CarModelBuilder.gd` (punti chiave (xf, yf)).
- **Verifica rapida**: aprire `scenes/CarShowroom.tscn` e premere F6,
  oppure aprire `scenes/MainCar.tscn` e muovere `level` nell'inspector.

Costo: ~13–16k triangoli e ~80 nodi per stadio (un'auto sola in scena):
nell'ordine di grandezza del modello precedente, adatto a mobile.

## Limiti onesti di questo approccio

Il modello è pensato per essere letto a distanza di gioco su schermo
mobile, ed è un grande passo avanti rispetto al blockout precedente, ma
**non è un asset modellato a mano**. In particolare:

- le superfici sono lisce e continue ma senza finiture fini: niente tagli
  di portiere/cofano, guarnizioni, battistrada, interni (il vetro è opaco
  e stilizzato, senza abitacolo interno);
- i dettagli (fari, paraurti, specchietti) sono forme tondeggianti
  generate da primitive sagomate (capsule/sfere/lathe): da vicino si
  riconosce la natura procedurale;
- materiali piatti senza texture/UV artistiche (le UV generate sono
  parametriche, utili al massimo per decal semplici);
- piccole intersezioni nascoste fra le parti (es. abitacolo affondato
  nella scocca) sono deliberate e invisibili da fuori, ma non è una mesh
  "watertight" da produzione.

Per un salto ulteriore (finiture, interni, livree, cerchi veri) serve un
modello fatto in Blender. Il progetto è già predisposto: segue il flusso.

## Flusso concreto: modello Blender → Godot

Il gancio è già nel codice e non richiede modifiche alla logica:
`CarModelLibrary.create_stage()` usa una scena esterna se presente,
altrimenti il modello procedurale.

1. **Modella in Blender** con 1 unità = 1 metro. Ingombri di riferimento
   per stadio: quelli di `CarEvolutionCatalog._apply_shape()` (es.
   utilitaria: 2.86 × 1.50 m, tetto a 1.04 m, ruote Ø 0.60 m). Origine al
   centro dell'auto **sul piano del suolo** (y = 0 sotto le ruote).
2. **Ruote come oggetti separati**, con origine al centro del mozzo
   (Object → Set Origin), nomi `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR`
   (devono iniziare per `Wheel`; in alternativa gruppo `car_wheel` da
   assegnare poi in Godot). Le prime due in ordine gerarchico saranno le
   **anteriori** (sterzanti): tieni l'ordine FL, FR, RL, RR.
3. **Applica le trasformazioni** (Ctrl+A: posizione/rotazione/scala)
   prima dell'export; budget consigliato ≤ 20–30k triangoli per auto,
   ≤ ~10 materiali, texture ≤ 1024² se servono.
4. **Esporta in glTF** (.glb, +Y up). Importa in Godot trascinando il file
   nel progetto (la compressione ETC2/ASTC è già attiva).
5. **Non usare il .glb grezzo**: crea una scena wrapper
   (`res://models/MiaAuto.tscn`) con radice `Node3D` e il .glb come
   figlio; ruota/scala il figlio in modo che il muso guardi **−Z** di
   Godot e le ruote tocchino y = 0. È nella wrapper che correggi
   orientamento e nomi senza toccare l'import.
6. **Collega la scena al gioco** in uno dei due modi già pronti:
   - `config/car_model_library.tres`: slot `model_scenes` per livello
     (indice = livello; gli slot vuoti restano procedurali);
   - oppure `CarEvolutionProfile.model_scene` su un profilo custom.
7. **Verifica**: avvia `scenes/Main.tscn`: le ruote devono ruotare e le
   anteriori sterzare; l'evoluzione ai cancelli deve sostituire il
   modello. Per un'anteprima statica puoi istanziare la wrapper nello
   showroom al posto di `MainCar`.

Note oneste sul contratto attuale per i modelli esterni:

- le **spie di evoluzione** sul tetto le crea solo il builder
  procedurale: con scene esterne su tutti i livelli il test
  `_test_evolution_stage_models` va aggiornato (o le spie vanno aggiunte
  alla scena wrapper e riferite). Il gameplay non ne risente (l'HUD
  mostra comunque il livello);
- il **lampo di trasformazione** anima i materiali emissivi trovati via
  `material_override`: i materiali interni a un .glb non lo sono, quindi
  sulle luci esterne l'effetto è assente a meno di impostare un
  `material_override` emissivo nella wrapper;
- la lista `body_meshes` (metadati di ricolorazione) resta vuota per le
  scene esterne: oggi la usano solo debug e test.

## Verifica eseguita in questa fase

- Geometria sviluppata e **controllata visivamente** con un prototipo
  Python che condivide la stessa matematica (loft, lathe, blueprint):
  render da ¾ anteriore/posteriore, laterale, frontale, dall'alto e da
  telecamera di gioco per tutti e sei gli stadi.
- Ingombri per stadio misurati: tutti sopra le soglie dei test
  (x ≥ 1.2, z ≥ 1.8, y ≥ 0.6) e **tutti diversi** tra loro.
- Sintassi e stile GDScript verificati con `gdparse`/`gdlint` (puliti su
  tutto il progetto).
- **Non** è stato possibile eseguire Godot né la suite
  `tests/TestRunner.tscn` nell'ambiente di sviluppo usato per questa
  modifica (binario dell'engine non scaricabile): l'esecuzione in locale
  è il passo di conferma finale — `godot --headless --path . --import`,
  poi `godot --headless --path . res://tests/TestRunner.tscn`, e F6 su
  `scenes/CarShowroom.tscn` per la vista reale con luci e materiali
  dell'engine.

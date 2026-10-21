class_name GameConfig
extends RefCounted
## Parametri centrali del progetto: dimensioni, velocità, camera e palette colori.
## Tutti i valori usano 1 unità = 1 metro.

# ------------------------------------------------------------------ Track ---
const TRACK_WIDTH: float = 7.8
const TRACK_LANE_COUNT: int = 3
const CURB_WIDTH: float = 0.48
const CURB_HEIGHT: float = 0.22
const GRASS_WIDTH: float = 150.0
const SEGMENT_LENGTH: float = 40.0
const SEGMENT_COUNT: int = 10

# -------------------------------------------------------------------- Car ---
## Spostamenti dell'auto oltre questo limite (in un solo passo) sono trattati
## come teletrasporti (test, reset, debug) e non generano attraversamenti di
## cancelli: in gioco reale l'auto avanza al massimo di ~1 m per passo fisico.
const GATE_TELEPORT_LIMIT: float = 8.0

## Ingombro dell'auto (le ruote sono la parte più larga, la carrozzeria la più lunga).
const CAR_HALF_WIDTH: float = 0.86
const CAR_HALF_LENGTH: float = 1.73
## Sterzata massima usata per il feedback visivo: entra nel calcolo dei bordi,
## perché un'auto ruotata occupa più spazio lateralmente.
const CAR_MAX_STEER_YAW: float = 0.16
## Margine di sicurezza tra carrozzeria e bordo asfalto, in metri.
const CAR_EDGE_MARGIN: float = 0.05

# ------------------------------------------------------------- Evoluzione ---
## Livello di evoluzione dell'auto: unica fonte di verità per minimo e massimo.
## Il valore corrente vive in GameManager.evolution_level e viene modificato
## solo tramite GameManager.apply_evolution().
const EVOLUTION_MIN_LEVEL: int = 0
const EVOLUTION_MAX_LEVEL: int = 5
const EVOLUTION_START_LEVEL: int = 1
## Colore della carrozzeria per ogni livello (indice = livello).
const EVOLUTION_COLORS: Array[Color] = [
	Color(0.64, 0.62, 0.53),
	Color(0.99, 0.71, 0.05),
	Color(1.00, 0.47, 0.09),
	Color(0.30, 0.87, 0.38),
	Color(0.10, 0.72, 0.96),
	Color(0.62, 0.34, 1.00),
]
## Nome dello stadio visivo per ogni livello (indice = livello).
## Lo stadio 0 è sotto l'utilitaria: è il "rottame" che si vede dopo troppe
## regressioni, così ogni livello ha comunque una silhouette riconoscibile.
const EVOLUTION_STAGE_NAMES: Array[String] = [
	"ROTTAME",
	"UTILITARIA",
	"BERLINA",
	"SPORTIVA",
	"SUPERCAR",
	"HYPERCAR",
]
## Moltiplicatore della velocità di avanzamento (indice = livello).
const EVOLUTION_SPEED_MULTIPLIERS: Array[float] = [
	0.85,
	1.00,
	1.12,
	1.24,
	1.36,
	1.50,
]
## Moltiplicatore della reattività dello sterzo (indice = livello).
const EVOLUTION_HANDLING_MULTIPLIERS: Array[float] = [
	0.85,
	1.00,
	1.10,
	1.20,
	1.30,
	1.45,
]
## Durata dell'animazione di trasformazione, in secondi.
const EVOLUTION_TRANSFORM_DURATION: float = 0.55

# ------------------------------------------------------ Ciclo di gioco -----
## Traguardo della corsa (metri). A velocità standard equivale a circa un minuto.
const RUN_DISTANCE_METERS: float = 800.0
## Conteggio iniziale breve (3, 2, 1), espresso in secondi.
const COUNTDOWN_DURATION: float = 2.4

# ---------------------------------------------------- Monete e punteggio ---
## Unica posizione del salvataggio locale (ConfigFile, cartella user:// di Godot).
const COIN_SAVE_PATH: String = "user://giocomobile_save.cfg"
## Ogni moneta aggiunge questa quantità sia alla corsa sia al saldo permanente.
const COIN_VALUE: int = 1
## Prima moneta e distanza costante tra gli oggetti generati davanti all'auto.
const COIN_FIRST_DISTANCE: float = 16.0
const COIN_SPAWN_SPACING: float = 8.0
const COIN_ACTIVE_COUNT: int = 20
## Posizioni laterali alternate: pista larga 7,8 m, sempre raggiungibili.
const COIN_LANE_PATTERN: Array[float] = [0.0, -1.8, 1.8, -0.8, 2.2, 0.0, -2.2]
## Aspetto e moto delle monete (metri / radianti al secondo).
const COIN_HEIGHT: float = 0.90
const COIN_RADIUS: float = 0.34
const COIN_THICKNESS: float = 0.09
const COIN_PICKUP_RADIUS: float = 1.30
const COIN_RECYCLING_OFFSET: float = 18.0
const COIN_TELEPORT_LIMIT: float = 6.0
const COIN_ANIMATION_DURATION: float = 0.42
const COIN_ANIMATION_RISE: float = 0.85
const COIN_SPIN_SPEED: float = 2.8
const COIN_BOB_AMPLITUDE: float = 0.12
const COIN_BOB_SPEED: float = 2.2
## Formula finale: metri × punti/m + livello massimo × bonus + monete × bonus.
const SCORE_POINTS_PER_METER: float = 10.0
const SCORE_POINTS_PER_EVOLUTION_LEVEL: int = 250
const SCORE_POINTS_PER_COIN: int = 50
const COLOR_COIN := SceneryPalette.COIN_GOLD
const COLOR_COIN_HIGHLIGHT := SceneryPalette.COIN_HIGHLIGHT

# --------------------------------------------------------------- Cancelli ---
## Distanza dall'auto della prima fila di cancelli all'avvio della corsa.
## Deve restare ampia: il giocatore vede i cancelli e ha il tempo di sterzare.
const GATE_FIRST_ROW_DISTANCE: float = 70.0
## Distanza costante tra due file di cancelli (metri).
const GATE_ROW_SPACING: float = 48.0
## File di cancelli mantenute in gioco contemporaneamente.
const GATE_ROW_COUNT: int = 3
## Un cancello è considerato superato (e la fila può essere riciclata)
## quando l'auto lo ha oltrepassato di questo margine, in metri.
const GATE_PASSED_OFFSET: float = 26.0
## Margine tra i cancelli e i cordoli: nessun palo finisce sopra il prato.
const GATE_EDGE_MARGIN: float = 0.15
## Larghezza minima di un cancello: entrambe le scelte restano percorribili.
const GATE_MIN_WIDTH: float = 2.4
## Altezza dell'arcata dei cancelli, in metri (leggibilità in lontananza).
const GATE_HEIGHT: float = 2.75
## Ampiezza della penalità applicata dai cancelli rossi.
const GATE_NEGATIVE_STEP: int = 1
## Posizione del punto di separazione tra i due cancelli di una fila, in metri
## dal centro pista. Valori alternati: a volte la scelta comoda è a sinistra,
## a volte a destra.
const GATE_SPLIT_PATTERN: Array[float] = [-1.3, 0.0, 1.3, 0.7, -0.7]
## Valori dei cancelli positivi (i più grandi sono blu, i piccoli verdi).
const GATE_POSITIVE_PATTERN: Array[int] = [1, 2, 1, 2, 1]

const COLOR_GATE_POSITIVE := SceneryPalette.GATE_GREEN
const COLOR_GATE_POSITIVE_STRONG := SceneryPalette.GATE_BLUE
const COLOR_GATE_NEGATIVE := SceneryPalette.GATE_RED
const COLOR_GATE_FRAME := Color(0.98, 0.99, 1.0)
const COLOR_GATE_OFF := Color(0.40, 0.43, 0.48)

# --------------------------------------------------------------- Ostacoli ---
## PUNTO UNICO DI TARATURA DEGLI OSTACOLI (fase 3).
## Gli ostacoli vivono nei "corridoi" oltre ogni fila di cancelli: ogni fila di
## ostacoli è ancorata a una fila di cancelli e sta OBSTACLE_CORRIDOR_OFFSET
## metri oltre di essa. Poiché le file di cancelli distano GATE_ROW_SPACING e
## vengono riciclate quando l'auto le ha superate di GATE_PASSED_OFFSET, questo
## schema garantisce SEMPRE, per costruzione:
## - distanza ostacolo/cancello = OBSTACLE_CORRIDOR_OFFSET (>= OBSTACLE_GATE_CLEARANCE);
## - distanza tra due file di ostacoli = GATE_ROW_SPACING (>= OBSTACLE_ROW_MIN_SPACING);
## - il riciclo di una fila (il "salto" verso l'orizzonte) avviene quando l'auto
##   ha già superato la fila: nessun ostacolo sparisce davanti al giocatore.
##
## Regola fondamentale di fairness: ogni fila lascia un varco largo almeno
## OBSTACLE_GAP_MIN, sempre maggiore dell'ingombro massimo dell'auto ruotata
## (2 * lateral_half_extent(CAR_MAX_STEER_YAW) ~= 2.25 m) più margine.

## Distanza tra il piano di una fila di cancelli e la fila di ostacoli ancorata.
## Deve essere < GATE_PASSED_OFFSET - 1: quando il cancello viene riciclato,
## il suo ostacolo è già dietro l'auto e il "salto" non è visibile.
const OBSTACLE_CORRIDOR_OFFSET: float = 24.0
## Distanza minima assoluta tra un ostacolo e il piano di un cancello.
const OBSTACLE_GATE_CLEARANCE: float = 16.0
## Distanza minima assoluta tra due file di ostacoli.
const OBSTACLE_ROW_MIN_SPACING: float = 16.0
## Margine tra gli ostacoli e i cordoli: nessun pezzo finisce sopra il prato.
const OBSTACLE_EDGE_MARGIN: float = 0.15
## Larghezza del varco percorribile: ampia a difficoltà 0, minima a difficoltà 1.
const OBSTACLE_GAP_WIDE: float = 3.6
const OBSTACLE_GAP_MIN: float = 2.6
## Distanza della prima fila (solo nella modalità senza GateManager: con i
## cancelli attivi le file sono ancorate ai corridoi, la prima nasce a
## GATE_FIRST_ROW_DISTANCE + OBSTACLE_CORRIDOR_OFFSET).
const OBSTACLE_FIRST_ROW_DISTANCE: float = 94.0
## Spaziatura/distanza di riciclo nella modalità senza GateManager.
const OBSTACLE_VIRTUAL_SPACING: float = 48.0
const OBSTACLE_PASSED_OFFSET: float = 26.0

## Rampa della difficoltà in funzione della distanza percorsa (metri):
## 0 fino a OBSTACLE_EASY_DISTANCE, 1 da OBSTACLE_RAMP_DISTANCE in poi.
## Progressione volutamente controllata: la velocità di base NON aumenta mai,
## cambiano solo precisione richiesta, tipi di ostacolo e velocità dei mobili.
const OBSTACLE_EASY_DISTANCE: float = 150.0
const OBSTACLE_RAMP_DISTANCE: float = 1200.0
## Soglie di difficoltà a cui compaiono i passaggi stretti e gli ostacoli mobili.
const OBSTACLE_TIER_NARROW: float = 0.30
const OBSTACLE_TIER_MOVING: float = 0.55
## Velocità laterale degli ostacoli mobili (m/s): lenti all'inizio, più rapidi
## a difficoltà massima, ma sempre leggibili e schivabili.
const OBSTACLE_MOVING_SPEED_SLOW: float = 1.5
const OBSTACLE_MOVING_SPEED_FAST: float = 2.8
## Contatti consecutivi (oltre la cooldown) dopo i quali un ostacolo mobile
## viene abbattuto: garanzia che l'auto non resti mai bloccata per sempre.
const OBSTACLE_MOVING_BREAK_HITS: int = 3

## Tipi di penalità: una collisione ne applica ESATTAMENTE UNA, mai entrambe.
const OBSTACLE_PENALTY_SPEED: int = 0
const OBSTACLE_PENALTY_EVOLUTION: int = 1
## Coni: perdita di velocità breve e leggera.
const OBSTACLE_CONE_SPEED_FACTOR: float = 0.75
const OBSTACLE_CONE_SPEED_DURATION: float = 0.55
## Barriere statiche: perdita di velocità marcata.
const OBSTACLE_BARRIER_SPEED_FACTOR: float = 0.45
const OBSTACLE_BARRIER_SPEED_DURATION: float = 1.15
## Muri dei restringimenti: perdita di velocità intermedia.
const OBSTACLE_WALL_SPEED_FACTOR: float = 0.55
const OBSTACLE_WALL_SPEED_DURATION: float = 0.95
## Ostacoli mobili: un livello di evoluzione perso (mai la velocità insieme).
const OBSTACLE_MOVING_EVOLUTION_STEP: int = 1
## Frazione della penalità di velocità mantenuta prima del recupero graduale.
const OBSTACLE_PENALTY_HOLD_FRACTION: float = 0.45
## Tempo minimo tra due contatti contati dello stesso ostacolo (mobile).
const OBSTACLE_HIT_COOLDOWN: float = 0.8

## Animazioni e feedback di collisione.
const OBSTACLE_BREAK_DURATION: float = 0.55
const OBSTACLE_CONE_FALL_DURATION: float = 0.40
const OBSTACLE_SHAKE_DURATION: float = 0.38
const OBSTACLE_SHAKE_FREQUENCY: float = 9.0
## Ampiezza massima dello scuotimento (radianti): volutamente piccola, non
## altera in modo percettibile l'ingombro laterale dell'auto.
const OBSTACLE_SHAKE_AMPLITUDE: float = 0.045
const OBSTACLE_IMPACT_DURATION: float = 0.5
const OBSTACLE_MAX_EFFECTS: int = 8

## Affidabilità della rilevazione (anti-tunneling e anti-teletrasporto).
## Spostamenti dell'auto oltre questo limite sono considerati teletrasporti
## (test/reset) e non generano collisioni; il passo dell'auto è comunque
## limitato a 0.1 s in CarController, quindi in gioco reale non accade mai.
const OBSTACLE_TELEPORT_LIMIT: float = 6.0
const OBSTACLE_MAX_STEP_DT: float = 0.1
const OBSTACLE_SUBSTEP_LENGTH: float = 0.35
const OBSTACLE_MAX_SUBSTEPS: int = 8
## Margine aggiuntivo sull'ingombro dell'auto usato nelle collisioni.
const OBSTACLE_CAR_MARGIN: float = 0.03

## Ingombri (metri, semi-assi) delle quattro tipologie.
const OBSTACLE_CONE_HALF_EXTENTS := Vector3(0.24, 0.34, 0.24)
const OBSTACLE_BARRIER_HALF_HEIGHT: float = 0.52
const OBSTACLE_BARRIER_HALF_DEPTH: float = 0.28
const OBSTACLE_WALL_HALF_HEIGHT: float = 0.48
const OBSTACLE_WALL_HALF_DEPTH: float = 0.30
const OBSTACLE_MOVING_HALF_EXTENTS := Vector3(1.00, 0.62, 0.45)

const COLOR_OBSTACLE_BARRIER := Color(0.85, 0.16, 0.14)
const COLOR_OBSTACLE_STRIPE := Color(0.96, 0.97, 0.99)
const COLOR_OBSTACLE_CONE := Color(0.98, 0.42, 0.08)
const COLOR_OBSTACLE_CONE_BASE := Color(0.20, 0.21, 0.24)
const COLOR_OBSTACLE_WALL := Color(0.62, 0.63, 0.66)
const COLOR_OBSTACLE_WALL_CHEVRON := Color(0.90, 0.25, 0.18)
const COLOR_OBSTACLE_MOVING := Color(0.98, 0.72, 0.06)
const COLOR_OBSTACLE_MOVING_DARK := Color(0.13, 0.14, 0.17)
const COLOR_OBSTACLE_BEACON := Color(1.0, 0.62, 0.10)
const COLOR_OBSTACLE_IMPACT := Color(1.0, 0.82, 0.35)

# ----------------------------------------------------------------- Camera ---
## Inquadratura "premium": camera più bassa e vicina, auto nel terzo inferiore
## e molta strada visibile davanti, così i cancelli si anticipano da lontano.
## L'auto resta perfettamente centrata (segue l'asse laterale 1:1).
const CAMERA_HEIGHT: float = 3.15
const CAMERA_DISTANCE: float = 7.5
const CAMERA_LOOK_AHEAD: float = 10.2
const CAMERA_LOOK_HEIGHT: float = 1.08
const CAMERA_FOV: float = 60.0
## 1.0 = la telecamera segue completamente l'auto: l'auto resta stabile al
## centro dell'inquadratura ed è la pista a scorrere lateralmente.
const CAMERA_LATERAL_FOLLOW: float = 1.0

# --------------------------------------------------------- Cielo / Luce -----
## Palette del livello tropicale: cielo, luce e superfici vengono da
## `SceneryPalette`, così scenario e interfaccia restano coordinati.
const COLOR_SKY_TOP := SceneryPalette.SKY_TOP
const COLOR_SKY_HORIZON := SceneryPalette.SKY_HORIZON
const COLOR_GROUND_HORIZON := SceneryPalette.FOG_COLOR
const COLOR_AMBIENT := SceneryPalette.AMBIENT_COLOR
const COLOR_SUN := SceneryPalette.SUN_COLOR

# --------------------------------------------------------- Pista / Prato ----
const COLOR_ROAD := SceneryPalette.ROAD_BASE
const COLOR_ROAD_ALT := SceneryPalette.ROAD_WEAR
const COLOR_LANE := SceneryPalette.LANE_PAINT
const COLOR_CURB_PRIMARY := SceneryPalette.CURB_LIGHT
const COLOR_CURB_ACCENT := SceneryPalette.CURB_RED
## Fascia sabbiosa tra cordolo e prato: stacca la pista dallo sfondo verde.
const COLOR_VERGE := SceneryPalette.SAND

const COLOR_GRASS := SceneryPalette.GRASS_BASE
const COLOR_GRASS_ALT := SceneryPalette.GRASS_DEEP
const COLOR_HILL := SceneryPalette.HILL_NEAR

# --------------------------------------------------------- Decorazioni ------
const COLOR_TRUNK := SceneryPalette.TRUNK
const FOLIAGE_COLORS: Array[Color] = [
	SceneryPalette.FOLIAGE_DEEP,
	SceneryPalette.FOLIAGE_MID,
	SceneryPalette.FOLIAGE_LIGHT,
	SceneryPalette.FOLIAGE_TIP,
]
## Fiori low-poly sparsi sul prato (MultiMesh: un solo draw call per segmento).
const FLOWER_COLORS: Array[Color] = [
	SceneryPalette.FLOWER_A,
	SceneryPalette.FLOWER_B,
	SceneryPalette.FLOWER_C,
	Color(0.72, 0.62, 1.0),
]
const COLOR_ROCK := SceneryPalette.ROCK
const COLOR_POST := SceneryPalette.CURB_LIGHT
const COLOR_POST_REFLECTOR := Color(1.0, 0.42, 0.16)

# --------------------------------------------------- Traguardo / Interfaccia -
const COLOR_FINISH_DARK := Color(0.07, 0.09, 0.13)
const COLOR_FINISH_LIGHT := Color(0.98, 0.99, 1.0)
const COLOR_FINISH_GOLD := Color(1.0, 0.82, 0.25)
const COLOR_UI_PANEL := Color(0.035, 0.065, 0.11, 0.93)
const COLOR_UI_PANEL_SOFT := Color(0.05, 0.09, 0.15, 0.86)
const COLOR_UI_ACCENT := Color(0.27, 0.90, 0.53)
const COLOR_UI_ACCENT_DEEP := Color(0.10, 0.72, 0.42)
const COLOR_UI_GOLD := Color(1.0, 0.80, 0.22)
const COLOR_UI_TEXT := Color(0.97, 0.98, 1.0)
const COLOR_UI_TEXT_MUTED := Color(0.68, 0.78, 0.90)

# ---------------------------------------------------------------- Audio -----
## Impostazioni audio persistenti (attivo/silenzioso) in user://.
const AUDIO_SAVE_PATH: String = "user://giocomobile_audio.cfg"
## Volume di riferimento degli effetti: leggero, non invadente.
const AUDIO_SFX_VOLUME_DB: float = -5.0
## Intervallo minimo tra due suoni di raccolta: evita raffiche sovrapposte.
const AUDIO_COIN_MIN_INTERVAL: float = 0.045
## Voci audio simultanee disponibili (pool riutilizzato, nessuna allocazione).
const AUDIO_VOICE_COUNT: int = 6
## Frequenza di campionamento dei suoni sintetizzati (leggeri, senza asset).
const AUDIO_SAMPLE_RATE: int = 22050

# ------------------------------------------------------ Feedback animato ----
## Durata della comparsa morbida di menu e riepilogo, in secondi.
const UI_APPEAR_DURATION: float = 0.30
## Durata del pop di testi e pillole di feedback.
const UI_POP_DURATION: float = 0.26
## Durata del lampo colorato a schermo quando si attraversa un cancello.
const GATE_FLASH_DURATION: float = 0.42
const GATE_FLASH_ALPHA: float = 0.16
## Scintilla/onda della raccolta moneta nel mondo 3D.
const COIN_BURST_DURATION: float = 0.34
const COIN_BURST_RADIUS: float = 0.62

# --------------------------------------------------------- Auto Gialla/Nera -
const COLOR_CAR_BODY := Color(0.98, 0.80, 0.10)
const COLOR_CAR_BLACK := Color(0.11, 0.12, 0.15)
const COLOR_CAR_CABIN := Color(0.13, 0.16, 0.22)
const COLOR_CAR_ACCENT := Color(0.11, 0.12, 0.15)
const COLOR_CAR_RIM := Color(0.98, 0.80, 0.10)
const COLOR_TIRE := Color(0.09, 0.10, 0.12)
const COLOR_HEADLIGHT := Color(1.0, 0.96, 0.76)
const COLOR_TAILLIGHT := Color(0.96, 0.18, 0.18)

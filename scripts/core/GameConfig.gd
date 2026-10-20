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
	Color(0.62, 0.60, 0.50),
	Color(0.98, 0.80, 0.10),
	Color(0.99, 0.60, 0.12),
	Color(0.36, 0.86, 0.36),
	Color(0.18, 0.78, 0.90),
	Color(0.68, 0.40, 0.96),
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

const COLOR_GATE_POSITIVE := Color(0.18, 0.86, 0.45)
const COLOR_GATE_POSITIVE_STRONG := Color(0.20, 0.60, 0.98)
const COLOR_GATE_NEGATIVE := Color(0.94, 0.24, 0.27)
const COLOR_GATE_FRAME := Color(0.97, 0.98, 1.0)
const COLOR_GATE_OFF := Color(0.42, 0.44, 0.48)

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
const CAMERA_HEIGHT: float = 6.2
const CAMERA_DISTANCE: float = 10.2
const CAMERA_LOOK_AHEAD: float = 16.5
const CAMERA_LOOK_HEIGHT: float = 1.15
const CAMERA_FOV: float = 64.0
## 1.0 = la telecamera segue completamente l'auto: l'auto resta stabile al
## centro dell'inquadratura ed è la pista a scorrere lateralmente.
const CAMERA_LATERAL_FOLLOW: float = 1.0

# --------------------------------------------------------- Cielo / Luce -----
const COLOR_SKY_TOP := Color(0.24, 0.58, 0.95)
const COLOR_SKY_HORIZON := Color(0.75, 0.89, 0.99)
const COLOR_GROUND_HORIZON := Color(0.75, 0.89, 0.99)
const COLOR_AMBIENT := Color(0.78, 0.85, 0.94)
const COLOR_SUN := Color(1.0, 0.98, 0.92)

# --------------------------------------------------------- Pista / Prato ----
const COLOR_ROAD := Color(0.37, 0.39, 0.42)
const COLOR_LANE := Color(0.95, 0.96, 0.98)
const COLOR_CURB_PRIMARY := Color(0.94, 0.95, 0.97)
const COLOR_CURB_ACCENT := Color(0.90, 0.25, 0.23)

const COLOR_GRASS := Color(0.36, 0.72, 0.33)
const COLOR_GRASS_ALT := Color(0.31, 0.66, 0.29)
const COLOR_HILL := Color(0.34, 0.68, 0.37)

# --------------------------------------------------------- Decorazioni ------
const COLOR_TRUNK := Color(0.45, 0.31, 0.19)
const FOLIAGE_COLORS: Array[Color] = [
	Color(0.20, 0.58, 0.30),
	Color(0.28, 0.68, 0.34),
	Color(0.16, 0.50, 0.27),
	Color(0.36, 0.74, 0.34),
]
const COLOR_ROCK := Color(0.56, 0.59, 0.63)
const COLOR_POST := Color(0.92, 0.93, 0.95)

# --------------------------------------------------------- Auto Gialla/Nera -
const COLOR_CAR_BODY := Color(0.98, 0.80, 0.10)
const COLOR_CAR_BLACK := Color(0.11, 0.12, 0.15)
const COLOR_CAR_CABIN := Color(0.13, 0.16, 0.22)
const COLOR_CAR_ACCENT := Color(0.11, 0.12, 0.15)
const COLOR_CAR_RIM := Color(0.98, 0.80, 0.10)
const COLOR_TIRE := Color(0.09, 0.10, 0.12)
const COLOR_HEADLIGHT := Color(1.0, 0.96, 0.76)
const COLOR_TAILLIGHT := Color(0.96, 0.18, 0.18)

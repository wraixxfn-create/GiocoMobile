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

class_name GameConfig
extends RefCounted
## Parametri centrali del progetto: dimensioni, velocità e palette colori.
## Tutti i valori sono pensati per un'unità di misura = 1 metro.

# ------------------------------------------------------------------ Track ---
const TRACK_WIDTH: float = 6.0
const TRACK_LANE_COUNT: int = 3
const SEGMENT_LENGTH: float = 40.0
const SEGMENT_COUNT: int = 8

# -------------------------------------------------------------------- Car ---
const CAR_BASE_SPEED: float = 12.0
const CAR_LATERAL_SPEED: float = 11.0
const CAR_DRAG_SENSITIVITY: float = 0.014

# ------------------------------------------------------------------ Colori ---
const COLOR_SKY := Color(0.55, 0.78, 0.94)
const COLOR_AMBIENT := Color(0.72, 0.80, 0.90)

const COLOR_ROAD := Color(0.32, 0.36, 0.42)
const COLOR_LANE := Color(0.93, 0.95, 0.97)
const COLOR_EDGE := Color(1.0, 0.82, 0.28)

const COLOR_GRASS := Color(0.44, 0.76, 0.38)
const COLOR_GRASS_ALT := Color(0.38, 0.68, 0.33)

const COLOR_TRUNK := Color(0.42, 0.29, 0.19)
const FOLIAGE_COLORS: Array[Color] = [
	Color(0.22, 0.62, 0.33),
	Color(0.30, 0.72, 0.38),
	Color(0.16, 0.52, 0.30),
	Color(0.42, 0.78, 0.35),
]
const COLOR_ROCK := Color(0.55, 0.58, 0.62)

const COLOR_CAR_BODY := Color(0.90, 0.25, 0.28)
const COLOR_CAR_CABIN := Color(0.75, 0.90, 0.98)
const COLOR_CAR_ACCENT := Color(0.15, 0.16, 0.20)
const COLOR_TIRE := Color(0.12, 0.13, 0.16)
const COLOR_HEADLIGHT := Color(1.0, 0.95, 0.70)
const COLOR_TAILLIGHT := Color(0.95, 0.20, 0.20)

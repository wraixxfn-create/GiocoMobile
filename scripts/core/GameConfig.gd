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
const CAR_BASE_SPEED: float = 14.0
const CAR_LATERAL_SPEED: float = 11.5
const CAR_DRAG_SENSITIVITY: float = 0.015
const CAR_HALF_WIDTH_MARGIN: float = 1.05

# ----------------------------------------------------------------- Camera ---
const CAMERA_HEIGHT: float = 6.2
const CAMERA_DISTANCE: float = 10.2
const CAMERA_LOOK_AHEAD: float = 16.5
const CAMERA_LOOK_HEIGHT: float = 1.15
const CAMERA_FOV: float = 64.0
const CAMERA_FOLLOW_SPEED: float = 7.5

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

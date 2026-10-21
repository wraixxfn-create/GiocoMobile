class_name SceneryPalette
extends RefCounted
## Palette artistica del livello tropicale dimostrativo: un'unica fonte per
## colori di terreno, vegetazione, rocce, arredi e sfondo.
##
## Regole di progetto (perché questi colori):
## - la **strada** è un grigio-blu freddo e desaturato: arretra rispetto al
##   verde e lascia che le strisce bianche e i cancelli colorati siano i
##   contrasti più forti;
## - il **terreno** è un verde tropicale medio, con una fascia sabbiosa calda
##   lungo il bordo: separa pista e prato senza linee grafiche;
## - la **vegetazione** usa tre verdi coordinati (scuro, medio, chiaro) e un
##   verde-teal per le fronde in ombra: i volumi si leggono anche in controluce;
## - le **rocce** sono grigio-lilla: complementari al verde, mai nere;
## - gli **oggetti interattivi** (cancelli, monete, ostacoli) mantengono i
##   colori saturi di gameplay: verde/blu/rosso e oro, gli unici "accesi";
## - lo **sfondo** vira verso l'acquamarina e il lilla per la foschia, così le
##   tre fasce di profondità restano distinguibili.

# ------------------------------------------------------------------ Cielo ---

const SKY_TOP := Color(0.13, 0.53, 0.82)
const SKY_HORIZON := Color(0.62, 0.83, 0.88)
const SKY_GROUND := Color(0.30, 0.46, 0.38)
const SUN_COLOR := Color(1.0, 0.95, 0.84)
const AMBIENT_COLOR := Color(0.78, 0.90, 1.0)
const FOG_COLOR := Color(0.66, 0.82, 0.84)

# ----------------------------------------------------------------- Strada ---

const ROAD_BASE := Color(0.35, 0.37, 0.42)
const ROAD_EDGE := Color(0.28, 0.30, 0.34)
const ROAD_WEAR := Color(0.41, 0.43, 0.47)
const ROAD_PATCH := Color(0.28, 0.31, 0.37)
const ROAD_JOINT := Color(0.23, 0.26, 0.31)
const LANE_PAINT := Color(0.95, 0.94, 0.89)
const CURB_LIGHT := Color(0.94, 0.93, 0.88)
const CURB_RED := Color(0.84, 0.24, 0.24)
const CURB_SIDE := Color(0.78, 0.77, 0.73)

# ---------------------------------------------------------------- Terreno ---

## Fascia sabbiosa subito fuori dal cordolo.
const SAND := Color(0.66, 0.55, 0.37)
const SAND_DARK := Color(0.52, 0.43, 0.28)
## Prato: tre toni che si alternano a chiazze morbide.
const GRASS_DEEP := Color(0.12, 0.31, 0.18)
const GRASS_BASE := Color(0.18, 0.40, 0.22)
const GRASS_LIGHT := Color(0.28, 0.51, 0.25)
const GRASS_DRY := Color(0.43, 0.49, 0.26)

# ------------------------------------------------------------- Vegetazione ---

const FOLIAGE_DEEP := Color(0.09, 0.30, 0.20)
const FOLIAGE_MID := Color(0.14, 0.40, 0.24)
const FOLIAGE_LIGHT := Color(0.23, 0.52, 0.28)
const FOLIAGE_TIP := Color(0.38, 0.65, 0.32)
const FERN_GREEN := Color(0.18, 0.46, 0.26)
const FERN_LIGHT := Color(0.31, 0.58, 0.31)
const TRUNK := Color(0.55, 0.41, 0.29)
const TRUNK_LIGHT := Color(0.66, 0.52, 0.37)
const TRUNK_DARK := Color(0.38, 0.29, 0.22)
const COCONUT := Color(0.42, 0.31, 0.20)
const FLOWER_A := Color(1.0, 0.93, 0.55)
const FLOWER_B := Color(1.0, 0.56, 0.62)
const FLOWER_C := Color(0.98, 0.98, 0.96)

# ------------------------------------------------------------------ Rocce ---

const ROCK := Color(0.56, 0.55, 0.60)
const ROCK_LIGHT := Color(0.66, 0.65, 0.69)
const ROCK_DARK := Color(0.42, 0.42, 0.47)
const MOSS := Color(0.30, 0.52, 0.32)

# ------------------------------------------------------------------ Arredi ---

const WOOD := Color(0.47, 0.33, 0.23)
const WOOD_LIGHT := Color(0.60, 0.44, 0.30)
const THATCH := Color(0.78, 0.63, 0.38)
const THATCH_DARK := Color(0.67, 0.51, 0.30)
const FABRIC_RED := Color(0.86, 0.32, 0.28)
const FABRIC_CREAM := Color(0.95, 0.91, 0.82)
const FABRIC_TEAL := Color(0.15, 0.60, 0.60)
const SIGN_YELLOW := Color(0.98, 0.80, 0.24)
const SIGN_GREEN := Color(0.16, 0.55, 0.33)
const METAL := Color(0.72, 0.74, 0.77)

# ----------------------------------------------------------------- Sfondo ---

## Colline lontane: ogni fascia è più chiara e più fredda (foschia).
const HILL_NEAR := Color(0.28, 0.48, 0.38)
const HILL_MID := Color(0.45, 0.61, 0.55)
const HILL_FAR := Color(0.60, 0.71, 0.69)
const HILL_HAZE := Color(0.71, 0.80, 0.80)
const DISTANT_TREE := Color(0.29, 0.46, 0.38)

# ------------------------------------------------------------- Interattivi ---

## Colori di gameplay: non cambiano con lo scenario, sono i più saturi.
const GATE_GREEN := Color(0.13, 0.84, 0.43)
const GATE_BLUE := Color(0.20, 0.60, 1.0)
const GATE_RED := Color(0.95, 0.25, 0.31)
const COIN_GOLD := Color(1.0, 0.70, 0.10)
const COIN_HIGHLIGHT := Color(1.0, 0.93, 0.52)


## Palette di fogliame per indice (0..3), sempre coordinata.
static func foliage(index: int) -> Color:
	var colors: Array[Color] = [FOLIAGE_DEEP, FOLIAGE_MID, FOLIAGE_LIGHT, FOLIAGE_TIP]
	return colors[posmod(index, colors.size())]


## Verde della chioma più chiaro di un passo: dà volume alla parte alta.
static func foliage_highlight(index: int) -> Color:
	return foliage(index).lightened(0.14)


static func grass(index: int) -> Color:
	var colors: Array[Color] = [GRASS_DEEP, GRASS_BASE, GRASS_LIGHT, GRASS_DRY]
	return colors[posmod(index, colors.size())]

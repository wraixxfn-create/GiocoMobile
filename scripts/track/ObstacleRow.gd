class_name ObstacleRow
extends RefCounted
## Una fila di ostacoli: i pezzi che occupano parte della carreggiata su uno
## stesso piano Z (o quasi: i coni possono avere micro-sfasamenti visivi).
## È una struttura dati pura (nessun nodo): i pezzi veri e propri sono nodi
## `Obstacle` figli dell'ObstacleManager.
##
## Ogni fila è generata da una "formazione" deterministica (serial + difficoltà)
## e lascia SEMPRE un varco percorribile largo almeno GameConfig.OBSTACLE_GAP_MIN:
## gli strumenti `free_intervals()` / `widest_gap()` lo verificano e vengono
## usati anche dai test di giocabilità.

enum Formation { CONES, BARRIER, NARROW, MOVING }

## Piano della fila (coordinata Z mondo).
var z: float = 0.0
## Formazione generata (una delle quattro tipologie di ostacolo).
var formation: int = -1
## Difficoltà [0..1] usata al momento della generazione.
var difficulty: float = 0.0
## Identificativo deterministico della generazione (seme del layout).
var serial: int = -1
## I pezzi della fila (nodi Obstacle figli dell'ObstacleManager).
var obstacles: Array = []


## Rettangolo XZ corrente di un pezzo (con l'eventuale X interpolata).
static func piece_rect(piece: Obstacle, override_x: float = NAN) -> Rect2:
	return piece.collision_rect(override_x)


## Intervalli X liberi dai pezzi collidibili, entro [road_min, road_max].
## Restituisce un array di Vector2(start, end) ordinato: il varco più largo è
## sempre >= GameConfig.OBSTACLE_GAP_MIN per costruzione della formazione.
func free_intervals(road_min: float, road_max: float) -> Array:
	var occupied: Array = []
	for piece in obstacles:
		var obstacle := piece as Obstacle
		if obstacle == null or not obstacle.is_collidable():
			continue
		var rect := obstacle.collision_rect()
		occupied.append(Vector2(rect.position.x, rect.position.x + rect.size.x))
	occupied.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var free: Array = []
	var cursor := road_min
	for span in occupied:
		var interval: Vector2 = span
		if interval.y <= cursor:
			continue
		if interval.x > cursor:
			free.append(Vector2(cursor, minf(interval.x, road_max)))
		cursor = maxf(cursor, interval.y)
		if cursor >= road_max:
			break
	if cursor < road_max:
		free.append(Vector2(cursor, road_max))
	return free


## Varco più largo: Vector2(start, end); Vector2.ZERO se la fila è vuota.
func widest_gap(road_min: float, road_max: float) -> Vector2:
	var best := Vector2.ZERO
	var best_width := -1.0
	for interval in free_intervals(road_min, road_max):
		var gap: Vector2 = interval
		var width := gap.y - gap.x
		if width > best_width:
			best_width = width
			best = gap
	return best if best_width > 0.0 else Vector2.ZERO


func widest_gap_width(road_min: float, road_max: float) -> float:
	var gap := widest_gap(road_min, road_max)
	return maxf(gap.y - gap.x, 0.0)


## Centro del varco più largo: la "linea sicura" che il giocatore (e il pilota
## automatico dei test) segue per attraversare la fila senza urti.
func widest_gap_center(road_min: float, road_max: float) -> float:
	var gap := widest_gap(road_min, road_max)
	return (gap.x + gap.y) * 0.5


## True se la fila contiene almeno un pezzo nello stato indicato.
func has_piece_in_state(state: int) -> bool:
	for piece in obstacles:
		var obstacle := piece as Obstacle
		if obstacle != null and obstacle.state == state:
			return true
	return false


func active_piece_count() -> int:
	var count := 0
	for piece in obstacles:
		var obstacle := piece as Obstacle
		if obstacle != null and obstacle.is_collidable():
			count += 1
	return count

class_name CarEvolutionProfile
extends Resource
## Descrive UN stadio visivo dell'auto (un valore di `evolution_level`).
##
## È un Resource, quindi modificabile dall'inspector e sostituibile a runtime:
## contiene i colori, le statistiche di gioco e le proporzioni che il
## modello procedurale (`CarModelBuilder`) usa per generare la silhouette.
## Le misure sono in metri, l'auto è rivolta verso -Z e poggia sul piano y=0.
##
## Sostituire in futuro i modelli provvisori NON richiede di toccare questo
## file né la logica di evoluzione: basta impostare `model_scene` (oppure
## compilare `config/car_model_library.tres`) con la scena/.glb definitiva.

enum Silhouette {
	WRECK,      # Rottame: microcar sgangherata, alta e corta.
	HATCHBACK,  # Utilitaria: compatta a due volumi, spigolosa.
	SEDAN,      # Berlina: tre volumi, più lunga e con abitacolo alto.
	COUPE,      # Sportiva: bassa, profilo fastback, coda corta.
	SUPERCAR,   # Supercar: larghissima, motore centrale, grande alettone.
	HYPERCAR,   # Hypercar futuristica: targa bassa, cupola, pinne e luci a barra.
}

@export_group("Identità")
@export var level: int = 0
@export var stage_name: String = "UTILITARIA"
@export var silhouette: int = Silhouette.HATCHBACK

@export_group("Colori")
@export var body_color: Color = Color(0.98, 0.80, 0.10)
@export var trim_color: Color = Color(0.11, 0.12, 0.15)
@export var trim_alt_color: Color = Color(0.30, 0.31, 0.35)
@export var glass_color: Color = Color(0.13, 0.16, 0.22)
@export var rim_color: Color = Color(0.98, 0.80, 0.10)
@export var tire_color: Color = Color(0.09, 0.10, 0.12)
## Colore delle parti luminose: lampeggiano durante la trasformazione.
@export var glow_color: Color = Color(1.0, 0.90, 0.40)
@export var headlight_color: Color = Color(1.0, 0.96, 0.76)
@export var taillight_color: Color = Color(0.96, 0.18, 0.18)

@export_group("Statistiche di gioco")
## Moltiplicatore della velocità di avanzamento (1.0 = taratura di base).
@export_range(0.2, 3.0, 0.01) var speed_multiplier: float = 1.0
## Moltiplicatore della reattività dello sterzo (1.0 = taratura di base).
@export_range(0.2, 3.0, 0.01) var handling_multiplier: float = 1.0
## Durata dell'animazione di trasformazione verso questo stadio, in secondi.
@export_range(0.05, 2.0, 0.05) var transform_duration: float = (
	GameConfig.EVOLUTION_TRANSFORM_DURATION
)

@export_group("Proporzioni (metri)")
@export var body_width: float = 1.50
@export var body_length: float = 2.86
@export var body_height: float = 0.36
## Altezza del tetto (o della cupola) da terra: definisce il profilo.
@export var roof_height: float = 1.04
## Altezza del pianale: più bassa = auto più sportiva.
@export var ride_height: float = 0.30
@export var wheel_radius: float = 0.30
@export var wheel_width: float = 0.24
@export var rear_wheel_width: float = 0.24
@export var wheel_base_x: float = 0.72
@export var wheel_base_z: float = 1.02

@export_group("Ingombro (metri)")
## Mezza larghezza e mezza lunghezza reali, ruote comprese: servono al
## CarController per calcolare i limiti laterali sul cordolo.
@export var half_width: float = GameConfig.CAR_HALF_WIDTH
@export var half_length: float = GameConfig.CAR_HALF_LENGTH
## Posizione della barra spia dell'evoluzione, in coordinate del modello.
@export var pip_offset: Vector3 = Vector3(0.0, 1.10, 0.0)

@export_group("Modello definitivo")
## Scena 3D opzionale (es. .glb importato) per questo livello.
## Se presente sostituisce il modello procedurale senza cambiare la logica:
## la scena deve avere come radice un Node3D rivolto verso -Z; le ruote
## vengono cercate nei figli che iniziano per "Wheel" o nel gruppo "car_wheel".
@export var model_scene: PackedScene = null


## Ingombro laterale dell'auto ruotata di `yaw`: entra nel calcolo dei bordi.
func lateral_half_extent(yaw: float) -> float:
	return half_width * cos(yaw) + half_length * sin(yaw)


## Velocità di avanzamento risultante, in metri al secondo.
func speed_for(base_speed: float) -> float:
	return maxf(base_speed * speed_multiplier, 0.0)


## Reattività dello sterzo risultante (1/s).
func handling_for(base_response: float) -> float:
	return maxf(base_response * handling_multiplier, 0.0)


## Righe di testo pronte per l'HUD (velocità e sterzo).
func stats_text() -> String:
	return "VEL ×%.2f   STERZO ×%.2f" % [speed_multiplier, handling_multiplier]

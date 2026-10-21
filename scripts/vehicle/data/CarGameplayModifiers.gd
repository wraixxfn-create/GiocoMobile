class_name CarGameplayModifiers
extends Resource
## Modificatori puri di gameplay e ingombro fisico associati a un componente.
##
## Separato dalla geometria e dal controller: i valori vengono aggregati in modo
## deterministico per calcolare velocità, reattività dello sterzo e ingombri.

## Bonus additivo sul moltiplicatore di velocità di avanzamento (es. +0.04).
@export_range(-0.5, 1.0, 0.01) var speed_bonus: float = 0.0
## Bonus additivo sul moltiplicatore di reattività dello sterzo (es. +0.05).
@export_range(-0.5, 1.0, 0.01) var handling_bonus: float = 0.0

## Variazione della mezza larghezza fisica dell'auto (metri, es. ruote larghe).
@export_range(-0.20, 0.20, 0.005) var half_width_delta: float = 0.0
## Sporgenza anteriore aggiuntiva oltre il muso base (metri, es. splitter).
@export_range(-0.20, 0.35, 0.005) var front_overhang_delta: float = 0.0
## Sporgenza posteriore aggiuntiva oltre la coda base (metri, es. alettone GT).
@export_range(-0.20, 0.35, 0.005) var rear_overhang_delta: float = 0.0

## Fattore di scala sul raggio e sulla larghezza del pneumatico (solo slot ruote).
@export_range(0.80, 1.25, 0.01) var wheel_radius_scale: float = 1.0
@export_range(0.80, 1.35, 0.01) var wheel_width_scale: float = 1.0


func has_gameplay_effect() -> bool:
	return (
		not is_zero_approx(speed_bonus)
		or not is_zero_approx(handling_bonus)
		or not is_zero_approx(half_width_delta)
		or not is_zero_approx(front_overhang_delta)
		or not is_zero_approx(rear_overhang_delta)
		or not is_equal_approx(wheel_radius_scale, 1.0)
		or not is_equal_approx(wheel_width_scale, 1.0)
	)

class_name DrivingTuning
extends Resource
## Parametri centralizzati dei controlli di guida.
##
## Questo è l'unico punto da modificare per regolare la velocità di avanzamento
## e la sensibilità/reattività dello sterzo. Il valore predefinito è letto da
## res://config/driving_tuning.tres, quindi si può tarare anche dall'inspector
## senza toccare gli script.
##
## Unità: metri e secondi (1 unità = 1 metro).

@export_group("Avanzamento automatico")
## Velocità costante lungo l'asse della pista, in metri al secondo.
@export_range(1.0, 80.0, 0.5, "or_greater") var forward_speed: float = 14.0

@export_group("Spostamento laterale")
## Metri di spostamento per una larghezza schermo trascinata.
## Trascinare l'intera larghezza dello schermo sposta l'auto di questo valore.
@export_range(0.5, 20.0, 0.1, "or_greater") var drag_sensitivity: float = 7.0
## Velocità dello sterzo con frecce/A-D, in metri al secondo.
@export_range(0.5, 30.0, 0.5, "or_greater") var keyboard_lateral_speed: float = 11.0
## Reattività dell'inseguimento del punto target (1/s).
## Più alto = risposta più immediata; il movimento resta comunque interpolato.
@export_range(1.0, 60.0, 0.5, "or_greater") var lateral_response: float = 22.0
## Limite di sicurezza della velocità laterale, in metri al secondo.
## Evita scatti anche dopo trascinamenti molto bruschi; 0 = nessun limite.
@export_range(0.0, 80.0, 0.5, "or_greater") var max_lateral_speed: float = 26.0

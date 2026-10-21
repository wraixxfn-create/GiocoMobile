class_name CarBodySockets
extends RefCounted
## Descrittore metrico dei punti di montaggio offerti dalla carrozzeria attiva.
##
## Ogni slot periferico ha una trasformazione 3D (`Transform3D` in spazio locale
## veicolo: -Z fronte, +Z retro, +Y alto, y=0 suolo), dimensioni disponibili
## per l'adattamento proporzionale e tag di compatibilità meccanica.

var body_silhouette: int = CarEvolutionProfile.Silhouette.HATCHBACK
var body_length: float = 2.86
var body_width: float = 1.50
var roof_height: float = 1.04
var belt_height: float = 0.80
var sill_height: float = 0.22
var roof_span: Vector2 = Vector2(-0.5, 0.5)

var _sockets: Dictionary = {}
var _wheel_hubs: Array[Dictionary] = []


func set_socket(
	slot: int,
	xform: Transform3D,
	width: float,
	height: float,
	length: float,
	tags: PackedStringArray,
) -> void:
	_sockets[slot] = {
		"transform": xform,
		"width": maxf(width, 0.05),
		"height": maxf(height, 0.05),
		"length": maxf(length, 0.05),
		"tags": tags,
	}


func get_socket(slot: int) -> Dictionary:
	if _sockets.has(slot):
		return _sockets[slot]
	return {
		"transform": Transform3D.IDENTITY,
		"width": body_width,
		"height": 0.30,
		"length": 0.30,
		"tags": PackedStringArray(),
	}


func socket_transform(slot: int) -> Transform3D:
	return get_socket(slot)["transform"] as Transform3D


func socket_width(slot: int) -> float:
	return float(get_socket(slot)["width"])


func socket_height(slot: int) -> float:
	return float(get_socket(slot)["height"])


func socket_length(slot: int) -> float:
	return float(get_socket(slot)["length"])


func socket_tags(slot: int) -> PackedStringArray:
	return get_socket(slot)["tags"] as PackedStringArray


func has_tag(slot: int, tag: String) -> bool:
	return socket_tags(slot).has(tag)


func set_wheel_hubs(hubs: Array[Dictionary]) -> void:
	_wheel_hubs = hubs


func wheel_hub_count() -> int:
	return _wheel_hubs.size()


func wheel_hub(index: int) -> Dictionary:
	if index >= 0 and index < _wheel_hubs.size():
		return _wheel_hubs[index]
	return {
		"position": Vector3.ZERO,
		"side": -1.0 if index % 2 == 0 else 1.0,
		"is_rear": index >= 2,
		"base_radius": 0.30,
		"base_width": 0.24,
	}


## Calcola la scala adattiva per un eventuale modello 3D esterno (`PackedScene`)
## in modo che rispetti la larghezza/lunghezza del punto di attacco senza mai
## deformarsi oltre i limiti `min_fit_scale..max_fit_scale`.
func compute_external_fit_scale(part: CarPartDefinition) -> Vector3:
	if part == null:
		return Vector3.ONE
	var compat := part.resolved_compatibility()
	var scale_out := Vector3.ONE
	if compat.reference_width > 0.001:
		var target_w := socket_width(part.slot)
		var factor_x := clampf(
			target_w / compat.reference_width,
			compat.min_fit_scale,
			compat.max_fit_scale,
		)
		scale_out.x = factor_x
	if compat.reference_length > 0.001 and part.slot == CarPartSlot.Type.AERO:
		var target_l := socket_length(part.slot)
		scale_out.z = clampf(
			target_l / compat.reference_length,
			compat.min_fit_scale,
			compat.max_fit_scale,
		)
	return scale_out


## Sovrascrive i socket usando eventuali nodi tipizzati `CarMountPoint3D`
## presenti in una scena esterna, senza ispezionare i nomi dei nodi.
static func extract_from_scene(root: Node3D, base: CarBodySockets) -> CarBodySockets:
	if root == null or base == null:
		return base
	var hubs := base._wheel_hubs.duplicate(true)
	for node in _collect_mount_points(root):
		var mp := node as CarMountPoint3D
		if mp.slot == CarPartSlot.Type.WHEELS and mp.hub_index >= 0 and mp.hub_index < hubs.size():
			var hub: Dictionary = hubs[mp.hub_index]
			hub["position"] = mp.transform.origin
			hubs[mp.hub_index] = hub
		else:
			var prev := base.get_socket(mp.slot)
			var w := mp.available_width if mp.available_width > 0.0 else float(prev["width"])
			var h := mp.available_height if mp.available_height > 0.0 else float(prev["height"])
			var l := mp.available_length if mp.available_length > 0.0 else float(prev["length"])
			var tags := (
				mp.mount_tags
				if not mp.mount_tags.is_empty()
				else (prev["tags"] as PackedStringArray)
			)
			base.set_socket(mp.slot, mp.transform, w, h, l, tags)
	base.set_wheel_hubs(hubs)
	return base


static func _collect_mount_points(node: Node) -> Array[CarMountPoint3D]:
	var found: Array[CarMountPoint3D] = []
	for child in node.get_children():
		if child is CarMountPoint3D:
			found.append(child as CarMountPoint3D)
		found.append_array(_collect_mount_points(child))
	return found

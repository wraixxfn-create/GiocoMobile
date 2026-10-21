class_name VehicleRig
extends Node3D
## Rig modulare persistente dell'automobile.
##
## Possiede i punti di montaggio strutturali (`_slot_anchors`) e i quattro perni
## mozzo (`_wheel_hubs`), creati una sola volta e mai distrutti:
##   - Sostituire un componente periferico (ruote, spoiler, paraurti, motore,
##     scarico, aerodinamica) rimpiazza UNICAMENTE il nodo visivo di quello slot,
##     lasciando intatti la scocca, i mozzi (inclusa la rotazione/sterzata in
##     corso) e tutti gli altri componenti.
##   - Ogni parte installata è tracciata tramite riferimenti dati tipizzati
##     (`CarPartSlot.Type -> CarPartDefinition`), mai tramite ricerche sul nome
##     dei nodi della scena.

signal part_equipped(slot: int, part: CarPartDefinition)
signal loadout_applied(level: int)

const WHEEL_GROUP: StringName = &"car_wheel"

var _profile: CarEvolutionProfile = null
var _sockets: CarBodySockets = null
var _sprung_root: Node3D = null
var _slot_anchors: Dictionary = {}
var _slot_visuals: Dictionary = {}
var _wheel_hubs: Array[Node3D] = []
var _wheel_visuals: Array[Node3D] = []
var _equipped_parts: Dictionary = {}
var _slot_paint: Dictionary = {}
var _slot_glow: Dictionary = {}
var _pips: Array = []
var _effective_stats: Dictionary = {}
var _structure_ready: bool = false


func _ready() -> void:
	ensure_structure()


## Inizializza una sola volta l'ossatura persistente del veicolo (7 socket
## sospesi + 4 mozzi ruota indipendenti).
func ensure_structure() -> void:
	if _structure_ready:
		return
	_sprung_root = Node3D.new()
	_sprung_root.name = "SprungChassis"
	add_child(_sprung_root)

	for slot in CarPartSlot.ALL:
		if slot == CarPartSlot.Type.WHEELS:
			continue
		var anchor := Node3D.new()
		anchor.name = "Anchor_" + String(CarPartSlot.slug(slot))
		_sprung_root.add_child(anchor)
		_slot_anchors[slot] = anchor

	_wheel_hubs.clear()
	_wheel_visuals.resize(4)
	for i in 4:
		var hub := Node3D.new()
		hub.name = "Wheel%d" % i
		hub.add_to_group(WHEEL_GROUP)
		add_child(hub)
		_wheel_hubs.append(hub)
		_wheel_visuals[i] = null

	_structure_ready = true


## Applica un intero assetto `CarLoadout` (es. cambio stadio evolutivo) senza
## distruggere il rig né i perni ruota, preservando eventuali parti custom
## vincolate (`pinned_parts`) purché compatibili con la nuova carrozzeria.
func apply_loadout(
	loadout: CarLoadout,
	profile: CarEvolutionProfile,
	pinned_parts: Dictionary = {},
	current_level: int = 99,
	enforce_level: bool = false,
) -> void:
	ensure_structure()
	_profile = profile if profile != null else CarEvolutionCatalog.profile_for(1)
	if loadout == null:
		loadout = CarPartRegistry.loadout_for_stage(_profile.level)

	# 1. Monta/aggiorna prima la carrozzeria per ottenere i nuovi socket metrici.
	var target_body := loadout.get_part(CarPartSlot.Type.BODY)
	if pinned_parts.has(CarPartSlot.Type.BODY):
		var pinned_body := pinned_parts[CarPartSlot.Type.BODY] as CarPartDefinition
		if pinned_body != null and (not enforce_level or current_level >= pinned_body.required_level):
			target_body = pinned_body
	if target_body == null:
		target_body = CarPartRegistry.loadout_for_stage(_profile.level).get_part(CarPartSlot.Type.BODY)

	_mount_body_internal(target_body)

	# 2. Monta ciascun componente periferico sui nuovi socket, verificando la
	#    compatibilità di eventuali personalizzazioni fissate dal giocatore.
	for slot in CarPartSlot.ATTACHED:
		var fallback_part := loadout.get_part(slot)
		var chosen := fallback_part
		if pinned_parts.has(slot):
			var custom := pinned_parts[slot] as CarPartDefinition
			var check := CarCompatibilityValidator.validate(
				custom,
				target_body,
				_sockets,
				_equipped_parts,
				current_level,
				enforce_level,
			)
			if bool(check["ok"]):
				chosen = custom
		if chosen != null:
			var valid_choice := CarCompatibilityValidator.validate(
				chosen, target_body, _sockets, _equipped_parts, current_level, false
			)
			if not bool(valid_choice["ok"]) and fallback_part != null:
				chosen = fallback_part
			_mount_peripheral_internal(chosen)

	_refresh_alignment_and_stats()
	loadout_applied.emit(_profile.level)


## Sostituisce UN SINGOLO componente sul veicolo attivo senza ricostruire il
## resto della gerarchia. Restituisce `{ok, changed, reason, message}`.
func equip_part(
	part: CarPartDefinition,
	current_level: int = 99,
	enforce_level: bool = false,
) -> Dictionary:
	ensure_structure()
	if _profile == null:
		_profile = CarEvolutionCatalog.profile_for(GameConfig.EVOLUTION_START_LEVEL)
		apply_loadout(CarPartRegistry.loadout_for_stage(_profile.level), _profile)

	var body_part := get_equipped_part(CarPartSlot.Type.BODY)
	var validation := CarCompatibilityValidator.validate(
		part,
		body_part,
		_sockets,
		_equipped_parts,
		current_level,
		enforce_level,
	)
	if not bool(validation["ok"]):
		validation["changed"] = false
		return validation

	var current := get_equipped_part(part.slot)
	if current != null and current.id == part.id and _has_valid_visual(part.slot):
		return {
			"ok": true,
			"changed": false,
			"reason": CarCompatibilityValidator.Reason.OK,
			"message": "",
		}

	if part.slot == CarPartSlot.Type.BODY:
		var previous_attached: Dictionary = {}
		for slot in CarPartSlot.ATTACHED:
			if _equipped_parts.has(slot):
				previous_attached[slot] = _equipped_parts[slot]
		var stage_defaults := CarPartRegistry.loadout_for_stage(_profile.level)
		_mount_body_internal(part)
		for slot in CarPartSlot.ATTACHED:
			var prev_part := previous_attached.get(slot, null) as CarPartDefinition
			var chk := CarCompatibilityValidator.validate(
				prev_part, part, _sockets, _equipped_parts, current_level, false
			)
			if bool(chk["ok"]):
				# Riadatta la parte esistente alle dimensioni/tag della nuova scocca.
				_mount_peripheral_internal(prev_part)
			else:
				var fallback := _first_compatible_for_slot(slot, part, stage_defaults)
				if fallback != null:
					_mount_peripheral_internal(fallback)
				else:
					_clear_slot_visual(slot)
					_equipped_parts.erase(slot)
	else:
		_mount_peripheral_internal(part)

	_refresh_alignment_and_stats()
	part_equipped.emit(part.slot, part)
	return {
		"ok": true,
		"changed": true,
		"reason": CarCompatibilityValidator.Reason.OK,
		"message": "",
	}


# ------------------------------------------------------- Query tipizzate ----

func get_equipped_part(slot: int) -> CarPartDefinition:
	return _equipped_parts.get(slot, null) as CarPartDefinition


func get_equipped_part_id(slot: int) -> StringName:
	var part := get_equipped_part(slot)
	return part.id if part != null else &""


func is_part_equipped(part_id: StringName) -> bool:
	if part_id == &"":
		return false
	for slot in _equipped_parts.keys():
		var part := _equipped_parts[slot] as CarPartDefinition
		if part != null and part.id == part_id:
			return true
	return false


func equipped_parts() -> Dictionary:
	return _equipped_parts.duplicate()


func get_slot_anchor(slot: int) -> Node3D:
	ensure_structure()
	return _slot_anchors.get(slot, null) as Node3D


func get_slot_visual(slot: int) -> Node3D:
	return _slot_visuals.get(slot, null) as Node3D


func get_wheel_hubs() -> Array[Node3D]:
	ensure_structure()
	return _wheel_hubs


func get_wheel_visuals() -> Array[Node3D]:
	var copy: Array[Node3D] = []
	for item in _wheel_visuals:
		copy.append(item)
	return copy


func get_sockets() -> CarBodySockets:
	return _sockets


func get_sprung_root() -> Node3D:
	ensure_structure()
	return _sprung_root


func get_pips() -> Array:
	return _pips


func get_paint_meshes() -> Array:
	var out: Array = []
	for slot in _slot_paint.keys():
		for mi in _slot_paint[slot] as Array:
			if is_instance_valid(mi):
				out.append(mi)
	return out


func get_glow_entries() -> Array:
	var out: Array = []
	var seen: Array = []
	for slot in _slot_glow.keys():
		for entry in _slot_glow[slot] as Array:
			var d: Dictionary = entry
			var mat := d.get("material", null) as StandardMaterial3D
			if mat != null and not seen.has(mat):
				seen.append(mat)
				out.append(d)
	return out


func effective_stats() -> Dictionary:
	if _effective_stats.is_empty():
		_effective_stats = CarStatsAggregator.compute(_profile, _equipped_parts)
	return _effective_stats


# --------------------------------------------------------- Montaggio slot ---

func _mount_body_internal(body_part: CarPartDefinition) -> void:
	_clear_slot_visual(CarPartSlot.Type.BODY)
	var built := CarPartMeshBuilder.build_part(body_part, _profile, null)
	var inst := built.get(CarPartMeshBuilder.KEY_INSTANCE, null) as Node3D
	_sockets = built.get(CarPartMeshBuilder.KEY_SOCKETS, null) as CarBodySockets
	if _sockets == null:
		var fallback := CarBodyMeshBuilder.build_body(null, _profile)
		var tmp := fallback.get("instance", null) as Node3D
		if tmp != null:
			tmp.free()
		_sockets = fallback.get("sockets", null) as CarBodySockets

	var anchor := _slot_anchors[CarPartSlot.Type.BODY] as Node3D
	anchor.transform = Transform3D.IDENTITY
	if inst != null:
		anchor.add_child(inst)
	_slot_visuals[CarPartSlot.Type.BODY] = inst
	_equipped_parts[CarPartSlot.Type.BODY] = body_part
	_slot_paint[CarPartSlot.Type.BODY] = built.get(CarPartMeshBuilder.KEY_PAINT_MESHES, [])
	_slot_glow[CarPartSlot.Type.BODY] = built.get(CarPartMeshBuilder.KEY_GLOW_ENTRIES, [])
	_pips = built.get(CarPartMeshBuilder.KEY_PIPS, [])

	for slot in CarPartSlot.ATTACHED:
		if slot == CarPartSlot.Type.WHEELS:
			continue
		var slot_anchor := _slot_anchors[slot] as Node3D
		slot_anchor.transform = _sockets.socket_transform(slot)


func _mount_peripheral_internal(part: CarPartDefinition) -> void:
	if part == null:
		return
	var slot := part.slot
	_clear_slot_visual(slot)
	var built := CarPartMeshBuilder.build_part(part, _profile, _sockets)
	if slot == CarPartSlot.Type.WHEELS:
		var nodes: Array = built.get(CarPartMeshBuilder.KEY_WHEEL_NODES, [])
		for i in mini(nodes.size(), _wheel_hubs.size()):
			var wnode := nodes[i] as Node3D
			if wnode != null:
				_wheel_hubs[i].add_child(wnode)
				_wheel_visuals[i] = wnode
	else:
		var anchor := _slot_anchors.get(slot, null) as Node3D
		var inst := built.get(CarPartMeshBuilder.KEY_INSTANCE, null) as Node3D
		if anchor != null:
			anchor.transform = _sockets.socket_transform(slot)
			if inst != null:
				anchor.add_child(inst)
		_slot_visuals[slot] = inst

	_equipped_parts[slot] = part
	_slot_paint[slot] = built.get(CarPartMeshBuilder.KEY_PAINT_MESHES, [])
	_slot_glow[slot] = built.get(CarPartMeshBuilder.KEY_GLOW_ENTRIES, [])


func _clear_slot_visual(slot: int) -> void:
	if slot == CarPartSlot.Type.WHEELS:
		for i in _wheel_visuals.size():
			var prev_w := _wheel_visuals[i]
			if prev_w != null and is_instance_valid(prev_w):
				if prev_w.get_parent() != null:
					prev_w.get_parent().remove_child(prev_w)
				prev_w.free()
			_wheel_visuals[i] = null
	else:
		var prev := _slot_visuals.get(slot, null) as Node3D
		if prev != null and is_instance_valid(prev):
			if prev.get_parent() != null:
				prev.get_parent().remove_child(prev)
			prev.free()
		_slot_visuals.erase(slot)
	_slot_paint.erase(slot)
	_slot_glow.erase(slot)


func _refresh_alignment_and_stats() -> void:
	_effective_stats = CarStatsAggregator.compute(_profile, _equipped_parts)
	if _sockets == null:
		return
	var eff_radius := float(_effective_stats["wheel_radius"])
	var width_delta := 0.0
	var wheels_part := get_equipped_part(CarPartSlot.Type.WHEELS)
	if wheels_part != null:
		width_delta = wheels_part.resolved_modifiers().half_width_delta * 0.5

	for i in _wheel_hubs.size():
		var hub_data := _sockets.wheel_hub(i)
		var base_pos: Vector3 = hub_data["position"]
		var side := float(hub_data["side"])
		_wheel_hubs[i].position = Vector3(
			base_pos.x + side * width_delta,
			eff_radius,
			base_pos.z,
		)

	# Compensa verticalmente la massa sospesa se cambia il diametro pneumatico,
	# mantenendo ruote appoggiate a y=0 e passaruota centrati sul mozzo.
	var base_radius := float(_sockets.wheel_hub(0)["base_radius"])
	if _sprung_root != null:
		_sprung_root.position.y = eff_radius - base_radius


func _has_valid_visual(slot: int) -> bool:
	if slot == CarPartSlot.Type.WHEELS:
		return _wheel_visuals.size() == 4 and is_instance_valid(_wheel_visuals[0])
	var node := _slot_visuals.get(slot, null) as Node3D
	return node != null and is_instance_valid(node)


func _first_compatible_for_slot(
	slot: int,
	body_part: CarPartDefinition,
	stage_defaults: CarLoadout,
) -> CarPartDefinition:
	if stage_defaults != null:
		var def_part := stage_defaults.get_part(slot)
		var def_chk := CarCompatibilityValidator.validate(
			def_part, body_part, _sockets, _equipped_parts
		)
		if bool(def_chk["ok"]):
			return def_part
	var candidates := CarPartRegistry.compatible_parts_for_slot(
		slot, body_part, _sockets, _equipped_parts
	)
	return candidates[0] if not candidates.is_empty() else null

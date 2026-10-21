class_name UITheme
extends RefCounted
## Fabbrica di stile condivisa dall'interfaccia: etichette, pulsanti, pannelli,
## icone e texture generate a runtime.
##
## Tenere qui i valori visivi permette di cambiare l'aspetto della UI in un sol
## punto e mantiene `HUD.gd` concentrato su layout e comportamento. Anche i
## piccoli asset (moneta e spia) sono procedurali: nessun file esterno.

const FONT_DARK := Color(0.035, 0.07, 0.105)
const BUTTON_ACCENT := Color(0.27, 0.90, 0.53)
const BUTTON_NEUTRAL := Color(0.78, 0.86, 0.94)
const PANEL_BORDER := Color(0.44, 0.62, 0.80, 0.45)
const PANEL_BORDER_ACCENT := Color(0.42, 0.74, 0.95, 0.85)
const SHADOW := Color(0.0, 0.0, 0.0, 0.30)


# ---------------------------------------------------------------- Etichette ---

## Etichetta leggibile sopra la scena 3D: outline e ombra contenuti, testo
## bianco (il colore si sovrascrive quando serve una gerarchia).
static func label(text: String, font_size: int, alignment: int) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = Color.WHITE
	settings.outline_size = 4 if font_size >= 24 else 3
	settings.outline_color = Color(0.03, 0.06, 0.10, 0.92)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	settings.shadow_offset = Vector2(1.0, 2.0)

	var control := Label.new()
	control.text = text
	control.label_settings = settings
	control.horizontal_alignment = alignment
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


# ----------------------------------------------------------------- Pulsanti ---

## Pulsante touch-friendly (altezza minima 72 px). Il segnale `pressed` va
## collegato dal chiamante, che aggiunge anche il suono di conferma.
static func button(text: String, accent: bool) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(0.0, 72.0)
	control.focus_mode = Control.FOCUS_ALL
	control.add_theme_font_size_override("font_size", 25)
	control.add_theme_color_override("font_color", FONT_DARK)
	control.add_theme_color_override("font_hover_color", Color(0.02, 0.05, 0.08))
	control.add_theme_color_override("font_pressed_color", Color(0.02, 0.05, 0.08))
	control.add_theme_color_override("font_focus_color", Color(0.02, 0.05, 0.08))
	var base := BUTTON_ACCENT if accent else BUTTON_NEUTRAL
	apply_button_color(control, base)
	control.add_theme_stylebox_override("focus", button_style(base.lightened(0.05), true))
	return control


## Applica (o riapplica) la tinta di un pulsante, mantenendo gli stati hover
## e pressed coerenti. Usato anche per il pulsante audio.
static func apply_button_color(control: Button, base: Color) -> void:
	if control == null:
		return
	control.add_theme_stylebox_override("normal", button_style(base))
	control.add_theme_stylebox_override("hover", button_style(base.lightened(0.10)))
	control.add_theme_stylebox_override("pressed", button_style(base.darkened(0.14)))


static func button_style(color: Color, focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = SHADOW
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 3.0)
	style.anti_aliasing = true
	if focused:
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color.WHITE
	return style


# ------------------------------------------------------------------ Pannelli ---

static func panel_style(
	color: Color,
	accent_border: bool = false,
	radius: int = 24,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_BORDER_ACCENT if accent_border else PANEL_BORDER
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	style.anti_aliasing = true
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


static func progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.anti_aliasing = true
	return style


# -------------------------------------------------------------- Componenti ---

static func spacer(height: float) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(0.0, height)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


static func icon(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var control := TextureRect.new()
	control.texture = texture
	control.custom_minimum_size = icon_size
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


# ------------------------------------------------------- Texture procedurali ---

## Cerchio bianco con bordo morbido: colorato via `modulate` per le spie.
static func circle_texture(size: int = 24) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := center.x - 1.0
	for y in size:
		for x in size:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(radius - distance + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


## Moneta stilizzata: gradiente dorato, bordo più scuro, trasparenza ai lati.
static func coin_texture(size: int = 40) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := center.x - 1.0
	var outer := GameConfig.COLOR_COIN.darkened(0.30)
	for y in size:
		for x in size:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(radius - distance + 0.6, 0.0, 1.0)
			var ratio := clampf(distance / radius, 0.0, 1.0)
			var color := GameConfig.COLOR_COIN_HIGHLIGHT.lerp(GameConfig.COLOR_COIN, ratio)
			if ratio > 0.72:
				color = outer
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)

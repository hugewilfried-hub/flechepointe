extends Node

# ─────────────────────────────────────────────
#  SafeArea.gd — Autoload "SafeArea"
#  Calcule la marge à réserver en bas de l'écran pour éviter que les
#  boutons ne soient masqués par la barre de navigation Android
#  (mode immersif : la barre peut réapparaître par-dessus l'UI).
# ─────────────────────────────────────────────

## Marge basse (en pixels de viewport) à ajouter sous les boutons.
func get_bottom_inset() -> float:
	if not OS.has_feature("mobile"):
		return 0.0

	var screen_size := DisplayServer.screen_get_size()
	var safe_area    := DisplayServer.get_display_safe_area()
	var bottom_px    := screen_size.y - (safe_area.position.y + safe_area.size.y)

	if bottom_px <= 0:
		return 0.0

	var window_size := DisplayServer.window_get_size()
	if window_size.y <= 0:
		return float(bottom_px)

	var viewport_size := get_viewport().get_visible_rect().size
	var scale         := viewport_size.y / float(window_size.y)
	return bottom_px * scale

## Ajoute un espaceur en bas de `container` pour respecter la zone sûre.
func apply_bottom_spacer(container: Container) -> void:
	var inset := get_bottom_inset()
	if inset <= 0:
		return
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, inset)
	container.add_child(spacer)

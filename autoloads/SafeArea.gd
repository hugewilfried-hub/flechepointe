extends Node

# ─────────────────────────────────────────────
#  SafeArea.gd — Autoload "SafeArea"
#  Calcule l'espace à réserver en bas de l'écran pour éviter que les
#  boutons de l'interface ne soient recouverts par les éléments système
#  du téléphone (barre de navigation Android, geste retour/accueil,
#  home indicator iOS). Le mode plein écran/immersif ne supprime pas
#  toujours cette zone : sur beaucoup d'appareils à navigation par
#  gestes, une bande tactile reste réservée tout en bas et peut
#  intercepter les touchers même quand elle est invisible.
# ─────────────────────────────────────────────

## Hauteur (en unités de canevas, adaptée au stretch mode du projet) à
## réserver en bas de l'écran. `min_px` garantit toujours une marge
## minimale, y compris sur desktop où get_display_safe_area() ne
## renvoie généralement aucune zone masquée.
func bottom_inset(min_px: float = 16.0) -> float:
	var window_size := DisplayServer.window_get_size()
	if window_size.y <= 0:
		return min_px

	var safe := DisplayServer.get_display_safe_area()
	var bottom_gap: float = float(window_size.y - (safe.position.y + safe.size.y))
	if bottom_gap < 0.0:
		bottom_gap = 0.0

	# Conversion pixels d'écran réels -> unités de canevas : le viewport
	# du jeu peut être affiché à une échelle différente de la fenêtre
	# réelle selon le stretch mode du projet (canvas_items + expand ici).
	var viewport := get_viewport()
	var canvas_height: float = float(window_size.y)
	if viewport != null:
		canvas_height = viewport.get_visible_rect().size.y

	var scale_y: float = canvas_height / float(window_size.y)
	return max(bottom_gap * scale_y, min_px)

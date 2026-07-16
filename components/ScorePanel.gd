extends HBoxContainer

# ─────────────────────────────────────────────
#  ScorePanel.gd
#  Attaché au HBoxContainer racine de ScorePanel.tscn
#  Appelé depuis Game.gd via refresh(...)
#
#  Ce composant ne garde AUCUN état lui-même : à chaque appel de
#  refresh(), il détruit tous ses enfants et reconstruit entièrement le
#  tableau de scores à partir des données fraîches de GameData. C'est
#  volontairement "brutal" (pas d'optimisation à mettre à jour juste ce
#  qui change) mais ça évite tout bug de désynchronisation avec l'état
#  réel de la partie — l'affichage est toujours le reflet exact de
#  GameData.players au moment de l'appel.
# ─────────────────────────────────────────────

const MARK_ICONS := ["", "/", "✕", "●"]  # 0, 1, 2, 3 marques

# ─────────────────────────────────────────────
#  Point d'entrée public
# ─────────────────────────────────────────────

## Rafraîchit l'affichage complet.
## pending_pts = total de la volée en cours (pour 301/501)
func refresh(
		players: Array[Dictionary],
		current_idx: int,
		mode: GameData.GameMode,
		pending_pts: int) -> void:

	print("[ScorePanel] refresh() -> mode=%s, joueur courant=%d, pending=%d" % [
		GameData.GameMode.keys()[mode], current_idx, pending_pts
	])

	# Vider les colonnes précédentes (une carte par joueur, reconstruite
	# entièrement à chaque appel : voir la note en haut du fichier).
	for child in get_children():
		child.queue_free()

	for i in players.size():
		var p := players[i]
		var col := _make_player_column(p, i, current_idx, mode, pending_pts)
		add_child(col)

# ─────────────────────────────────────────────
#  Construction d'une colonne joueur
#  Une "colonne" = une carte (PanelContainer) contenant nom + score +
#  éventuellement une flèche "▲" si c'est ce joueur qui doit lancer.
#  Le contenu du score change totalement selon le mode (voir plus bas).
# ─────────────────────────────────────────────
func _make_player_column(
		p: Dictionary,
		idx: int,
		current_idx: int,
		mode: GameData.GameMode,
		pending_pts: int) -> PanelContainer:

	var is_current := (idx == current_idx)

	var card := PanelContainer.new()
	card.theme_type_variation  = &"ActivePanel" if is_current else &"PanelContainer"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	# ── Nom ─────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.text                 = p["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.theme_type_variation = &"AccentLabel" if is_current else &"MutedLabel"
	col.add_child(name_lbl)

	# ── Score principal ──────────────────────
	match mode:
		GameData.GameMode.MODE_301, GameData.GameMode.MODE_501:
			_add_score_301_501(col, p, idx, current_idx, pending_pts)
		GameData.GameMode.CRICKET:
			_add_score_cricket(col, p, idx, current_idx)
		GameData.GameMode.FREE_SCORE:
			_add_score_free(col, p)

	# ── Indicateur joueur actif ──────────────
	if is_current:
		var arrow := Label.new()
		arrow.text                 = "▲"
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.theme_type_variation = &"AccentLabel"
		col.add_child(arrow)

	return card

# ─────────────────────────────────────────────
#  Affichages selon le mode
# ─────────────────────────────────────────────
## Affichage 301/501 : montre le score restant, et si c'est le tour du
## joueur en cours, calcule un score "potentiel" en temps réel (score -
## points déjà lancés ce tour) pour prévisualiser le bust avant validation.
func _add_score_301_501(
		col: VBoxContainer,
		p: Dictionary,
		idx: int,
		current_idx: int,
		pending_pts: int) -> void:

	var displayed_score: int = p["score"]
	var is_current      := (idx == current_idx)

	# ── Score du tour en cours ────────────────
	var turn_lbl := Label.new()
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_lbl.theme_type_variation = &"MutedLabel"
	turn_lbl.text = "Tour: %d" % pending_pts if (is_current and pending_pts > 0) else "Tour: -"
	col.add_child(turn_lbl)

	# ── Score restant à faire ──────────────────
	var restant_lbl := Label.new()
	restant_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restant_lbl.theme_type_variation = &"MutedLabel"
	restant_lbl.text = "Restant"
	col.add_child(restant_lbl)

	var score_lbl := Label.new()
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.theme_type_variation = &"ScoreLabel"

	if is_current and pending_pts > 0:
		var potential: int = p["score"] - pending_pts
		if potential < 0:
			score_lbl.text = "BUST"
			score_lbl.add_theme_color_override("font_color", Color(0.7882, 0.2510, 0.1725))  # red
		else:
			score_lbl.text = str(potential)
			score_lbl.add_theme_color_override("font_color", Color(0.1725, 0.5412, 0.3059))  # green
	else:
		score_lbl.text = str(displayed_score)

	col.add_child(score_lbl)

## Affichage Cricket : le score de points en gros, puis une ligne
## horizontale avec une mini-colonne par numéro (15..20 + Bull) montrant
## sa marque actuelle (rien / "/" = 1 marque / "✕" = 2 marques /
## "●" = 3 marques = fermé). Couleur brass = en cours d'ouverture,
## vert = numéro fermé par ce joueur.
func _add_score_cricket(
		col: VBoxContainer,
		p: Dictionary,
		_idx: int,
		_current_idx: int) -> void:

	# Score en points
	var pts_lbl := Label.new()
	pts_lbl.text                  = str(p["cricket_score"])
	pts_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	pts_lbl.theme_type_variation  = &"ScoreLabel"
	pts_lbl.add_theme_font_size_override("font_size", 20)
	col.add_child(pts_lbl)

	# Marques par numéro (15..20 + Bull), alignées horizontalement
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)

	for n in GameData.CRICKET_NUMBERS:
		var marks: int = p["cricket_marks"].get(n, 0)
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 0)

		var n_lbl := Label.new()
		n_lbl.text = str(n) if n != 25 else "B"
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.theme_type_variation = &"MutedLabel"
		n_lbl.add_theme_font_size_override("font_size", 10)
		cell.add_child(n_lbl)

		var m_lbl := Label.new()
		m_lbl.text = MARK_ICONS[clamp(marks, 0, 3)]
		m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m_lbl.add_theme_font_size_override("font_size", 13)
		if marks >= 3:
			m_lbl.add_theme_color_override("font_color", Color(0.1725, 0.5412, 0.3059))  # green
		elif marks > 0:
			m_lbl.add_theme_color_override("font_color", Color(0.8196, 0.6471, 0.2392))  # brass
		cell.add_child(m_lbl)

		row.add_child(cell)

	col.add_child(row)

func _add_score_free(col: VBoxContainer, p: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text                 = str(p["free_score"])
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.theme_type_variation = &"ScoreLabel"
	col.add_child(lbl)

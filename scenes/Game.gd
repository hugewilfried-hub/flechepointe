extends Control

# ─────────────────────────────────────────────
#  Game.gd — CORRIGÉ
#
#  Cette scène est le plateau de jeu : elle affiche la cible, le tableau
#  de scores et les boutons "Annuler / Raté / Tour suivant". Elle ne
#  contient QUE la logique d'un tour (3 fléchettes max) ; les règles
#  de score (301/501/Cricket/Score libre) et l'état de la partie
#  (joueurs, manche, victoire) vivent dans l'Autoload GameData.
#
#  Boucle de jeu résumée :
#   1. Le joueur clique sur la cible (DartboardInput) -> _on_dart_thrown()
#   2. Chaque fléchette est stockée dans _darts (max 3) -> _register_dart()
#   3. Clic sur "Tour suivant" -> _apply_turn() applique les règles du
#      mode en cours sur GameData.players, puis GameData.next_player()
#      passe la main et on recommence un tour.
# ─────────────────────────────────────────────

const WIN_SCENE  := "res://scenes/WinScreen.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var lbl_round:   Label         = $VBoxContainer/top_bar/lbl_round
@onready var lbl_player:  Label         = $VBoxContainer/top_bar/lbl_current_player
@onready var lbl_double_out: Label      = $VBoxContainer/top_bar/lbl_double_out
@onready var btn_menu:    Button        = $VBoxContainer/top_bar/btn_menu
@onready var score_panel                = $VBoxContainer/score_panel/HBoxContainer
@onready var dartboard:   Control       = $VBoxContainer/dartboard
@onready var dart1:       Label         = $VBoxContainer/throw_panel/dart_row/dart1
@onready var dart2:       Label         = $VBoxContainer/throw_panel/dart_row/dart2
@onready var dart3:       Label         = $VBoxContainer/throw_panel/dart_row/dart3
@onready var lbl_total:   Label         = $VBoxContainer/throw_panel/dart_row/lbl_total
@onready var lbl_bust:    Label         = $VBoxContainer/throw_panel/lbl_bust
@onready var btn_undo:    Button        = $VBoxContainer/throw_panel/HFlowContainer/btn_undo
@onready var btn_miss:    Button        = $VBoxContainer/throw_panel/HFlowContainer/btn_miss
@onready var btn_next:    Button        = $VBoxContainer/throw_panel/HFlowContainer/btn_next
@onready var history_list: VBoxContainer = $VBoxContainer/history_panel/history_scroll/history_list
@onready var safe_area_spacer: Control   = $VBoxContainer/safe_area_spacer
#@onready var btn_end_free: Button       = $VBox/ThrowPanel/BtnRow/btn_End_Free
var btn_end_free: Button = null

# Les 3 fléchettes du tour en cours. Chaque entrée est un Dictionary
# {"number": int, "multiplier": int, "label": String}. Vidé à chaque
# nouveau tour (_on_next_turn).
var _darts: Array[Dictionary] = []

# true dès que le tour dépasse le score restant en 301/501 ("bust").
# Dans ce cas les 3 fléchettes du tour ne comptent pour rien.
var _bust: bool = false

# Journal des tours joués depuis le début de la partie (affiché dans
# history_panel), le plus récent en premier. Purement local à l'écran :
# repart de zéro à chaque nouvelle partie/rejoue (nouvelle instance de Game).
const MAX_HISTORY_ENTRIES := 50
var _turn_log: Array[String] = []

func _ready() -> void:
	print("[Game] _ready() -> mode=%s, joueur courant=%s" % [
		GameData.GameMode.keys()[GameData.game_mode],
		GameData.get_current_player()["name"]
	])

	# Réserve de l'espace en bas pour ne pas être recouvert par la barre
	# de navigation/gestes du téléphone (voir SafeArea.gd).
	safe_area_spacer.custom_minimum_size.y = SafeArea.bottom_inset()

	btn_end_free = get_node_or_null("VBoxContainer/throw_panel/HFlowContainer/btn_end_free")

	dartboard.dart_thrown.connect(_on_dart_thrown, CONNECT_REFERENCE_COUNTED)

	btn_undo.pressed.connect(_on_undo)
	btn_miss.pressed.connect(_on_miss)
	btn_next.pressed.connect(_on_next_turn)
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))

	# Le bouton "Terminer" (score libre) n'existe que pour ce mode, et
	# uniquement s'il a été laissé dans la scène (sinon il reste null,
	# géré par les gardes `btn_end_free != null` ci-dessous).
	if btn_end_free != null:
		btn_end_free.visible = (GameData.game_mode == GameData.GameMode.FREE_SCORE)
		if not btn_end_free.pressed.is_connected(_on_end_free):
			btn_end_free.pressed.connect(_on_end_free)

	# En mode Cricket, la cible assombrit les numéros qui ne comptent pas
	# (1-14) pour aider visuellement à viser les bons secteurs.
	dartboard.cricket_mode = (GameData.game_mode == GameData.GameMode.CRICKET)

	# Rappel visuel de la règle "sortie double" si elle est active (301/501 uniquement).
	lbl_double_out.visible = GameData.double_out and GameData.game_mode in [GameData.GameMode.MODE_301, GameData.GameMode.MODE_501]

	_start_turn()

# ─────────────────────────────────────────────
#  Réception d'une fléchette (clic sur la cible)
# ─────────────────────────────────────────────
func _on_dart_thrown(number: int, multiplier: int) -> void:
	print("[Game] Fléchette reçue : number=%d, multiplier=%d" % [number, multiplier])

	# Ignore si le tour est déjà complet (3 fléchettes) ou déjà "bust".
	if _darts.size() >= 3 or _bust:
		print("[Game] -> ignorée (tour complet ou bust)")
		return

	# En Cricket, un numéro hors 15-20/Bull ne rapporte jamais rien :
	# on affiche juste un petit message et on ne l'enregistre pas.
	if GameData.game_mode == GameData.GameMode.CRICKET:
		if number not in GameData.CRICKET_NUMBERS:
			print("[Game] -> hors jeu en Cricket (numéro %d)" % number)
			_show_feedback("Hors jeu")
			return

	_register_dart(number, multiplier)

## Bouton "✕ Raté" : simule une fléchette qui n'a touché aucune zone
## comptante. Elle occupe quand même un des 3 emplacements du tour
## (comme une vraie fléchette manquée), mais rapporte toujours 0 point
## et n'ouvre aucune marque de Cricket.
func _on_miss() -> void:
	print("[Game] Bouton Raté pressé")
	if _darts.size() >= 3 or _bust:
		print("[Game] -> ignoré (tour complet ou bust)")
		return
	_register_dart(0, 0)

## Point d'entrée commun pour ajouter une fléchette au tour, que ce soit
## via la cible (_on_dart_thrown) ou via le bouton Raté (_on_miss).
func _register_dart(number: int, multiplier: int) -> void:
	var label := _dart_to_label(number, multiplier)
	_darts.append({"number": number, "multiplier": multiplier, "label": label})
	print("[Game] Fléchette #%d ajoutée : %s (total du tour = %d)" % [_darts.size(), label, _turn_total()])

	# Règle du "bust" en 301/501 : si le total du tour dépasse le score
	# restant, le joueur "casse" (bust) et perdra son tour entier
	# (voir _apply_301_501). On le détecte dès la 1ère/2e/3e fléchette
	# pour prévenir immédiatement le joueur à l'écran.
	if GameData.game_mode in [GameData.GameMode.MODE_301, GameData.GameMode.MODE_501]:
		var potential: int = GameData.get_current_player()["score"] - _turn_total()
		if potential < 0:
			_bust = true
			print("[Game] BUST ! Score restant potentiel = %d (< 0)" % potential)

	_refresh_throw_panel()
	btn_next.disabled = false

## Convertit une fléchette (numéro + multiplicateur) en texte affiché
## dans la rangée dart1/dart2/dart3, ex: "T20" = Triple 20, "D25"/"Bull"
## = Bull (double), "Raté" = notre fléchette à 0 point.
func _dart_to_label(number: int, multiplier: int) -> String:
	if number == 0:
		return "Raté"
	if number == 25:
		return "Bull" if multiplier == 2 else "25"
	match multiplier:
		2: return "D%d" % number
		3: return "T%d" % number
		_: return str(number)

## Somme des points des fléchettes déjà lancées ce tour (numéro * multiplicateur).
func _turn_total() -> int:
	var total := 0
	for d in _darts:
		total += d["number"] * d["multiplier"]
	return total

# ─────────────────────────────────────────────
#  Annuler / Tour suivant
# ─────────────────────────────────────────────
func _on_undo() -> void:
	if _darts.is_empty():
		return
	var removed: Dictionary = _darts.pop_back()
	_bust = false  # on ré-évaluera le bust normalement à la prochaine fléchette
	print("[Game] Annulation de la dernière fléchette : %s" % removed["label"])
	_refresh_throw_panel()
	btn_next.disabled = _darts.is_empty()

func _on_next_turn() -> void:
	print("[Game] --- Fin de tour pour %s (fléchettes = %d) ---" % [
		GameData.get_current_player()["name"], _darts.size()
	])
	_apply_turn()

	if GameData.game_over:
		print("[Game] Partie terminée ! Gagnant = %s" % GameData.players[GameData.winner_index]["name"])
		get_tree().change_scene_to_file(WIN_SCENE)
		return

	GameData.next_player()
	_darts.clear()
	_bust = false
	_start_turn()

## Mode Score libre uniquement : le joueur peut arrêter la partie à tout
## moment (pas de score cible à atteindre). On applique son tour en
## cours, puis on cherche le meilleur score parmi tous les joueurs.
func _on_end_free() -> void:
	print("[Game] Fin de partie (Score libre) demandée par le joueur")
	_apply_free(GameData.get_current_player())
	GameData.game_over = true
	var best_score := -1
	for i in GameData.players.size():
		if GameData.players[i]["free_score"] > best_score:
			best_score = GameData.players[i]["free_score"]
			GameData.winner_index = i
	get_tree().change_scene_to_file(WIN_SCENE)

# ─────────────────────────────────────────────
#  Application des règles selon le mode
# ─────────────────────────────────────────────
func _apply_turn() -> void:
	var player := GameData.get_current_player()
	match GameData.game_mode:
		GameData.GameMode.MODE_301, GameData.GameMode.MODE_501:
			_apply_301_501(player)
		GameData.GameMode.CRICKET:
			_apply_cricket(player)
		GameData.GameMode.FREE_SCORE:
			_apply_free(player)

## Règles 301/501 : le score démarre à 301 ou 501 et diminue à chaque
## tour. Si le total du tour amène le score en dessous de 0 ("bust"),
## le tour entier est annulé et le score ne bouge pas. Atteindre
## exactement 0 déclenche la victoire.
func _apply_301_501(player: Dictionary) -> void:
	if _bust:
		print("[Game] %s a fait BUST -> score inchangé (%d)" % [player["name"], player["score"]])
		player["history"].append({"darts": _darts.duplicate(), "bust": true})
		_log_turn(player, true)
		return

	var total     := _turn_total()
	var new_score: int = player["score"] - total

	if new_score < 0:
		print("[Game] %s -> bust détecté à l'application (%d - %d < 0)" % [player["name"], player["score"], total])
		player["history"].append({"darts": _darts.duplicate(), "bust": true})
		_log_turn(player, true)
		return

	# Règle "sortie double" : si activée, atteindre 0 ne suffit pas, il
	# faut que la fléchette qui ramène le score à exactement 0 soit un
	# double (ou le Bull double = 50). Sinon, le tour est un bust classique
	# (le score ne bouge pas), comme dans une vraie partie de fléchettes.
	if new_score == 0 and GameData.double_out and not _finished_on_double(player["score"]):
		print("[Game] %s atteint 0 mais pas sur un double (sortie double active) -> BUST" % player["name"])
		player["history"].append({"darts": _darts.duplicate(), "bust": true})
		_log_turn(player, true)
		return

	player["score"] = new_score
	player["history"].append({"darts": _darts.duplicate(), "score_after": new_score})
	print("[Game] %s marque %d points -> score restant = %d" % [player["name"], total, new_score])
	_log_turn(player, false)

	if new_score == 0:
		print("[Game] %s atteint 0 pile -> VICTOIRE" % player["name"])
		GameData.game_over    = true
		GameData.winner_index = GameData.current_player_index

## Retrouve la fléchette qui a ramené le score à exactement 0 (première
## fléchette du tour dont le total cumulé égale le score de départ) et
## indique si c'est un double. Utilisé par la règle "sortie double".
func _finished_on_double(start_score: int) -> bool:
	var running := 0
	for d in _darts:
		running += d["number"] * d["multiplier"]
		if running == start_score:
			return d["multiplier"] == 2
	return false

## Règles Cricket : chaque numéro (15-20 + Bull) doit être "ouvert" avec
## 3 marques avant de rapporter des points. Une fléchette peut à la fois
## finir d'ouvrir un numéro ET commencer à marquer des points si son
## multiplicateur dépasse ce qu'il fallait pour l'ouvrir (ex: une triple
## sur un numéro à 1 marque ouvre les 2 marques manquantes + marque 1
## fois des points). Un numéro déjà fermé par le joueur ne rapporte plus
## rien si tous les adversaires l'ont aussi fermé (all_players_closed).
func _apply_cricket(player: Dictionary) -> void:
	for d in _darts:
		var n: int = d["number"]
		var m: int = d["multiplier"]

		if n not in GameData.CRICKET_NUMBERS:
			continue  # numéro hors jeu (ne devrait plus arriver ici, filtré en amont)

		var current_marks: int = player["cricket_marks"].get(n, 0)

		# Cas 1 : le numéro est déjà fermé (3 marques) -> tout le
		# multiplicateur devient des points (si un adversaire n'a pas
		# encore fermé ce numéro).
		if current_marks >= 3:
			if not GameData.all_players_closed(n):
				player["cricket_score"] += n * m
				print("[Game] %s marque %d pts sur le %d (déjà fermé)" % [player["name"], n * m, n])
			continue

		# Cas 2 : le numéro n'est pas encore fermé -> une partie du
		# multiplicateur sert à ouvrir les marques manquantes, le reste
		# (s'il y en a) devient des points immédiatement.
		var to_open   := mini(m, 3 - current_marks)
		var scoring_m := m - to_open
		player["cricket_marks"][n] += to_open
		print("[Game] %s ouvre %d marque(s) sur le %d (total = %d/3)" % [player["name"], to_open, n, player["cricket_marks"][n]])

		if player["cricket_marks"][n] >= 3 and scoring_m > 0:
			if not GameData.all_players_closed(n):
				player["cricket_score"] += n * scoring_m
				print("[Game] %s marque %d pts supplémentaires sur le %d (fermeture + surplus)" % [player["name"], n * scoring_m, n])

	player["history"].append({"darts": _darts.duplicate()})
	_log_turn(player, false)

	if GameData.cricket_win(GameData.current_player_index):
		GameData.game_over    = true
		GameData.winner_index = GameData.current_player_index

## Règles Score libre : pas de score cible, on additionne simplement les
## points de chaque tour. La partie se termine seulement via le bouton
## "Terminer" (_on_end_free), pas automatiquement.
func _apply_free(player: Dictionary) -> void:
	var total := _turn_total()
	player["free_score"] += total
	player["history"].append({"darts": _darts.duplicate(), "score_after": player["free_score"]})
	print("[Game] %s ajoute %d pts -> total = %d" % [player["name"], total, player["free_score"]])
	_log_turn(player, false)

# ─────────────────────────────────────────────
#  Rafraîchissement de l'interface
#  (appelé souvent : pas de print ici pour ne pas noyer la console,
#  les vrais événements de jeu sont déjà tracés plus haut)
# ─────────────────────────────────────────────
func _start_turn() -> void:
	_refresh_throw_panel()
	_refresh_top_bar()

func _refresh_top_bar() -> void:
	lbl_round.text  = "Manche %d" % GameData.round_number
	lbl_player.text = "🎯  %s" % GameData.get_current_player()["name"]

func _refresh_throw_panel() -> void:
	var labels := [dart1, dart2, dart3]
	for i in 3:
		labels[i].text = _darts[i]["label"] if i < _darts.size() else "—"
	lbl_total.text = "= %d" % _turn_total()

	lbl_bust.visible  = _bust
	btn_undo.disabled = _darts.is_empty()

	# En Score libre, "Tour suivant" reste toujours actif (le joueur peut
	# passer sans lancer, ou terminer via le bouton dédié).
	if GameData.game_mode != GameData.GameMode.FREE_SCORE:
		btn_next.disabled = _darts.is_empty()

	_refresh_score_panel()

## Transmet l'état courant au ScorePanel (composant réutilisable qui sait
## se dessiner différemment selon le mode). `pending` = le total du tour
## en cours, utilisé par ScorePanel pour afficher un score "potentiel"
## en 301/501 avant de valider le tour.
func _refresh_score_panel() -> void:
	var pending := 0
	if not _bust:
		pending = _turn_total()

	if score_panel != null and score_panel.has_method("refresh"):
		score_panel.refresh(
			GameData.players,
			GameData.current_player_index,
			GameData.game_mode,
			pending
		)

## Ajoute une ligne au journal des tours affiché dans history_panel, à
## partir de l'état du joueur APRÈS application du tour (bust ou non).
## Sert à visualiser le déroulé de la partie sans attendre le WinScreen.
func _log_turn(player: Dictionary, bust: bool) -> void:
	var darts_str := "—"
	if not _darts.is_empty():
		var labels: Array[String] = []
		for d in _darts:
			labels.append(d["label"])
		darts_str = " ".join(labels)

	var result_str: String
	if bust:
		result_str = "💥 Bust"
	else:
		match GameData.game_mode:
			GameData.GameMode.MODE_301, GameData.GameMode.MODE_501:
				result_str = "%d restant" % player["score"]
			GameData.GameMode.CRICKET:
				result_str = "%d pts" % player["cricket_score"]
			GameData.GameMode.FREE_SCORE:
				result_str = "%d pts" % player["free_score"]
			_:
				result_str = ""

	var entry := "M%d · %s : %s → %s" % [GameData.round_number, player["name"], darts_str, result_str]
	_add_history_entry(entry)

## Insère `entry` en tête du journal (le plus récent en haut) et borne sa
## taille pour ne pas accumuler indéfiniment de nœuds à l'écran.
func _add_history_entry(entry: String) -> void:
	_turn_log.push_front(entry)
	if _turn_log.size() > MAX_HISTORY_ENTRIES:
		_turn_log.resize(MAX_HISTORY_ENTRIES)
	_refresh_history_panel()

## Reconstruit entièrement la liste affichée (même logique "brutale" que
## ScorePanel.refresh : plus simple à maintenir qu'une mise à jour incrémentale).
func _refresh_history_panel() -> void:
	for child in history_list.get_children():
		child.queue_free()

	for entry in _turn_log:
		var lbl := Label.new()
		lbl.text                  = entry
		lbl.theme_type_variation  = &"MutedLabel"
		lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		history_list.add_child(lbl)

## Affiche un message temporaire (ex: "Hors jeu") puis revient à
## l'affichage normal du bust après 1.2 seconde.
func _show_feedback(msg: String) -> void:
	lbl_bust.text    = msg
	lbl_bust.visible = true
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		lbl_bust.text    = "💥 BUST !"
		lbl_bust.visible = _bust

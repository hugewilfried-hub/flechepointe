extends Node

# ─────────────────────────────────────────────
#  SaveManager.gd — Autoload "SaveManager"
#  Sauvegarde/chargement de parties en cours, pour pouvoir quitter et
#  reprendre plus tard. Chaque partie sauvegardée est un fichier JSON
#  dans user://saves/, contenant tout l'état nécessaire de GameData
#  pour reconstruire exactement où la partie en était.
#  Ne connaît rien de l'UI : Game.gd / MainMenu.gd appellent juste
#  save_game() / list_saves() / load_game() / delete_save().
# ─────────────────────────────────────────────

const SAVE_DIR := "user://saves"

## Crée le dossier de sauvegarde s'il n'existe pas encore.
func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

# ─────────────────────────────────────────────
#  Sauvegarde
# ─────────────────────────────────────────────
## Sauvegarde la partie en cours (état de GameData). Si GameData.current_save_id
## pointe déjà vers une sauvegarde existante (partie reprise puis re-sauvegardée),
## on écrase le même fichier plutôt que d'en créer un nouveau à chaque fois.
func save_game() -> void:
	_ensure_dir()

	var id := GameData.current_save_id
	if id == "":
		id = "save_%d" % Time.get_unix_time_from_system()
		GameData.current_save_id = id

	var data := {
		"label":                _build_label(),
		"saved_at":             Time.get_datetime_string_from_system(),
		"game_mode":            GameData.game_mode,
		"player_names":         GameData.player_names,
		"double_out":           GameData.double_out,
		"players":              GameData.players,
		"current_player_index": GameData.current_player_index,
		"round_number":         GameData.round_number,
		# Fléchettes déjà lancées ce tour-ci mais pas encore validées
		# ("Tour suivant" pas encore pressé) : sans ça, sauvegarder en
		# pleine volée ferait perdre silencieusement ces fléchettes.
		"pending_darts":        GameData.pending_darts,
		"pending_bust":         GameData.pending_bust,
	}

	var file := FileAccess.open("%s/%s.json" % [SAVE_DIR, id], FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Impossible d'écrire la sauvegarde %s" % id)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[SaveManager] Partie sauvegardée : %s" % id)

## Construit un libellé lisible pour la liste des reprises, ex:
## "501 · Joueur 1, Joueur 2 · Manche 3".
func _build_label() -> String:
	var mode_names := {
		GameData.GameMode.MODE_301:   "301",
		GameData.GameMode.MODE_501:   "501",
		GameData.GameMode.CRICKET:    "Cricket",
		GameData.GameMode.FREE_SCORE: "Score libre",
	}
	var names := ", ".join(GameData.player_names)
	return "%s · %s · Manche %d" % [mode_names.get(GameData.game_mode, "?"), names, GameData.round_number]

# ─────────────────────────────────────────────
#  Liste / lecture
# ─────────────────────────────────────────────
## Liste les sauvegardes disponibles, les plus récentes en premier.
## Chaque entrée : {id, label, saved_at}.
func list_saves() -> Array:
	_ensure_dir()
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var id := fname.trim_suffix(".json")
			var data: Variant = _read_save(id)
			if data != null:
				out.append({
					"id":       id,
					"label":    data.get("label", id),
					"saved_at": data.get("saved_at", ""),
				})
		fname = dir.get_next()
	dir.list_dir_end()

	out.sort_custom(func(a, b): return a["saved_at"] > b["saved_at"])
	return out

## Lit les données brutes d'une sauvegarde (pour construire un aperçu
## avant chargement, ex: récapitulatif dans une boîte de dialogue).
## Renvoie null si introuvable/corrompue. Contrairement à load_game(),
## ne modifie pas GameData.
func read_save(id: String) -> Variant:
	return _read_save(id)

func _read_save(id: String) -> Variant:
	var path := "%s/%s.json" % [SAVE_DIR, id]
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else null

# ─────────────────────────────────────────────
#  Chargement
# ─────────────────────────────────────────────
## Charge une sauvegarde dans GameData pour reprendre la partie là où
## elle en était. Renvoie false si la sauvegarde est introuvable/corrompue
## (fichier supprimé/modifié à la main, par ex.).
func load_game(id: String) -> bool:
	var data: Variant = _read_save(id)
	if data == null:
		push_error("[SaveManager] Sauvegarde introuvable ou corrompue : %s" % id)
		return false

	GameData.game_mode            = data["game_mode"]
	GameData.player_names         = _to_string_array(data["player_names"])
	GameData.double_out           = data.get("double_out", false)
	GameData.players              = _restore_players(data["players"])
	GameData.current_player_index = data["current_player_index"]
	GameData.round_number         = data["round_number"]
	GameData.game_over            = false
	GameData.winner_index         = -1
	GameData.current_save_id      = id
	GameData.pending_darts        = _restore_darts(data.get("pending_darts", []))
	GameData.pending_bust         = data.get("pending_bust", false)

	print("[SaveManager] Partie chargée : %s" % id)
	return true

## JSON renvoie un Array générique (Variant) : on le retype en Array[String]
## pour rester compatible avec GameData.player_names.
func _to_string_array(arr: Array) -> Array[String]:
	var out: Array[String] = []
	for s in arr:
		out.append(str(s))
	return out

## JSON ne connaît pas les entiers : tous les nombres reviennent en
## float (3 -> 3.0), et toutes les clés de Dictionary reviennent en
## String. On reconvertit ici tout ce qui doit rester un int pour que
## le reste du code (comparaisons, %d, indexation de tableau comme
## MARK_ICONS[marks]...) se comporte exactement comme sur une partie
## jamais sauvegardée.
func _restore_players(raw: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rp in raw:
		var p: Dictionary = rp

		p["score"]         = int(p.get("score", 0))
		p["free_score"]    = int(p.get("free_score", 0))
		p["cricket_score"] = int(p.get("cricket_score", 0))

		var marks: Dictionary = {}
		for k in p.get("cricket_marks", {}).keys():
			marks[int(k)] = int(p["cricket_marks"][k])
		p["cricket_marks"] = marks

		for turn in p.get("history", []) as Array:
			var t: Dictionary = turn
			if t.has("score_after"):
				t["score_after"] = int(t["score_after"])
			t["darts"] = _restore_darts(t.get("darts", []))

		out.append(p)
	return out

## Reconvertit "number"/"multiplier" en int dans une liste de fléchettes
## (utilisé pour l'historique des tours et pour pending_darts).
func _restore_darts(raw: Array) -> Array:
	var out: Array = []
	for rd in raw:
		var d: Dictionary = rd
		if d.has("number"):
			d["number"] = int(d["number"])
		if d.has("multiplier"):
			d["multiplier"] = int(d["multiplier"])
		out.append(d)
	return out

# ─────────────────────────────────────────────
#  Suppression
# ─────────────────────────────────────────────
## Supprime une sauvegarde (partie terminée normalement, ou suppression
## manuelle depuis la liste du menu).
func delete_save(id: String) -> void:
	var path := "%s/%s.json" % [SAVE_DIR, id]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] Sauvegarde supprimée : %s" % id)

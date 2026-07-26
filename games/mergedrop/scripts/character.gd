extends Node
## Autoload "Char" — «جغد» the owl, the game's companion.
##
## The character exists to give the player a voice that reacts to what they actually did:
## a streak worth protecting, a record within reach, a comeback after days away. Lines are
## picked from the player's real state, never at random, so it reads as attention rather
## than noise.

const ART := "res://assets/art/mascot.png"
const ART_CHEER := "res://assets/art/mascot_cheer.png"

## A line is {key, mood}. mood drives which artwork and colour is used.
enum Mood { HAPPY, CHEER, URGE }


func portrait(cheer := false) -> Texture2D:
	var path := ART_CHEER if cheer else ART
	return load(path) if ResourceLoader.exists(path) else null


## What the owl says on the menu, chosen by priority — the most relevant thing first.
func menu_line() -> Dictionary:
	var today := Time.get_date_string_from_system()
	var played_today: bool = Store.streak_last == today

	if Store.first_run:
		return {"key": "char_welcome", "mood": Mood.HAPPY}
	if Store.streak_count >= 3 and not played_today:
		return {"key": "char_streak_risk", "arg": I18n.digits(Store.streak_count), "mood": Mood.URGE}
	if not Store.pending_scores.is_empty():
		return {"key": "char_pending", "mood": Mood.HAPPY}
	if Online.last_rank > 0 and Online.last_rank <= 10:
		return {"key": "char_top_rank", "arg": I18n.digits(Online.last_rank), "mood": Mood.CHEER}
	if played_today:
		return {"key": "char_done_today", "mood": Mood.CHEER}
	if Store.games_played == 0:
		return {"key": "char_first_game", "mood": Mood.HAPPY}
	if Store.best_score > 0:
		return {"key": "char_beat_best", "arg": I18n.digits(Store.best_score), "mood": Mood.URGE}
	return {"key": "char_idle", "mood": Mood.HAPPY}


## What the owl says on the game-over screen.
func result_line(score: int, new_best: bool, rank: int) -> Dictionary:
	if new_best:
		return {"key": "char_new_best", "mood": Mood.CHEER}
	if rank > 0 and rank <= 3:
		return {"key": "char_podium", "arg": I18n.digits(rank), "mood": Mood.CHEER}
	if Store.best_score > 0 and score >= int(Store.best_score * 0.9):
		return {"key": "char_so_close", "mood": Mood.URGE}
	if score <= 0:
		return {"key": "char_try_again", "mood": Mood.HAPPY}
	return {"key": "char_good_run", "mood": Mood.HAPPY}


func text(line: Dictionary) -> String:
	var s := I18n.t(String(line.get("key", "")))
	if line.has("arg") and s.contains("%s"):
		s = s % line.arg
	return s

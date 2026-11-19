class_name DevMode
extends RefCounted
## The developer's own game (RyeeRue): running from the Godot editor, or the Developer build
## (export preset "Windows Developer", feature tag "developer").
## Only the developer can Import List (bring in players' creations) and use the reserved names.
## Players get new seeds from the official list that ships with every update instead.

const RESERVED := ["ryeru", "kepup"]  ## RyeeRue, KeepUpp, KeepUp - normalized (see normalize)


static var force_player := false  ## tests: behave like a player's game


static func on() -> bool:
	return not force_player and (OS.has_feature("editor") or OS.has_feature("developer"))


## Lowercase letters only, look-alike digits and symbols read as letters, repeats collapsed:
## "Ry33_Rue" -> "ryerue", "KEEP-UPP" -> "kepup", "K33pUp" -> "kepup".
static func normalize(user_name: String) -> String:
	var map := { "0": "o", "1": "i", "!": "i", "|": "i", "3": "e", "4": "a", "@": "a", "5": "s", "$": "s", "7": "t", "8": "b", "9": "g" }
	var out := ""
	for ch in user_name.to_lower():
		ch = map.get(ch, ch)
		if ch < "a" or ch > "z":
			continue
		if out.is_empty() or out[-1] != ch:
			out += ch
	return out


## A name players can't use: RyeeRue / KeepUpp / KeepUp or anything that looks like them.
static func is_reserved(user_name: String) -> bool:
	var n := normalize(user_name)
	for r in RESERVED:
		if n.contains(r):
			return true
	return false


## "" if this name is fine for a player, else why not.
static func name_problem(user_name: String) -> String:
	var n := user_name.strip_edges()
	if n == "":
		return "Pick a username first."
	if normalize(n).length() < 2:
		return "Use at least 2 letters."
	if is_reserved(n) and not on():
		return "That username is taken."
	return ""

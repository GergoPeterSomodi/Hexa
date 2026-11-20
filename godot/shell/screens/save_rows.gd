## The rows of the Save and Load screen (docs/architecture/m3-build-spec.md section 6.10), pure: Session.list_saves()
## rows in, the words and flags each row shows out. It lives in the shell because it formats the wall clock and the words.
## Each row: {slot, label, state, name, title, summary, detail, state_text, thumbnail, can_act, can_delete}.
class_name SaveRows
extends RefCounted

const SAVE_TAB := &"save"
const LOAD_TAB := &"load"
const QUICK_SLOT := "quick"
const AUTO_PREFIX := "auto"
const EMPTY_WORDS := "Empty slot"
const NO_PICK := "Choose your country"
const UNREADABLE := "Cannot be read"
const AUTOSAVE_WORD := "Autosave"
const SEP := " · "
const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const STATE_WORDS: Dictionary[StringName, String] = {
	&"newer": "Made by a newer Hexa",
	&"older": "Made by an older test build",
	&"other_map": "Made for another map",
	&"other_build": "Made by another build",
	&"broken": UNREADABLE,
}


## The rows for `tab`. The save tab has quicksave and slots 1 to 8 (no autosaves); the load tab has the autosaves first,
## newest first (empty slots last, ties in list order), then quicksave and slots 1 to 8 in their fixed order.
## `_now_unix` is the wall clock of the call: no M3 text is relative to it, so it is accepted and unused.
static func of(list: Array[Dictionary], tab: StringName, _now_unix: int) -> Array[Dictionary]:
	var offset := zone_offset_seconds()
	var autos: Array[Dictionary] = []
	var fixed: Array[Dictionary] = []
	for row: Dictionary in list:
		var slot := str(row.get("slot", ""))
		if not is_autosave(slot):
			fixed.append(row)
		elif tab == LOAD_TAB:
			autos.append(row)
	var out: Array[Dictionary] = []
	for row: Dictionary in _newest_first(autos):
		out.append(_row_of(row, tab, offset))
	for row: Dictionary in fixed:
		out.append(_row_of(row, tab, offset))
	return out


## The rows sorted by header saved_unix, newest first; a row with no save (empty) goes last; equal stamps keep their order.
static func _newest_first(rows: Array[Dictionary]) -> Array[Dictionary]:
	var keyed: Array = []
	for at: int in rows.size():
		var row := rows[at]
		var empty := StringName(row.get("state", &"empty")) == &"empty"
		var stamp := int((row.get("header", {}) as Dictionary).get("saved_unix", 0))
		keyed.append({"row": row, "at": at, "empty": empty, "stamp": stamp})
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["empty"] != b["empty"]:
			return not bool(a["empty"])
		if a["stamp"] != b["stamp"]:
			return int(a["stamp"]) > int(b["stamp"])
		return int(a["at"]) < int(b["at"]))
	var out: Array[Dictionary] = []
	for item: Dictionary in keyed:
		out.append(item["row"] as Dictionary)
	return out


## The words of a slot: "Quicksave", "Slot 3", "Autosave 1".
static func label_of(slot: String) -> String:
	if slot == QUICK_SLOT:
		return "Quicksave"
	if is_autosave(slot):
		return "%s %s" % [AUTOSAVE_WORD, slot.substr(AUTO_PREFIX.length())]
	return "Slot %s" % slot


static func is_autosave(slot: String) -> bool:
	return slot.begins_with(AUTO_PREFIX)


## The default name of a new save: "<country>, <date>", or only the date before the country pick (country "").
static func default_name(country: String, date: String) -> String:
	if country.is_empty():
		return date
	return "%s, %s" % [country, date]


## Seconds the local clock is ahead of UTC right now. Read from the two clocks, so no sign convention is assumed.
static func zone_offset_seconds() -> int:
	var now := int(Time.get_unix_time_from_system())
	var local_as_utc := Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return roundi(float(local_as_utc - now) / 60.0) * 60


## "17 Nov 2026, 14:32" for a Unix time shown at `offset_seconds` from UTC.
static func date_text(unix: int, offset_seconds: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(unix + offset_seconds)
	return "%d %s %d, %02d:%02d" % [
		int(dt["day"]), MONTHS[int(dt["month"]) - 1], int(dt["year"]), int(dt["hour"]), int(dt["minute"]),
	]


## "2 h 05 min" from whole seconds; under an hour, "42 min".
static func play_text(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var hours := floori(total / 3600.0)
	var minutes := floori((total % 3600) / 60.0)
	if hours > 0:
		return "%d h %02d min" % [hours, minutes]
	return "%d min" % minutes


## The country of a header, or NO_PICK for a scenario game before the country pick (the header's "" country).
static func who_of(header: Dictionary) -> String:
	var country := str(header.get("country", ""))
	return NO_PICK if country.is_empty() else country


## The state's words for a row that cannot be loaded or was made elsewhere; an unknown state reads as unreadable.
static func state_words(state: StringName) -> String:
	return str(STATE_WORDS.get(state, UNREADABLE))


static func _row_of(row: Dictionary, tab: StringName, offset: int) -> Dictionary:
	var slot := str(row.get("slot", ""))
	var state := StringName(row.get("state", &"empty"))
	var header := row.get("header", {}) as Dictionary
	var auto := is_autosave(slot)
	var label := label_of(slot)
	var out := {
		"slot": slot, "label": label, "state": state, "name": "", "title": label, "summary": "", "detail": "",
		"state_text": "", "thumbnail": str(row.get("thumbnail", "")), "can_act": false, "can_delete": false,
	}
	if state == &"empty":
		out["title"] = EMPTY_WORDS
		out["can_act"] = tab == SAVE_TAB and not auto
		return out
	if state == &"ok":
		var date := str(header.get("date", ""))
		var who := AUTOSAVE_WORD if auto else who_of(header)
		out["title"] = "%s%s%s" % [who, SEP, date]
		out["summary"] = "%s, %s" % [who, date]
		out["name"] = str(header.get("name", ""))
		out["detail"] = _detail_of(header, offset)
		out["can_act"] = true
		out["can_delete"] = true
		return out
	out["state_text"] = state_words(state)
	out["detail"] = _detail_of(header, offset) if not header.is_empty() else ""
	out["can_act"] = tab == SAVE_TAB and not auto
	out["can_delete"] = true
	return out


## "North Italy · saved 17 Nov 2026, 14:32 · played 2 h 05 min · Hexa 0.3.0".
static func _detail_of(header: Dictionary, offset: int) -> String:
	var parts: PackedStringArray = []
	var map_id := str(header.get("map_id", ""))
	if not map_id.is_empty():
		parts.append(map_id.capitalize())
	var saved := int(header.get("saved_unix", 0))
	if saved > 0:
		parts.append("saved " + date_text(saved, offset))
	parts.append("played " + play_text(int(header.get("play_seconds", 0))))
	var build := str(header.get("build", ""))
	if not build.is_empty():
		parts.append("Hexa " + build)
	return SEP.join(parts)

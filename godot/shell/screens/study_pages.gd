## The pages of the Statesman's Study and the milestone each one came in (docs/architecture/m4-build-spec.md 6.7).
## Each entry is {id, title, scene, since}. Economy (the "This season" tab) came in M4; its other tabs, Rankings and History
## came in M4.5 (docs/architecture/m4-5-build-spec.md 6.3).
class_name StudyPages
extends RefCounted

const LIST: Array[Dictionary] = [
	{id = &"economy", title = "Economy", scene = "res://shell/screens/study/page_economy.tscn", since = "4"},
	{id = &"rankings", title = "Rankings", scene = "res://shell/screens/study/page_rankings.tscn", since = "4.5"},
	{id = &"history", title = "History", scene = "res://shell/screens/study/page_history.tscn", since = "4.5"},
]


## The entries whose `since` milestone is at or before `milestone` ("4"); none when `milestone` is not a number.
static func shown(milestone: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not milestone.is_valid_float():
		return out
	var now := milestone.to_float()
	for entry: Dictionary in LIST:
		if str(entry.get("since", "0")).to_float() <= now:
			out.append(entry)
	return out

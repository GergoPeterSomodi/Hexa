## The pages of the Statesman's Study and the milestone each one came in (docs/architecture/m4-build-spec.md 6.7).
## Each entry is {id, title, scene, since}. LIST is empty in W11a; W11b adds Economy.
class_name StudyPages
extends RefCounted

const LIST: Array[Dictionary] = []


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

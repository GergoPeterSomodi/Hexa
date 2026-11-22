## The rules of a place-name key (a battle or siege name table, M7 5.2): a text of 1 to NAME_KEY_MAX characters with no control
## characters (below 32, or 127) and none of the digest separators ';', '=' and '|'. The digests join these keys with those
## separators, so a forged key must not be able to shift a segment. Pure data: no engine calls, no dependency on the systems.
class_name PlaceNames
extends RefCounted

## The longest place name a table may hold (a saved key past it is refused).
const NAME_KEY_MAX := 200
## The characters a key may never hold: the digest separators and DEL (control characters are tested by code).
const FORBIDDEN := ";=|"


## True when `key` is a place-name key: 1 to NAME_KEY_MAX characters, no control character, no separator.
static func key_ok(key: String) -> bool:
	if key.is_empty() or key.length() > NAME_KEY_MAX:
		return false
	for k: int in key.length():
		var code := key.unicode_at(k)
		if code < 32 or code == 127 or FORBIDDEN.contains(String.chr(code)):
			return false
	return true

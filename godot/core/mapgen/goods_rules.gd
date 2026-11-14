## The good each land province produces, by terrain, climate and place: a port of good_for in
## hexa/campaign/systems/worldgen.py and special_good in hexa/campaign/specialgoods.py (the frozen reference).
## Each call draws two luck rolls, in the Python order (the terrain roll, then the special-good roll).
class_name GoodsRules
extends RefCounted


## The good of a land province, or "" for none.
static func good_for(prov: Province, lon: float, lat: float, rng: Rng) -> String:
	var t := prov.terrain
	var roll := rng.randf()
	var americas := lon < -30.0
	var africa := lat < 17.0 and lon > -20.0
	var special := _special_good(lon, lat, t, rng.randf(), americas)
	if special != "":
		return special
	if t == "desert":
		if not prov.coastal:
			return ""
		return "salt" if roll < 0.5 else "fish"
	if t == "marsh":
		if prov.coastal and roll < 0.5:
			return "fish"
		return "wool" if roll < 0.75 else "grain"
	if t == "taiga":
		return "furs" if roll < 0.5 else "timber"
	if t == "snow":
		return "furs" if roll < 0.6 else ""
	if t == "savanna":
		if americas:
			if roll < 0.4:
				return "cotton"
			return "grain" if roll < 0.8 else "tobacco"
		if roll < 0.35:
			return "ivory"
		return "grain" if roll < 0.75 else "cotton"
	if t == "beach":
		if prov.coastal and roll < 0.45:
			return "fish"
		if americas or africa:
			return "sugar" if roll < 0.75 else "cotton"
		if roll < 0.6:
			return "salt"
		return "wine" if lat < 44.0 else "grain"
	if t == "tundra":
		return "fish" if (prov.coastal and roll < 0.4) else "furs"
	if t == "mountains" or (t == "hills" and roll < 0.3):
		if americas and lon < -95.0:
			return "silver"
		if _near(lon, lat, 13.0, 50.5) or _near(lon, lat, 11.5, 47.3, 1.5):
			return "silver"
		if _near(lon, lat, 18.9, 48.7, 1.5) or _near(lon, lat, -11.0, 13.5, 3.0) or _near(lon, lat, -1.5, 6.5, 3.0):
			return "gold"
		if t == "hills" and americas:
			return "furs" if lat > 42.0 else "timber"
		return "iron" if (roll < 0.8 or t == "hills") else "salt"
	if t == "jungle":
		if americas:
			if prov.coastal and roll < 0.6:
				return "sugar"
			return "tobacco" if roll < 0.75 else "timber"
		if _near(lon, lat, -1.5, 6.5, 3.5):
			return "gold" if roll < 0.5 else "ivory"
		return "ivory" if roll < 0.6 else "timber"
	if t == "forest":
		if (americas and lat > 42.0) or (lon > 22.0 and lat > 57.0):
			return "furs" if roll < 0.55 else "timber"
		if prov.coastal and lat > 48.0 and roll < 0.25:
			return "fish"
		return "timber"
	if t == "steppe":
		return "grain" if roll < 0.55 else "wool"
	if prov.coastal and (lat > 48.0 or (americas and lat > 40.0)) and roll < (0.6 if americas else 0.3):
		return "fish"
	if americas:
		if lat < 25.0:
			if lon < -95.0:
				return "grain" if roll < 0.6 else "cotton"
			if roll < 0.5:
				return "sugar"
			return "tobacco" if roll < 0.75 else "cotton"
		if 33.0 <= lat and lat <= 39.5:
			return "tobacco" if roll < 0.6 else "grain"
		return "grain"
	if africa:
		if roll < 0.5:
			return "grain"
		return "ivory" if roll < 0.75 else "cotton"
	if lat < 37.5 and lon > 29.0 and prov.coastal and roll < 0.45:
		return "spices"
	if lat < 44.5 and lon > -10.0 and lon < 40.0:
		if lon > 26.0 and roll < 0.25:
			return "cotton"
		if roll < 0.55:
			return "grain"
		return "wine" if roll < 0.9 else "wool"
	if _near(lon, lat, 20.0, 50.0, 1.0) or _near(lon, lat, 10.4, 53.25, 1.0) or _near(lon, lat, 13.0, 47.8, 1.0):
		return "salt"
	var wool := 0.35 if ((lon < 2.0 and lat > 50.0) or (lon > -7.0 and lon < -1.0 and lat > 39.0 and lat < 43.0)) else 0.15
	return "wool" if roll < wool else "grain"


## Horses, cattle, stone, copper, hemp, olives, silk, dyes, cocoa and coffee, where they belonged in 1480.
static func _special_good(lon: float, lat: float, t: String, r: float, americas: bool) -> String:
	if (t == "mountains" or t == "hills") and (_near(lon, lat, 15.5, 60.5, 3.0) or _near(lon, lat, 19.0, 48.7, 2.0)
			or _near(lon, lat, 13.0, 50.5, 1.5) or _near(lon, lat, 33.0, 35.0, 1.5)
			or (americas and lon < -95.0)) and r < 0.35:
		return "copper"
	if (t == "hills" or t == "mountains") and not americas and lat > 35.0:
		var stone_odds := 0.3 if _near(lon, lat, 10.5, 44.0, 3.0) else 0.16
		if r < stone_odds:
			return "stone"
	if t == "steppe" and r < 0.35:
		return "horses"
	if (t == "plains" or t == "savanna") and (_near(lon, lat, 19.5, 47.0, 3.0) or _near(lon, lat, -5.5, 37.5, 2.0)) \
			and r < 0.3:
		return "horses"
	if (t == "plains" or t == "marsh" or t == "steppe") and not americas and lat > 44.0 and lat < 56.0 and r < 0.12:
		return "cattle"
	if t == "savanna" and not americas and r < 0.15:
		return "cattle"
	if (t == "plains" or t == "marsh") and not americas and lat > 50.0 and lon > -6.0 and lon < 45.0 and r < 0.18:
		return "hemp"
	if (t == "plains" or t == "hills") and (_near(lon, lat, 29.0, 40.0, 2.5) or _near(lon, lat, 10.5, 45.2, 1.8)
			or _near(lon, lat, -3.6, 37.2, 1.0)) and r < 0.35:
		return "silk"
	if (t == "plains" or t == "hills" or t == "beach") and not americas and lat > 30.0 and lat < 43.8 \
			and lon > -10.0 and lon < 37.0 and r < 0.3:
		return "olives"
	if americas and (t == "jungle" or t == "savanna" or t == "plains") and lat < 22.0 and lon > -98.0:
		if r < 0.16:
			return "cocoa" if lon < -75.0 else "dyes"
		if r < 0.24:
			return "dyes"
	if (t == "hills" or t == "mountains" or t == "plains" or t == "savanna") and lon > 36.0 and lat > 8.0 \
			and lat < 18.0 and r < 0.4:
		return "coffee"
	return ""


## Python's near(x, y, r): inside a box of half-width r degrees around (x, y).
static func _near(lon: float, lat: float, x: float, y: float, r: float = 2.5) -> bool:
	return absf(lon - x) < r and absf(lat - y) < r

## The winter of a hex: the pieces kit's rule (tools/worldmap/pieces/kit.py cold_index and winter_of, GUIDE.md section 7)
## ported as it is. Latitude, height and the kilometres to the sea give one cold index; below MILD_BELOW the winter is
## mild, from SNOW_FROM it is snow, between them frost. Pure: no files, no engine calls.
class_name MapClimate
extends RefCounted

## The values stored in MapData.climate.
const SNOW := 0
const FROST := 1
const MILD := 2
const MILD_BELOW := 4.5
const SNOW_FROM := 8.0
## The kit's "far inland" distance to the sea, used when a map has no coast at all.
const FAR_INLAND_KM := 400.0


## How hard the winter is, as one number. lat: degrees north; height_m: the hex's height; sea_km: km from its centre to
## the sea (FAR_INLAND_KM when there is none). Within 25 km of the sea the height counts less, and not at all on the shore.
static func cold_index(lat: float, height_m: float, sea_km: float) -> float:
	var sea := maxf(0.0, sea_km)
	var warm := maxf(0.25, minf(1.0, (50.0 - lat) / 8.0))
	var settled := height_m * minf(1.0, sea / 25.0)
	return 0.5 * (lat - 36.0) + settled / 300.0 \
		- warm * (3.5 * maxf(0.0, 1.0 - sea / 40.0) + 2.0 * maxf(0.0, 1.0 - sea / 15.0)) \
		+ minf(2.0, sea / 300.0)


## SNOW, FROST or MILD for a hex.
static func winter_of(lat: float, height_m: float, sea_km: float) -> int:
	var cold := cold_index(lat, height_m, sea_km)
	if cold < MILD_BELOW:
		return MILD
	return FROST if cold < SNOW_FROM else SNOW


## The shortest distance from a point to a set of polylines (all in km), or FAR_INLAND_KM when there are none.
static func km_to_lines(p: Vector2, lines: Array[PackedVector2Array]) -> float:
	var best := INF
	for line: PackedVector2Array in lines:
		for s: int in line.size() - 1:
			var a := line[s]
			var ab := line[s + 1] - a
			var len2 := ab.length_squared()
			var t := 0.0 if len2 < 1e-12 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return FAR_INLAND_KM if best == INF else best

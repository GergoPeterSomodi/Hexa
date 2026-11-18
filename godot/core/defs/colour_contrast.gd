## Perceptual colour distance (CIE76 in Lab, D65) and Machado (2009) colour-vision deficiency simulations
## (docs/architecture/m2-build-spec.md section 4.6 and 5.1). Pure math on sRGB Color values.
class_name ColourContrast
extends RefCounted

enum Vision { NORMAL, PROTAN, DEUTAN, TRITAN }

const _D65_WHITE := Vector3(0.95047, 1.0, 1.08883)
const _LAB_EPSILON := 0.008856
const _LAB_KAPPA := 7.787
const _LAB_OFFSET := 16.0 / 116.0

const _PROTAN_MATRIX: Array[Vector3] = [
	Vector3(0.152286, 1.052583, -0.204868),
	Vector3(0.114503, 0.786281, 0.099216),
	Vector3(-0.003882, -0.048116, 1.051998),
]
const _DEUTAN_MATRIX: Array[Vector3] = [
	Vector3(0.367322, 0.860646, -0.227968),
	Vector3(0.280085, 0.672501, 0.047413),
	Vector3(-0.011820, 0.042940, 0.968881),
]
const _TRITAN_MATRIX: Array[Vector3] = [
	Vector3(1.255528, -0.076749, -0.178779),
	Vector3(-0.078411, 0.930809, 0.147602),
	Vector3(0.004733, 0.691367, 0.303900),
]


## CIE76 ΔE distance in Lab (D65) between two sRGB colours.
static func delta_e(a: Color, b: Color) -> float:
	return _to_lab(a).distance_to(_to_lab(b))


## Machado (2009) full-severity simulation in linear RGB, clamped to [0, 1] and re-encoded to sRGB.
static func simulate(c: Color, vision: Vision) -> Color:
	var rows := _vision_matrix(vision)
	if rows.is_empty():
		return c
	var lin := Vector3(_srgb_to_linear(c.r), _srgb_to_linear(c.g), _srgb_to_linear(c.b))
	var sr := _linear_to_srgb(clampf(lin.dot(rows[0]), 0.0, 1.0))
	var sg := _linear_to_srgb(clampf(lin.dot(rows[1]), 0.0, 1.0))
	var sb := _linear_to_srgb(clampf(lin.dot(rows[2]), 0.0, 1.0))
	return Color(sr, sg, sb, c.a)


## Minimum ΔE76 across normal, protan, deutan, and tritan vision.
static func worst_delta_e(a: Color, b: Color) -> float:
	var best := delta_e(a, b)
	for v: Vision in [Vision.PROTAN, Vision.DEUTAN, Vision.TRITAN]:
		best = minf(best, delta_e(simulate(a, v), simulate(b, v)))
	return best


static func _vision_matrix(vision: Vision) -> Array[Vector3]:
	match vision:
		Vision.PROTAN:
			return _PROTAN_MATRIX
		Vision.DEUTAN:
			return _DEUTAN_MATRIX
		Vision.TRITAN:
			return _TRITAN_MATRIX
		_:
			return []


static func _to_lab(c: Color) -> Vector3:
	var r := _srgb_to_linear(c.r)
	var g := _srgb_to_linear(c.g)
	var b := _srgb_to_linear(c.b)
	var x := 0.4124 * r + 0.3576 * g + 0.1805 * b
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := 0.0193 * r + 0.1192 * g + 0.9505 * b
	var fx := _lab_f(x / _D65_WHITE.x)
	var fy := _lab_f(y / _D65_WHITE.y)
	var fz := _lab_f(z / _D65_WHITE.z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _srgb_to_linear(c: float) -> float:
	var v := clampf(c, 0.0, 1.0)
	if v <= 0.04045:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)


static func _linear_to_srgb(c: float) -> float:
	var v := clampf(c, 0.0, 1.0)
	if v <= 0.0031308:
		return 12.92 * v
	return 1.055 * pow(v, 1.0 / 2.4) - 0.055


static func _lab_f(t: float) -> float:
	if t > _LAB_EPSILON:
		return pow(t, 1.0 / 3.0)
	return _LAB_KAPPA * t + _LAB_OFFSET

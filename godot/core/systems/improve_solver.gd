## The search of the improvement step: wave function collapse over the land hexes, as WorldCover's search. Each hex has a
## domain of options as bits; a propagation narrows the hexes within two hexes of each choice; a dead end undoes the last
## choice and strikes it out (backtracking); a search that uses up its budget restarts with the next draw of luck; after
## RETRIES restarts the undecided hexes stay wild. Split out of world_improve.gd (the old _search and its helpers, moved as
## they were): WorldImprove builds the inputs (domains, priors, neighbour tables, compatibility masks), calls solve, and reads
## dom back. Determinism: one Rng seeded by the caller; ties broken by a drawn order, never by the order of a dictionary.
class_name ImproveSolver
extends RefCounted

## The inputs, set by WorldImprove before solve.
var initial: PackedInt64Array = PackedInt64Array()  # per cell: the options it may take, as bits
var prior: PackedFloat32Array = PackedFloat32Array()  # one per cell and option; zero when not allowed
var nbr: PackedInt32Array = PackedInt32Array()  # six per cell: the neighbouring land cell or -1
var ring2: Array[PackedInt32Array] = []  # per cell: the land cells exactly two hexes away
var fixed: PackedByteArray = PackedByteArray()  # 1: the data decides this hex (a place)
var compat1: PackedInt64Array = PackedInt64Array()  # per option: the options it may touch
var compat2: PackedInt64Array = PackedInt64Array()  # per option: the options it may have two hexes away
var opt_family: PackedInt32Array = PackedInt32Array()
var all: int = 0  # every option's bit
## The result and the counts.
var dom: PackedInt64Array = PackedInt64Array()  # per cell: the options left (one bit when decided)
var backtracks: int = 0  # dead ends undone (all attempts)
var restarts: int = 0  # searches given up after the backtrack budget
var contradictions: int = 0  # propagation wipe-outs
var input_dead_ends: int = 0  # wipe-outs before any choice
var last_resort: Array[int] = []  # cells left wild by the fallback (none expected)

var _count: PackedInt32Array = PackedInt32Array()  # options left in each domain
var _single: PackedInt32Array = PackedInt32Array()  # the option of a decided cell, else -1
var _order: PackedInt32Array = PackedInt32Array()  # the drawn order that breaks ties between cells
var _trail_cell: PackedInt32Array = PackedInt32Array()
var _trail_old: PackedInt64Array = PackedInt64Array()
var _frame_cell: PackedInt32Array = PackedInt32Array()
var _frame_opt: PackedInt32Array = PackedInt32Array()
var _frame_tried: PackedInt64Array = PackedInt64Array()
var _frame_before: PackedInt64Array = PackedInt64Array()
var _frame_start: PackedInt32Array = PackedInt32Array()
var _rng: Rng = null
var _attempt_backtracks: int = 0


func solve(seed_value: int) -> void:
	_rng = Rng.new()
	_rng.seed_with(seed_value)
	var n := initial.size()
	_count.resize(n)
	_single.resize(n)
	_order.resize(n)
	for _attempt: int in ImproveRules.RETRIES + 1:
		_reset_domains()
		for i: int in n:
			_order[i] = _rng.randi_range(0, 1 << 30)
		_trail_cell.clear()
		_trail_old.clear()
		_clear_frames()
		_attempt_backtracks = 0
		var queue: Array[int] = []
		for i: int in n:
			if _count[i] == 1:
				queue.append(i)
		if not _propagate(queue):
			input_dead_ends += 1
			_reset_domains()
		if _run():
			return
		restarts += 1
	# Last resort: every hex still open stays wild (or takes its first option where "none" is not allowed).
	_reset_domains()
	for i: int in n:
		if _count[i] > 1:
			var keep := 1 if (int(initial[i]) & 1) == 1 else (1 << lowest_bit(int(initial[i])))
			_set_dom(i, keep)
			last_resort.append(i)


func _reset_domains() -> void:
	dom = initial.duplicate()
	for i: int in dom.size():
		_count[i] = popcount(int(dom[i]))
		_single[i] = lowest_bit(int(dom[i])) if _count[i] == 1 else -1


func _set_dom(cell: int, mask: int) -> void:
	dom[cell] = mask
	var count := popcount(mask)
	_count[cell] = count
	_single[cell] = lowest_bit(mask) if count == 1 else -1


## The backtracking loop of WorldCover._run: a frame is one decision; a dead end restores the newest frame and strikes
## its option; a frame with no option left is popped and the one below it restored in turn.
func _run() -> bool:
	var contradiction := false
	var result := false
	var running := true
	while running:
		if not contradiction:
			var cell := _pick_cell()
			if cell < 0:
				result = true
				running = false
			else:
				var opt := _pick_option(cell, int(dom[cell]))
				_frame_cell.append(cell)
				_frame_opt.append(opt)
				_frame_tried.append(0)
				_frame_before.append(dom[cell])
				_frame_start.append(_trail_cell.size())
				contradiction = not _assign(cell, opt)
		else:
			if _frame_cell.is_empty() or _attempt_backtracks >= ImproveRules.BACKTRACK_LIMIT:
				running = false
			else:
				_attempt_backtracks += 1
				backtracks += 1
				var top := _frame_cell.size() - 1
				_restore(int(_frame_start[top]))
				var tried := int(_frame_tried[top]) | (1 << int(_frame_opt[top]))
				_frame_tried[top] = tried
				var rem := int(_frame_before[top]) & ~tried
				if rem == 0:
					_pop_frame()
				else:
					var cell := int(_frame_cell[top])
					var opt := _pick_option(cell, rem)
					_frame_opt[top] = opt
					contradiction = not _assign(cell, opt)
	return result


func _clear_frames() -> void:
	_frame_cell.clear()
	_frame_opt.clear()
	_frame_tried.clear()
	_frame_before.clear()
	_frame_start.clear()


func _pop_frame() -> void:
	var top := _frame_cell.size() - 1
	_frame_cell.resize(top)
	_frame_opt.resize(top)
	_frame_tried.resize(top)
	_frame_before.resize(top)
	_frame_start.resize(top)


## The undecided cell with the fewest options; ties go to the lowest drawn order (not to the map's rows, so the
## districts do not grow in stripes). -1 when all are decided. A linear scan: fine for a region; Europe needs a heap.
func _pick_cell() -> int:
	var best := -1
	var best_count := 1 << 20
	var best_order := 0
	for i: int in _count.size():
		var count := _count[i]
		if count <= 1:
			continue
		if count < best_count or (count == best_count and _order[i] < best_order):
			best_count = count
			best_order = _order[i]
			best = i
	return best


## One option of a domain, drawn by weight: the prior, raised by decided neighbours of the same family and lowered by
## decided neighbours with the very same family and level.
func _pick_option(cell: int, mask: int) -> int:
	var options := opt_family.size()
	var same_family := PackedInt32Array()
	same_family.resize(ImproveRules.FAMILIES)
	same_family.fill(0)
	var same_option: Dictionary[int, int] = {}
	for d: int in 6:
		var nb := int(nbr[cell * 6 + d])
		if nb < 0 or _single[nb] < 0:
			continue
		var opt := _single[nb]
		same_family[opt_family[opt]] += 1
		same_option[opt] = int(same_option.get(opt, 0)) + 1
	var picked: Array[int] = []
	var weights: Array[float] = []
	var total := 0.0
	for opt: int in options:
		if ((mask >> opt) & 1) == 0:
			continue
		var f := opt_family[opt]
		var w := maxf(float(prior[cell * options + opt]), 0.0001)
		if f == ImproveRules.NONE:
			w *= 1.0 + ImproveRules.WILD_AFFINITY * float(same_family[ImproveRules.NONE])
		else:
			w *= 1.0 + ImproveRules.AFFINITY[f] * float(same_family[f])
			w *= pow(ImproveRules.SAME_PENALTY, float(int(same_option.get(opt, 0))))
		picked.append(opt)
		weights.append(w)
		total += w
	var x := _rng.randf() * total
	var acc := 0.0
	for k: int in picked.size():
		acc += weights[k]
		if x < acc:
			return picked[k]
	return picked[picked.size() - 1]


func _assign(cell: int, opt: int) -> bool:
	_push_trail(cell, int(dom[cell]))
	_set_dom(cell, 1 << opt)
	var queue: Array[int] = [cell]
	return _propagate(queue)


## Narrows the cells within two hexes of each queued cell to what its domain allows; false on a wipe-out. A fixed
## place is never narrowed (its conflicts are data: fixed_conflicts).
func _propagate(queue: Array[int]) -> bool:
	while not queue.is_empty():
		var j: int = queue.pop_back()
		var mask := int(dom[j])
		var near := _support(mask, compat1)
		if near != all:
			for d: int in 6:
				var k := int(nbr[j * 6 + d])
				if k >= 0 and not _narrow(k, near, queue):
					return false
		var far := _support(mask, compat2)
		if far != all and j < ring2.size():
			for k: int in ring2[j]:
				if not _narrow(k, far, queue):
					return false
	return true


func _narrow(cell: int, allow: int, queue: Array[int]) -> bool:
	if not fixed.is_empty() and fixed[cell] == 1:
		return true
	var before := int(dom[cell])
	var after := before & allow
	if after == before:
		return true
	_push_trail(cell, before)
	_set_dom(cell, after)
	if after == 0:
		contradictions += 1
		return false
	queue.append(cell)
	return true


## The options some option of a domain allows beside it. "None" allows everything, so an open hex narrows nothing.
func _support(mask: int, table: PackedInt64Array) -> int:
	if (mask & 1) == 1 and (int(table[0]) == all):
		return all
	var got := 0
	var m := mask
	var opt := 0
	while m != 0:
		if (m & 1) == 1:
			got = got | int(table[opt])
			if got == all:
				return got
		m = m >> 1
		opt += 1
	return got


func _push_trail(cell: int, old: int) -> void:
	_trail_cell.append(cell)
	_trail_old.append(old)


func _restore(start: int) -> void:
	while _trail_cell.size() > start:
		var last := _trail_cell.size() - 1
		_set_dom(int(_trail_cell[last]), int(_trail_old[last]))
		_trail_cell.resize(last)
		_trail_old.resize(last)


static func popcount(mask: int) -> int:
	var count := 0
	var m := mask
	while m != 0:
		m = m & (m - 1)
		count += 1
	return count


static func lowest_bit(mask: int) -> int:
	if mask == 0:
		return -1
	var opt := 0
	var m := mask
	while (m & 1) == 0:
		m = m >> 1
		opt += 1
	return opt

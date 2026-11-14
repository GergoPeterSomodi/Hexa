## A binary min-heap for the wave function's queue, ordered like Python's heapq on (count, tie, hex) tuples.
class_name MinHeap
extends RefCounted


class Entry:
	extends RefCounted
	var count: int
	var tie: float
	var pos: Vector2i

	func _init(p_count: int, p_tie: float, p_pos: Vector2i) -> void:
		count = p_count
		tie = p_tie
		pos = p_pos


var _items: Array[Entry] = []


func is_empty() -> bool:
	return _items.is_empty()


func push(entry: Entry) -> void:
	_items.append(entry)
	var i := _items.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if not _less(_items[i], _items[parent]):
			break
		_swap(i, parent)
		i = parent


func pop() -> Entry:
	var top: Entry = _items[0]
	var last: Entry = _items.pop_back()
	if not _items.is_empty():
		_items[0] = last
		var i := 0
		var n := _items.size()
		while true:
			var left := 2 * i + 1
			var right := left + 1
			var least := i
			if left < n and _less(_items[left], _items[least]):
				least = left
			if right < n and _less(_items[right], _items[least]):
				least = right
			if least == i:
				break
			_swap(i, least)
			i = least
	return top


func _swap(i: int, j: int) -> void:
	var held: Entry = _items[i]
	_items[i] = _items[j]
	_items[j] = held


static func _less(a: Entry, b: Entry) -> bool:
	if a.count != b.count:
		return a.count < b.count
	if a.tie != b.tie:
		return a.tie < b.tie
	return HexGrid.lex_less(a.pos, b.pos)

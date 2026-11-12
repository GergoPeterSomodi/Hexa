"""Digests of a whole game state that two processes, or a world and its reloaded copy, can compare.

    canonical(obj)      sha256 of a canonical serialisation of any game object graph
    world_digest(w)     canonical() of the game state of a Conquest, Colonisation or campaign world
    quick_digest(w)     a much cheaper digest that only tells whether this world object changed (pickle based:
                        compare it only with itself, in the same process)

``pickle.dumps`` is fine for "did this world change" inside one process (``worlds.digest``), but not across
processes: it writes sets in hash order (string hashes change with ``PYTHONHASHSEED``) and it records object
identity, even for strings. The serialisation here differs from pickle in only those two ways:

- sets and frozensets are written sorted, and object attributes in name order: both are unordered by nature;
- strings, numbers and tuples are written by value every time; lists, dicts and objects are written once and
  then referred to by number, so shared objects (a unit's ship, a province's market) and cycles still work.

Everything ordered stays in order: lists, and dicts in insertion order. Game code walks those in order, so an
order that differs between processes is a real difference and must change the digest.

No pygame here.
"""
import hashlib
import itertools
import pickle
import random
import types

_PLAIN = (type(None), bool, int, float, str, bytes)
_FLUSH = 4096


class _Encoder:
    def __init__(self, sink):
        self.sink = sink              # list of str tokens
        self.memo = {}                # id(obj) -> number, for lists, dicts, sets and objects
        self.keep = []                # keeps memoised objects alive, so their ids stay unique

    def ref(self, obj):
        n = self.memo.get(id(obj))
        if n is not None:
            self.sink.append(f"@{n}")
            return True
        self.memo[id(obj)] = len(self.memo)
        self.keep.append(obj)
        return False

    def encode(self, obj):
        out = self.sink
        t = type(obj)
        if t in _PLAIN:
            out.append(repr(obj))      # repr tells 1, 1.0, True and "1" apart; float repr is exact
            return
        if t is tuple:
            if all(type(e) in _PLAIN for e in obj):
                out.append(repr(obj))
                return
            out.append("(")
            for e in obj:
                self.encode(e)
            out.append(")")
            return
        if t is list:
            if self.ref(obj):
                return
            out.append("[")
            for e in obj:
                self.encode(e)
            out.append("]")
            return
        if t is dict:
            if self.ref(obj):
                return
            out.append("{")
            for k, v in obj.items():
                self.encode(k)
                self.encode(v)
            out.append("}")
            return
        if t is set or t is frozenset:
            if t is set and self.ref(obj):
                return
            out.append("s{" if t is set else "f{")
            out.extend(sorted(_element(e) for e in obj))
            out.append("}")
            return
        if t is random.Random:
            if self.ref(obj):
                return
            out.append("Random")
            self.encode(obj.getstate())
            return
        if t is itertools.count:
            out.append(repr(obj))      # "count(17)": the next id, without using it up
            return
        if t is types.ModuleType or t is types.FunctionType or t is type:
            out.append(f"<{t.__name__} {getattr(obj, '__module__', '')}.{obj.__name__}>")
            return
        if hasattr(obj, "__dict__"):
            if self.ref(obj):
                return
            out.append(f"<{t.__module__}.{t.__qualname__}")
            attrs = vars(obj)
            for name in sorted(attrs):
                out.append(name)
                self.encode(attrs[name])
            out.append(">")
            return
        raise TypeError(f"digest: don't know how to write a {t.__module__}.{t.__qualname__}")


def _element(obj):
    """The canonical text of one set element (set elements are hashable, so nearly always plain values)."""
    if type(obj) in _PLAIN or (type(obj) is tuple and all(type(e) in _PLAIN for e in obj)):
        return repr(obj)
    tokens = []
    _Encoder(tokens).encode(obj)
    return "\x1e".join(tokens)


def canonical(obj):
    """The sha256 (hex) of a canonical serialisation of obj (see the module docstring)."""
    tokens = []
    _Encoder(tokens).encode(obj)
    h = hashlib.sha256()
    for i in range(0, len(tokens), _FLUSH):
        h.update("\x1f".join(tokens[i:i + _FLUSH]).encode("utf-8", "surrogatepass"))
        h.update(b"\x1f")
    return h.hexdigest()


def world_state(world):
    """The part of a world that is game state, as a dict.

    Conquest and Colonisation: every attribute (they hold no caches). The campaign: the attributes the
    pristine guard compares (``worlds._STATE``: no lazy caches, no map source), plus the unit id counter."""
    if getattr(world, "mode", None) == "campaign":
        from tests.support.worlds import _STATE
        state = {name: getattr(world, name) for name in _STATE if hasattr(world, name)}
        state["rng"] = world.rng
        state["_ids"] = world._ids
        return state
    return dict(vars(world))


def world_digest(world):
    return canonical(world_state(world))


def quick_digest(world):
    """Whether the game state changed, cheaply: a pickle of the same attributes as world_digest.

    Within one process an untouched object pickles to the same bytes, so this is enough to see that a refused
    action changed nothing (and ten times faster). Never compare it across processes or copies of a world."""
    if getattr(world, "mode", None) == "campaign":
        from tests.support.worlds import digest
        return digest(world)
    state = dict(vars(world))
    state["_ids"] = repr(state.get("_ids"))        # itertools.count can't be pickled on Python 3.14+
    return hashlib.sha256(pickle.dumps(state, protocol=pickle.HIGHEST_PROTOCOL)).hexdigest()

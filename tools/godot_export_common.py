"""Shared helpers for the Godot exporters: `export_data.py`, `export_geography.py` and `export_map_reference.py`.

The exporters only read the frozen Python game (`hexa/`, imported, never edited) and write plain JSON under
`godot/data/`. Nothing here is game logic. The helpers:

- `plain(value)`: turns a game table (tuples, dataclasses, dicts with string keys, numbers) into JSON-ready
  lists and dicts. Anything else (a function, a lambda, a module) is an error, so a table that cannot be exported
  is noticed here and not silently written as text.
- `dump(path, obj)`: writes JSON with non-ASCII kept as UTF-8 and floats in Python's shortest round-trip form
  (`repr`), so every float reads back to the same double in Godot's JSON parser.
- `function_ir(path, names)`: the source of named top-level functions as a small list of steps (see the README
  under godot/data/). The steps are produced by walking the AST, so nothing is retyped by hand.
"""
import ast
import dataclasses
import json
import math
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

DATA_DIR = REPO / "godot" / "data"
GEO_DIR = DATA_DIR / "geography"
RULES_DIR = DATA_DIR / "rules"
CAMPAIGN_DIR = REPO / "hexa" / "campaign"


def plain(value):
    """A JSON-ready copy of a game value. Raises TypeError for anything that is not plain data."""
    if value is None or isinstance(value, (bool, int, str)):
        return value
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            raise ValueError(f"not a finite number: {value!r}")
        return value
    if dataclasses.is_dataclass(value) and not isinstance(value, type):
        return {f.name: plain(getattr(value, f.name)) for f in dataclasses.fields(value)}
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            if not isinstance(key, str):
                raise TypeError(f"dict key is not a string: {key!r}")
            out[key] = plain(item)
        return out
    if isinstance(value, (tuple, list)):
        return [plain(item) for item in value]
    if isinstance(value, (set, frozenset)):
        return sorted(plain(item) for item in value)
    raise TypeError(f"not plain data: {type(value).__name__}")


def text(obj):
    """The JSON text dump() writes (also used by the tests to compare with the committed files)."""
    return json.dumps(obj, ensure_ascii=False, indent=1) + "\n"


def dump(path, obj):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text(obj), encoding="utf-8", newline="\n")
    return path


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


# ----- function steps (the Python builder as data) -----------------------------------------------------------
def _value(node):
    """An expression as a step value: literals stay literal, a name or a dict is tagged, the rest is source text."""
    if node is None:
        return None
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, ast.Name):
        return {"name": node.id}
    if isinstance(node, ast.Dict):
        return {"dict": [[_value(k), _value(v)] for k, v in zip(node.keys, node.values)]}
    if isinstance(node, (ast.Tuple, ast.List)):
        return {"list": [_value(e) for e in node.elts]}
    return {"expr": ast.unparse(node)}


def _steps(stmts, when, out):
    for stmt in stmts:
        if isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Constant) and isinstance(stmt.value.value, str):
            continue                                      # docstring
        if isinstance(stmt, ast.If):
            test = ast.unparse(stmt.test)
            _steps(stmt.body, when + [test], out)
            _steps(stmt.orelse, when + [f"not ({test})"], out)
        elif isinstance(stmt, ast.Return):
            out.append({"when": when, "op": "return", "value": _value(stmt.value)})
        elif isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
            out.append({"when": when, "op": "assign", "var": stmt.targets[0].id, "value": _value(stmt.value)})
        elif isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Subscript) \
                and isinstance(stmt.targets[0].value, ast.Name):
            target = stmt.targets[0]
            out.append({"when": when, "op": "set", "var": target.value.id, "key": _value(target.slice),
                        "value": _value(stmt.value)})
        elif isinstance(stmt, (ast.For, ast.While)):
            head = (f"for {ast.unparse(stmt.target)} in {ast.unparse(stmt.iter)}" if isinstance(stmt, ast.For)
                    else f"while {ast.unparse(stmt.test)}")
            body = []
            _steps(stmt.body, [], body)
            out.append({"when": when, "op": "loop", "head": head, "body": body})
        else:
            out.append({"when": when, "op": "stmt", "text": ast.unparse(stmt)})


def function_ir(path, names=None):
    """{name: {"line", "params", "steps"}} for the named top-level functions of one Python file (all of them if names is None).

    `steps` are in source order. Each has `when` (the if-tests that must all hold, as source text; an else
    is the negated test), and an `op`: `assign` (var = value), `set` (var[key] = value), `return`, `loop`
    (head text and its body steps) or `stmt` (any other statement, as text). Values are literals, `{"name"}`,
    `{"dict": [[k, v]...]}`, `{"list": [...]}` or `{"expr": source}`.
    """
    path = Path(path)
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    found = {}
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and (names is None or node.name in names):
            steps = []
            _steps(node.body, [], steps)
            found[node.name] = {"line": node.lineno, "params": [a.arg for a in node.args.args], "steps": steps}
    missing = set(names or ()) - set(found)
    if missing:
        raise KeyError(f"{path.name}: no top-level function {sorted(missing)}")
    return found


def module_constants(path, names):
    """{name: value} for top-level constants of one Python file, read with ast.literal_eval (not imported).

    Used for the few constants the exporters need that are private to their module (names starting with an
    underscore), so no exporter reaches into another module's private names.
    """
    path = Path(path)
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    found = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) \
                and node.targets[0].id in names:
            found[node.targets[0].id] = ast.literal_eval(node.value)
    missing = set(names) - set(found)
    if missing:
        raise KeyError(f"{path.name}: no literal constant {sorted(missing)}")
    return found


def rel(path):
    """A repository-relative POSIX path, for the `file` fields."""
    return Path(path).resolve().relative_to(REPO).as_posix()

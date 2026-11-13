"""Architecture guard tests: the structure rules of CLAUDE.md, checked on the code. Pygame-free and fast.

The rules come from docs/architecture/review-2026-11-12.md (section 5). Four of them are checked by reading the
source with ``ast`` (nothing under hexa/ is imported):

    no pygame          state, rules, AI, data and map-building modules never import pygame, directly or through
                       another hexa module (a lazy import inside a function counts too)
    import direction   those modules never import a window module (app, mapview, render, landscape, ui, ...)
    no cross-module _private use, outside tests: ``from hexa.x import _y``, ``module._y`` and ``world._y`` from
                       another module. Today's offenders are in ALLOW_PRIVATE and may only be removed from it.
    size ratchet       a module over 800 lines and a function over 60 lines is in ALLOW with its current size and
                       may not grow past it (plus a 2 % tolerance). Anything else must stay under 1,200 lines per
                       module and 100 lines per function (150 in art and map-building modules).

The fifth check is world.version: scripted actions (found a colony and a trading post, invest, finish a castle and a
settlement, capture a province, attack a castle, make peace, a move that lifts the fog) each change what the cached map
layers draw, and each must bump ``world.version``; a few seasons of the random player of tests/support/agents.py are
an extra net. (Several helpers bump the version too, so a missing ``changed()`` in an action only shows when the
helper's bump is gone as well: the scripted tests call the season phases, not end_round, which calls changed() itself.)

ALLOW IS A RATCHET: ONLY EVER SHRINK IT.
- A number is the size an entry may not grow beyond. Modules and functions get 2 % of tolerance; a module that is over
  2,000 lines gets none (NO_TOLERANCE_ABOVE): the giants only shrink.
- When a refactor makes a module or function smaller, lower its number (or delete the entry once it is under the
  limit); the stale-entry tests fail until you do. ``python -m tests.test_architecture --report`` prints the current
  sizes and offenders, ready to paste into the dicts.
- When code MOVES, re-key it: a function moved to another module is deleted from ALLOW_FUNCTIONS under its old
  "module:qualname" key and added under the new one with the size it has now (it must not be bigger than before the
  move), in the same PR. The same for a module that is split: the parts are new modules that meet the limits.
- Never raise a number or add an entry to make this test pass: split the code instead.
- A module with no function and no class is a data table (place names) and is exempt from the module size limit.
"""
import ast
import math
import os
import random
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = "hexa"

# ----- the rules -----------------------------------------------------------------------------------------------
MODULE_LIMIT, MODULE_ALLOW_ABOVE = 1200, 800
FUNCTION_LIMIT, FUNCTION_ALLOW_ABOVE, FUNCTION_LIMIT_ART = 100, 60, 150
TOLERANCE = 1.02
NO_TOLERANCE_ABOVE = 2000

# Modules (and the packages below them) that draw or read input: the only ones that may import pygame, and the
# ones state modules must never import. Every other module of hexa/ is "state": pygame-free, no window imports.
WINDOW = {
    "hexa.menu", "hexa.render", "hexa.colony.app", "hexa.colony.render",
    "hexa.campaign.app", "hexa.campaign.mapview", "hexa.campaign.gamemenu", "hexa.campaign.techscreen",
    "hexa.campaign.display", "hexa.campaign.uistate",
    "hexa.campaign.art", "hexa.campaign.goodsart", "hexa.campaign.goodsobjects", "hexa.campaign.landscape",
    "hexa.campaign.landmarks", "hexa.campaign.life", "hexa.campaign.nature", "hexa.campaign.wfctiles",
}
WINDOW_PACKAGES = ("hexa.ui", "hexa.render", "hexa.campaign.panels", "hexa.campaign.screens", "hexa.campaign.render",
                   "hexa.campaign.ui", "hexa.campaign.hud")

# Modules that draw (art recipes) or build maps get the longer function limit.
LONG_FUNCTIONS = ("art", "goodsart", "goodsobjects", "landscape", "landmarks", "life", "nature", "wfctiles",
                  "wfc", "randomgeo", "mapgen", "geo")

# Where the world classes live: their own attributes are not "somebody else's _private".
WORLD_MODULES = {"hexa.world", "hexa.colony.world", "hexa.campaign.world"}

# ----- ALLOW: ONLY EVER SHRINK THESE -----------------------------------------------------------------------------
ALLOW_MODULES = {
    "hexa.campaign.world": 2556,
    "hexa.campaign.goodsart": 2476,
    "hexa.campaign.wfctiles": 2375,
    "hexa.campaign.landscape": 2010,
    "hexa.campaign.app": 917,
    "hexa.campaign.mapview": 1531,
    "hexa.campaign.randomgeo": 1286,
    "hexa.campaign.life": 1182,
    "hexa.campaign.goodsobjects": 1135,
    "hexa.colony.world": 1116,
}

ALLOW_FUNCTIONS = {
    "hexa.campaign.randomgeo:_attempt": 395,
    "hexa.campaign.wfctiles:_generate": 325,
    "hexa.campaign.screens.techdraw:_glyph": 137,
    "hexa.campaign.systems.worldgen:build_countries": 133,
    "hexa.campaign.randomgeo:_design": 134,
    "hexa.campaign.randomgeo:_mask": 130,
    "hexa.campaign.goodsart:_timber": 100,
    "hexa.campaign.landscape:Landscape._draw_ridge": 99,
    "hexa.campaign.landscape:Landscape._ridge_objects": 95,
    "hexa.campaign.goodsart:_coffee": 86,
    "hexa.campaign.wfctiles:socket_collapse": 86,
    "hexa.campaign.goodsart:_stone": 85,
    "hexa.campaign.world:CampaignWorld._battle": 85,
    "hexa.campaign.goodsart:_furs": 84,
    "hexa.campaign.screens.gamemenu:PauseMenu.draw": 80,
    "hexa.campaign.landscape:decorate": 82,
    "hexa.campaign.randomgeo:_mountains": 82,
    "hexa.campaign.goodsart:_horses": 81,
    "hexa.campaign.systems.worldgen:terrain_prior": 81,
    "hexa.campaign.goodsart:_fish": 80,
    "hexa.campaign.wfctiles:_settlement_objects": 80,
    "hexa.campaign.world:CampaignWorld.economy": 80,
    "hexa.campaign.app:CampaignApp.handle": 75,
    "hexa.campaign.art:_draw_figure": 78,
    "hexa.campaign.goodsart:_silk": 78,
    "hexa.campaign.goodsart:_gold": 75,
    "hexa.campaign.wfc:collapse": 74,
    "hexa.campaign.systems.worldgen:good_for": 74,
    "hexa.campaign.mapview:MapView._town_labels": 72,
    "hexa.campaign.goodsart:_wine": 70,
    "hexa.campaign.screens.techdraw:draw_idea_modal": 68,
    "hexa.colony.mapgen:generate": 69,
    "hexa.campaign.goodsart:_hemp": 68,
    "hexa.campaign.goodsart:_cocoa": 67,
    "hexa.campaign.screens.techdraw:_side_sections": 67,
    "hexa.campaign.mapview:MapView._draw_tiles": 66,
    "hexa.campaign.screens.techdraw:_node": 66,
    "hexa.campaign.goodsart:_silver": 65,
    "hexa.campaign.goodsart:_cattle": 65,
    "hexa.campaign.goodsart:_iron": 64,
    "hexa.campaign.wfctiles:_castle_objects": 64,
    "hexa.campaign.mapview:MapView.__init__": 62,
    "hexa.campaign.screens.techdraw:_grid": 61,
}

# (module, what it reaches into). Offenders of 2026-11-12; remove a line when the code stops doing it.
ALLOW_PRIVATE = {
    ("hexa.campaign.landscape", "hexa.campaign.goodsart._GOODS"),
    ("hexa.campaign.landscape", "hexa.campaign.life._obj"),
    ("hexa.campaign.landscape", "hexa.campaign.nature._get2x"),
    ("hexa.campaign.landscape", "hexa.campaign.wfctiles._coast_geo"),
    ("hexa.campaign.randomgeo", "world._ok"),
    ("hexa.colony.mapgen", "hexa.mapgen._noise"),
    ("hexa.colony.render", "hexa.render._hex_surface"),
    ("tools.perf", "world._RANDOM_GEOS"),
    ("tools.perf", "world._SNAPSHOTS"),
}


# ----- reading the source --------------------------------------------------------------------------------------
_CACHE = {}


def modules():
    """{dotted name: path} of every .py under hexa/."""
    found = {}
    for folder, dirs, files in os.walk(os.path.join(ROOT, PACKAGE)):
        dirs[:] = [d for d in dirs if d != "__pycache__"]
        for name in files:
            if name.endswith(".py"):
                path = os.path.join(folder, name)
                parts = os.path.relpath(path, ROOT)[:-3].replace(os.sep, "/").split("/")
                if parts[-1] == "__init__":
                    parts.pop()
                found[".".join(parts)] = path
    return found


def parsed(name):
    if name not in _CACHE:
        path = modules()[name]
        with open(path, encoding="utf-8") as f:
            text = f.read()
        _CACHE[name] = (ast.parse(text), text.count("\n") + (0 if text.endswith("\n") or not text else 1))
    return _CACHE[name]


def is_package(name):
    return os.path.basename(modules()[name]) == "__init__.py"


def imports(name):
    """[(imported dotted name, lazy?)] of every import in a module."""
    return read_imports(parsed(name)[0], name if is_package(name) else name.rpartition(".")[0], modules())


def read_imports(tree, package, known):
    """The imports of a parsed module in `package`: (dotted name, inside a function?)."""
    found = []

    def walk(node, lazy):
        for child in ast.iter_child_nodes(node):
            inner = lazy or isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            if isinstance(child, ast.Import):
                for alias in child.names:
                    found.append((alias.name, inner))
            elif isinstance(child, ast.ImportFrom):
                if child.level:
                    base = package.split(".")
                    base = base[:len(base) - (child.level - 1)]
                    target = ".".join(base + ([child.module] if child.module else []))
                else:
                    target = child.module or ""
                found.append((target, inner))
                for alias in child.names:           # "from hexa.campaign import saves" imports a module
                    if target + "." + alias.name in known:
                        found.append((target + "." + alias.name, inner))
            walk(child, inner)

    walk(tree, False)
    return found


def is_window(name):
    return name in WINDOW or any(name == p or name.startswith(p + ".") for p in WINDOW_PACKAGES)


def reach(name):
    """{module: import chain} of every module this one imports, directly or not: the chain is the list of hexa
    modules from `name` down to the module itself."""
    known, seen, todo = modules(), {}, [(name, [name])]
    while todo:
        current, chain = todo.pop(0)
        for target, _lazy in imports(current):
            if target.split(".")[0] != PACKAGE:
                seen.setdefault(target.split(".")[0], chain + [target.split(".")[0]])
                continue
            parts = target.split(".")
            while ".".join(parts) not in known:         # "from hexa.x import name" where name is not a module
                parts.pop()
            target = ".".join(parts)
            if target not in seen and target != name:
                seen[target] = chain + [target]
                todo.append((target, chain + [target]))
    return seen


def state_modules():
    return sorted(m for m in modules() if not is_window(m))


# ----- the checks, as functions that return the problems ---------------------------------------------------------
def pygame_problems():
    problems = []
    for name in state_modules():
        if "pygame" in reach(name):
            problems.append(f"{name} imports pygame: " + " -> ".join(reach(name)["pygame"]))
    return problems


def direction_problems():
    problems = []
    for name in state_modules():
        for other, chain in sorted(reach(name).items()):
            if other.startswith(PACKAGE) and is_window(other):
                problems.append(f"{name} imports the window module {other}: " + " -> ".join(chain))
    return problems


def private_uses():
    """{(module, what)} of every reach into another module's _private name, in hexa/, play.py and tools/."""
    known = modules()
    found = set()
    files = {n: p for n, p in known.items()}
    for folder in ("tools",):
        for fname in sorted(os.listdir(os.path.join(ROOT, folder))):
            if fname.endswith(".py") and fname != "__init__.py":
                files[f"{folder}.{fname[:-3]}"] = os.path.join(ROOT, folder, fname)
    files["play"] = os.path.join(ROOT, "play.py")
    for name, path in files.items():
        if name in known:
            tree = parsed(name)[0]
        else:
            with open(path, encoding="utf-8") as f:
                tree = ast.parse(f.read())
        aliases = {}                                    # local name -> hexa module it is
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names:
                    if a.name in known and a.asname:
                        aliases[a.asname] = a.name
            elif isinstance(node, ast.ImportFrom):
                package = name if name in known and is_package(name) else name.rpartition(".")[0]
                if node.level:
                    base = package.split(".")
                    source = ".".join(base[:len(base) - (node.level - 1)] + ([node.module] if node.module else []))
                else:
                    source = node.module or ""
                for a in node.names:
                    if f"{source}.{a.name}" in known:
                        aliases[a.asname or a.name] = f"{source}.{a.name}"
                    elif source in known and a.name.startswith("_") and not a.name.startswith("__") and source != name:
                        found.add((name, f"{source}.{a.name}"))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Attribute) or not node.attr.startswith("_") or node.attr.startswith("__"):
                continue
            base = node.value
            if isinstance(base, ast.Name) and base.id in aliases and aliases[base.id] != name:
                found.add((name, f"{aliases[base.id]}.{node.attr}"))
            elif name not in WORLD_MODULES:
                if (isinstance(base, ast.Name) and base.id in ("world", "w")) \
                        or (isinstance(base, ast.Attribute) and base.attr == "world"):
                    found.add((name, f"world.{node.attr}"))
    return found


def function_sizes():
    """{"module:qualname": lines} of every function over FUNCTION_ALLOW_ABOVE lines (the longest of equal names)."""
    sizes = {}
    for name in modules():
        tree = parsed(name)[0]

        def walk(node, prefix):
            for child in ast.iter_child_nodes(node):
                if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    qual = prefix + child.name
                    size = child.end_lineno - child.lineno + 1
                    if size > FUNCTION_ALLOW_ABOVE:
                        key = f"{name}:{qual}"
                        sizes[key] = max(size, sizes.get(key, 0))
                    walk(child, qual + ".<locals>.")
                elif isinstance(child, ast.ClassDef):
                    walk(child, prefix + child.name + ".")
                else:
                    walk(child, prefix)

        walk(tree, "")
    return sizes


def is_data_only(name):
    """A module with no function and no class is a table of data (place names, say): a long one is not code to split."""
    return not any(isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) for n in ast.walk(parsed(name)[0]))


def module_sizes():
    return {name: parsed(name)[1] for name in modules()
            if parsed(name)[1] > MODULE_ALLOW_ABOVE and not is_data_only(name)}


def allowed(limit):
    """The size an allowlisted entry may reach: its number, plus 2 % (nothing at all above 2,000 lines)."""
    return limit if limit > NO_TOLERANCE_ABOVE else math.ceil(limit * TOLERANCE)


def size_problems():
    problems = []
    for name, lines in sorted(module_sizes().items()):
        if name in ALLOW_MODULES:
            if lines > allowed(ALLOW_MODULES[name]):
                problems.append(f"{name} has {lines} lines; it may not grow past {allowed(ALLOW_MODULES[name])}: split it")
        elif lines > MODULE_LIMIT:
            problems.append(f"{name} has {lines} lines; the limit for a module is {MODULE_LIMIT}: split it")
    for key, lines in sorted(function_sizes().items()):
        module = key.split(":")[0]
        limit = FUNCTION_LIMIT_ART if module.rpartition(".")[2] in LONG_FUNCTIONS else FUNCTION_LIMIT
        if key in ALLOW_FUNCTIONS:
            if lines > allowed(ALLOW_FUNCTIONS[key]):
                problems.append(f"{key} has {lines} lines; it may not grow past {allowed(ALLOW_FUNCTIONS[key])}: split it")
        elif lines > limit:
            problems.append(f"{key} has {lines} lines; the limit for a function here is {limit}: split it")
    return problems


def private_problems():
    return [f"{module} reaches into {what}: add a public function, or (never for new code) see ALLOW_PRIVATE"
            for module, what in sorted(private_uses() - ALLOW_PRIVATE)]


# ----- the tests -------------------------------------------------------------------------------------------------
class ImportRulesTest(unittest.TestCase):
    def test_every_module_is_found(self):
        names = modules()
        for must in ("hexa.world", "hexa.campaign.world", "hexa.campaign.app", "hexa.colony.ai"):
            self.assertIn(must, names)
        self.assertTrue(is_window("hexa.campaign.app") and not is_window("hexa.campaign.world"))

    def test_state_modules_do_not_import_pygame(self):
        self.assertEqual(pygame_problems(), [])

    def test_state_modules_do_not_import_window_modules(self):
        self.assertEqual(direction_problems(), [])

    def test_the_screens_never_import_the_window(self):
        """The app-gamemenu cycle is gone: the pause menu, the tech screen and everything else under
        hexa.campaign.screens (and the old import paths) talk to the window through the ctx they are handed, never by
        importing hexa.campaign.app, directly or through another module."""
        screens = sorted(m for m in modules() if m.startswith("hexa.campaign.screens")) + [
            "hexa.campaign.gamemenu", "hexa.campaign.techscreen"]
        self.assertTrue(len(screens) >= 6, screens)
        for name in screens:
            with self.subTest(module=name):
                self.assertNotIn("hexa.campaign.app", reach(name), f"{name} imports the window: take it as ctx")

    def test_the_game_manager_stays_pygame_free_and_never_sees_a_screen(self):
        """The stack of screens belongs to the window (screens/__init__.py), not to campaign/game.py."""
        reached = reach("hexa.campaign.game")
        self.assertNotIn("pygame", reached)
        self.assertFalse([m for m in reached if m.startswith("hexa.campaign.screens")], sorted(reached))

    def test_the_import_reader_sees_lazy_and_relative_imports(self):
        """A lazy pygame import and a relative window import are found, so the two tests above would bite."""
        tree = ast.parse("import pygame\nfrom . import app\ndef f():\n    from hexa.campaign import mapview\n")
        found = dict(read_imports(tree, "hexa.campaign", modules()))
        self.assertEqual(found["pygame"], False)
        self.assertIn("hexa.campaign.app", found)
        self.assertEqual(found["hexa.campaign.mapview"], True)
        self.assertTrue(is_window("hexa.campaign.app") and is_window("hexa.ui.kit"))


class PrivateUseTest(unittest.TestCase):
    def test_no_new_cross_module_private_use(self):
        self.assertEqual(private_problems(), [])


    def test_allow_private_is_not_stale(self):
        """An entry for a reach into another module's _private that is gone should be deleted (the ratchet only shrinks)."""
        self.assertEqual(sorted(ALLOW_PRIVATE - private_uses()), [],
                         "delete these from ALLOW_PRIVATE: the code no longer does it")


class SizeTest(unittest.TestCase):
    def test_size_ratchet(self):
        self.assertEqual(size_problems(), [])

    def test_allow_lists_are_not_stale(self):
        """An entry for a module or function that is gone, or is now under the limit, should be deleted."""
        modules_now, functions_now = module_sizes(), function_sizes()
        stale = [m for m in ALLOW_MODULES if m not in modules_now] + [f for f in ALLOW_FUNCTIONS if f not in functions_now]
        self.assertEqual(stale, [], "delete these from ALLOW_*: the code got smaller or moved (the ratchet only shrinks)")


# ----- world.version -------------------------------------------------------------------------------------------------
def map_layers(world):
    """What the cached map layers and the minimap draw that a player action can change (units are drawn over them
    each frame): per province its name, owners, buildings, siege and garrison, and how much the player has explored."""
    explored = len(world.countries[world.player].explored) if world.player else 0
    return explored, tuple((p.pos, p.name, p.owner, p.controller, p.settlement, p.castle, p.works, p.trading_post,
                            p.colony, p.siege, p.garrison, tuple(sorted(p.buildings.items())))
                           for p in world.provinces.values())


class StatePickleTest(unittest.TestCase):
    """D5: every class defined in state.py pickles as hexa.campaign.world.<Name> (old saves and old builds depend on it)."""

    def test_every_state_class_pickles_as_a_world_class(self):
        import pickle
        import pickletools
        from hexa.campaign import state, world
        classes = [c for c in vars(state).values() if isinstance(c, type) and c.__module__ in (state.__name__, "hexa.campaign.world")
                   and getattr(c, "__qualname__", "") == c.__name__]
        names = {c.__name__ for c in classes}
        self.assertTrue({"Province", "Market", "Route", "Country", "Unit", "Garrison", "War"} <= names)
        for cls in classes:
            self.assertEqual(cls.__module__, "hexa.campaign.world", cls.__name__)
            strings = [arg for op, arg, _ in pickletools.genops(pickle.dumps(cls)) if isinstance(arg, str)]
            self.assertIn("hexa.campaign.world", strings, cls.__name__)
            self.assertIn(cls.__name__, strings)
            self.assertIs(getattr(world, cls.__name__), cls)


class ScriptedVersionTest(unittest.TestCase):
    """One scripted action per kind of map change: it must change the map layers (else the setup is wrong) and bump
    world.version. A planted ``pass`` in place of ``changed()`` in found, move_group, attack_group, peace, sieges,
    invest or the building queue fails the matching test."""
    A, B = "POR", "CAS"

    def setUp(self):
        from tests.support.worlds import fresh
        self.world = fresh(self.A)

    def bumps(self, action):
        """Run action(); the map must have changed and world.version with it. Returns what action returned."""
        world = self.world
        before, version = map_layers(world), world.version
        result = action()
        self.assertNotEqual(map_layers(world), before, "setup: the action changed nothing on the map")
        self.assertNotEqual(world.version, version, "the map changed but world.version did not (call changed())")
        return result

    def bumps_within(self, seasons, done, phase):
        """Run one phase of the season (world.grow, world.sieges) until done() or `seasons` pass; the version must
        have moved when done() holds. (end_round itself calls changed(), so it would hide a missing call.)"""
        world = self.world
        version = world.version
        for _ in range(seasons):
            if done():
                break
            phase()
        self.assertTrue(done(), f"setup: nothing happened within {seasons} seasons")
        self.assertNotEqual(world.version, version, "the map changed but world.version did not (call changed())")

    def colonist_at_free_coast(self, trading_post):
        from hexa.campaign.data import COLONIST
        world = self.world
        for pos, prov in sorted(world.provinces.items()):
            if prov.owner is None and prov.coastal and world.is_land(pos):
                unit = world._add_unit(COLONIST, self.A, pos, moves=1)
                if world.found_check(unit, trading_post)[0]:
                    return unit
                world.units.remove(unit)
        self.fail("no free coast to found on")

    def test_found_a_colony(self):
        unit = self.colonist_at_free_coast(False)
        self.bumps(lambda: self.world.found(unit, False))

    def test_found_a_trading_post(self):
        unit = self.colonist_at_free_coast(True)
        self.bumps(lambda: self.world.found(unit, True))

    def test_invest(self):
        world = self.world
        prov = next(p for p in world.provinces_of(self.A) if world.invest_check(self.A, p)[0])
        self.bumps(lambda: world.invest(self.A, prov))

    def test_a_castle_is_finished(self):
        world = self.world
        prov = next(p for p in world.provinces_of(self.A) if world.build_check(self.A, p, "castle")[0])
        world.countries[self.A].treasury += 5000
        self.assertTrue(world.build(self.A, prov, "castle"))
        self.bumps_within(12, lambda: prov.castle > 0, world.grow)

    def test_a_settlement_is_finished(self):
        world = self.world
        prov = next(p for p in world.provinces_of(self.A) if p.settlement < 3)
        prov.peasants += 200.0                              # enough people for the next size
        world.countries[self.A].treasury += 5000
        level = prov.settlement
        self.assertTrue(world.build(self.A, prov, "settlement"))
        self.bumps_within(12, lambda: prov.settlement > level, world.grow)

    def at_war_next_to_an_enemy_province(self):
        """(province of B, an army of A next to it), B's units there cleared, A and B at war."""
        from hexa.campaign.data import troop
        from hexa.hexgrid import neighbors
        world = self.world
        self.assertTrue(world.declare_war(self.A, self.B))
        for prov in sorted(world.provinces_of(self.B), key=lambda p: p.pos):
            home = next((n for n in sorted(neighbors(prov.pos))
                         if world.provinces.get(n) and world.provinces[n].owner == self.A), None)
            if home:
                for unit in world.units_at(prov.pos):
                    world.units.remove(unit)
                army = [world._add_unit(troop("infantry", 1), self.A, home, moves=3) for _ in range(4)]
                return prov, army
        self.fail("no province of the enemy next to ours")

    def test_a_move_that_captures_a_province(self):
        world = self.world
        prov, army = self.at_war_next_to_an_enemy_province()
        prov.castle = prov.garrison = 0
        self.assertTrue(world.move_group(army, prov.pos))
        self.bumps_within(10, lambda: prov.controller == self.A, world.sieges)

    def test_attack_a_castle(self):
        from hexa.campaign.data import GARRISON_HP
        world = self.world
        prov, army = self.at_war_next_to_an_enemy_province()
        prov.castle = 2
        prov.garrison = 2 * GARRISON_HP
        self.assertIn(prov.pos, world.attack_options_group(army))
        self.bumps(lambda: world.attack_group(army, prov.pos))

    def test_peace_hands_provinces_over(self):
        world = self.world
        prov, army = self.at_war_next_to_an_enemy_province()
        prov.castle = prov.garrison = 0
        self.assertTrue(world.move_group(army, prov.pos))
        self.bumps_within(10, lambda: prov.controller == self.A, world.sieges)
        self.bumps(lambda: world.peace(self.A, self.B, winner=self.A))
        self.assertEqual(prov.owner, self.A)

    def test_a_move_that_explores(self):
        """The player's own move can lift the fog; the fog is part of the cached layers."""
        world = self.world
        moved = 0
        for unit in list(world.units_of(self.A)):
            if unit.carrier is not None or unit.moves_left <= 0:
                continue
            group = [unit]
            far = sorted(world.reachable_group(group), key=lambda pos: -sum(abs(a - b) for a, b in zip(pos, unit.pos)))
            if not far:
                continue
            before, version = map_layers(world), world.version
            self.assertTrue(world.move_group(group, far[0]))
            if map_layers(world) != before:
                self.assertNotEqual(world.version, version, "the fog lifted but world.version did not change")
                moved += 1
        self.assertTrue(moved, "setup: none of the moves explored anything")


class RandomPlayerVersionTest(unittest.TestCase):
    """An extra net: a few seasons of the random player; whatever it changes on the map must bump the version."""
    SEEDS, SEASONS = (1, 3), 6

    def test_actions_that_change_the_map_bump_the_version(self):
        from hexa.campaign import geo
        from tests.support.agents import Judge, campaign_player
        from tests.support.worlds import fresh, play_seasons

        seen, missed = {}, []

        class Watching(Judge):
            def attempt(self, name, args, check, action):
                world = self.world
                before, version = map_layers(world), world.version
                result = super().attempt(name, args, check, action)
                if map_layers(world) != before:
                    seen[name] = seen.get(name, 0) + 1
                    if world.version == version:
                        missed.append(f"{name}({args})")
                return result

        for seed in self.SEEDS:
            rng = random.Random(seed)
            tag = rng.choice(sorted(geo.COUNTRIES))
            world = fresh(tag)
            player = campaign_player(rng, Watching(world), tag)
            for _ in range(self.SEASONS):
                player(world)
                play_seasons(world, 1, player_ai=False)
        self.assertTrue(seen, "the random player changed nothing on the map: this test would pass for nothing")
        self.assertEqual(missed, [], "these actions changed the map but not world.version (call changed())")


def report():
    """Print the sizes, ready to paste into the ALLOW dicts."""
    print("ALLOW_MODULES = {")
    for name, lines in sorted(module_sizes().items(), key=lambda kv: -kv[1]):
        print(f'    "{name}": {lines},')
    print("}\n\nALLOW_FUNCTIONS = {")
    for key, lines in sorted(function_sizes().items(), key=lambda kv: -kv[1]):
        print(f'    "{key}": {lines},')
    print("}\n\nALLOW_PRIVATE = {")
    for module, what in sorted(private_uses()):
        print(f'    ("{module}", "{what}"),')
    print("}")


if __name__ == "__main__":
    import sys
    if "--report" in sys.argv:
        report()
    else:
        unittest.main()

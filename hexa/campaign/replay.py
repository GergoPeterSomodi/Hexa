"""The movement replay: the walks the player can see, played hex by hex at a readable pace. Pygame-free.

The game state never waits for it. ``world.move_group`` moves a stack at once and emits ``unit_moved`` with the whole
path and, per hex, whether the player could see it (``seen``). The window records those events here and, while the
replay runs, draws the moving figures where the replay says they are instead of where the world has put them. So the
replay is a pure picture: it reads events and a clock, never the world, and nothing it does is saved.

    what is played   a step (hex to hex) is played when the player saw either end of it. A step nobody saw is instant,
                     and a walk with no seen step is not recorded at all (the figure was in fog the whole way).
    the order        countries one after the other in turn order (the order their first walk was recorded, which is
                     the order the AIs played), the stacks of one country at the same time. A stack that walks twice
                     in a season (two events with one of its units) walks them one after the other.
    the pace         ``PACE``: ms per hex and the longest a whole replay may take. When the countries one after
                     the other would take longer, neighbours in turn order play together (2 at a time, 3, ... all),
                     and if even that is too long the pace goes up, never below ``MIN_STEP`` ms a hex.
    the clock        ``advance(dt)`` from the window loop. ``skip()`` ends it at once.
    ribbons          ``ready_at(pos)`` says when the replay has got to a hex: the floating text of a battle or a
                     capture waits for it (campaign/hud/__init__.py).

``poses()`` is what the map draws: for each walking stack a `Pose`: the hex it stands on (or leaves), the hex it walks
to, how far (0 to 1) and whether it is to be drawn while it waits for its turn (it is not if the player cannot see
where it starts).
"""
from typing import NamedTuple

from ..hexgrid import neighbors

PACE = {"normal": (180, 6000), "slow": (320, 9000)}      # speed -> (ms per hex, ms the whole replay may take)
MIN_STEP = 40                                            # ms per hex at the least, however much there is to see
MAX_FRAME = 50                                           # a slow frame (a season was just played) moves the clock this much


class Pose(NamedTuple):
    ids: tuple          # the unit ids of the stack this pose draws
    a: tuple            # the hex it stands on, or is leaving
    b: tuple            # the hex it is walking to (a when it waits)
    f: float            # how far from a to b, 0 to 1
    shown: bool         # False: the stack waits in a hex the player cannot see, so it is not drawn yet


class Leg:
    """One recorded walk. Scheduled by the replay: ``start`` and ``step`` (ms) say when and how fast."""

    def __init__(self, tag, ids, path, seen):
        self.tag, self.ids, self.path, self.seen = tag, tuple(ids), tuple(path), tuple(seen)
        self.vis = tuple(seen[i] or seen[i + 1] for i in range(len(path) - 1))
        self.start, self.step = 0.0, 0.0

    @property
    def count(self):
        """How many steps are played (the ones the player saw)."""
        return sum(self.vis)

    @property
    def end(self):
        return self.start + self.count * self.step

    def pose(self, t):
        """The `Pose` at replay time t, or None before nothing is left to play (the walk is over)."""
        local = t - self.start
        if local < 0:
            return Pose(self.ids, self.path[0], self.path[0], 0.0, self.seen[0])
        for i, played in enumerate(self.vis):
            if not played:
                continue                    # a step in fog is jumped
            if local < self.step:
                return Pose(self.ids, self.path[i], self.path[i + 1], local / self.step, True)
            local -= self.step
        return None


def _span(legs, step):
    """({leg: offset in ms}, total ms) of legs played together at `step` ms a hex. Walks that share a unit wait."""
    free, offsets, total = {}, {}, 0.0
    for leg in legs:
        begin = max([free.get(uid, 0.0) for uid in leg.ids] + [0.0])
        offsets[leg] = begin
        for uid in leg.ids:
            free[uid] = begin + leg.count * step
        total = max(total, begin + leg.count * step)
    return offsets, total


class Replay:
    def __init__(self):
        self.t = 0.0                # ms into the replay
        self.legs = []              # scheduled walks (in the order they were recorded)
        self.pending = []           # recorded, not scheduled yet
        self.speed = "normal"

    # ----- recording ------------------------------------------------------------------------------------
    def record(self, event, speed="normal"):
        """Take a ``unit_moved`` event. Walks the player did not see at all are dropped; speed "off" drops all."""
        if speed not in PACE:
            return
        path, seen = event.get("path"), event.get("seen")
        if not path or len(path) < 2 or not seen:
            return
        leg = Leg(event.tag, event.get("ids", ()), path, seen)
        if leg.count:
            self.pending.append(leg)
            self.speed = speed

    @property
    def active(self):
        """Whether a replay is running or waiting to start (End season is blocked until it is over)."""
        return bool(self.legs or self.pending)

    def skip(self):
        """End the replay now: every figure goes to where the world has it."""
        self.legs, self.pending, self.t = [], [], 0.0

    # ----- the clock ------------------------------------------------------------------------------------
    def advance(self, dt):
        """Move the clock on by dt ms (at most MAX_FRAME at a time); a replay that has run out ends."""
        self.schedule()
        if not self.legs:
            return
        self.t += min(max(dt, 0), MAX_FRAME)
        if self.t >= max(leg.end for leg in self.legs):
            self.skip()

    def schedule(self):
        """Give the walks recorded since the last call their place in time, starting now."""
        legs, self.pending = self.pending, []
        if not legs:
            return
        step, cap = PACE[self.speed]
        phases = {}
        for leg in legs:
            phases.setdefault(leg.tag, []).append(leg)
        phases = list(phases.values())
        together, step = self._plan(phases, step, cap)
        begin = self.t
        for i in range(0, len(phases), together):
            group = [leg for phase in phases[i:i + together] for leg in phase]
            offsets, total = _span(group, step)
            for leg in group:
                leg.start, leg.step = begin + offsets[leg], step
            begin += total
        self.legs.extend(legs)

    @staticmethod
    def _plan(phases, step, cap):
        """(countries played together, ms a hex): the least parallel play that fits `cap`, else the pace goes up."""
        total = 0.0
        for together in range(1, len(phases) + 1):
            total = sum(_span([leg for phase in phases[i:i + together] for leg in phase], step)[1]
                        for i in range(0, len(phases), together))
            if total <= cap:
                return together, step
        return len(phases), max(MIN_STEP, step * cap / total) if total else step

    # ----- what the map draws ---------------------------------------------------------------------------
    def poses(self):
        """[Pose] of the stacks still walking or waiting for their turn. Each unit is in one pose only."""
        self.schedule()
        claimed, out = set(), []
        for leg in self.legs:
            pose = leg.pose(self.t)
            if pose is None:
                continue
            ids = tuple(uid for uid in pose.ids if uid not in claimed)
            if ids:
                claimed.update(ids)
                out.append(pose._replace(ids=ids))
        return out

    def ready_at(self, pos):
        """The replay time (ms) at which a walk has got to `pos` or next to it: when the ribbons of a battle or a
        capture there may float. 0 when no walk ends there (nothing to wait for)."""
        self.schedule()
        near = {pos, *neighbors(pos)}
        ends = [leg.end for leg in self.legs if leg.path[-1] in near]
        return min(ends) if ends else 0.0

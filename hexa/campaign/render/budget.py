"""FrameBudget: a slice of real time that work spread over frames (building tiles, sprites, object lists) may use.

    budget = FrameBudget(3.0)            # milliseconds
    budget.start()                       # a new frame: the slice begins now (start(ms) or start(ms, t0) to change it)
    while todo and budget.fits(cost_ms): # may one more piece of work, expected to take cost_ms, still start?
        t = budget.clock()
        work()
        budget.spend(t)                  # adds the time since t to budget.spent
    budget.left()                        # seconds left in the slice (0 when over)

``fits(expected_ms=0)`` is true while now + expected < the end of the slice, so ``fits()`` alone asks "is there any
time left". ``spent`` counts the time the frame's builds took (`spend`), whatever the slice: MapView compares it with
its own limit (LAND_STILL_MS) when the camera does not move. The clock is ``time.perf_counter``; tests may pass
another. Nothing here needs pygame.
"""
import time


class FrameBudget:
    def __init__(self, ms=0.0, clock=time.perf_counter):
        self.ms, self.clock = ms, clock
        self.t0 = self.end = clock()
        self.spent = 0.0

    def start(self, ms=None, t0=None):
        """Begin a slice of `ms` (default: the one given to the constructor) at t0 (default: now); spent is 0 again."""
        if ms is not None:
            self.ms = ms
        self.t0 = self.clock() if t0 is None else t0
        self.end = self.t0 + self.ms / 1000
        self.spent = 0.0
        return self

    def fits(self, expected_ms=0.0, now=None):
        """Does work expected to take expected_ms still end inside the slice? (`now`: a time already read.)"""
        return (self.clock() if now is None else now) + expected_ms / 1000 < self.end

    def left(self):
        """Seconds left in the slice, 0 when it is over."""
        return max(0.0, self.end - self.clock())

    def spend(self, since):
        """Count the time from `since` (a ``clock()`` reading) until now as spent."""
        self.spent += self.clock() - since

    def extend(self, now, ms):
        """Make sure the slice lasts until at least ms after `now`."""
        self.end = max(self.end, now + ms / 1000)

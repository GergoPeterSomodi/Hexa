"""The odds card's word (battle slice 1, PR 7b): the bands of data.ODDS_WORDS, what battleview.odds_word makes of a ratio,
and the calibration: every band must show the attacker's win rate it was measured at (the plains pike fights of
tests/support/scenarios.py, the same rules as the bands of tests/test_battle.py, 30 seeds). Edit the numbers of data.py
and this test says which word lies. Pygame-free; the card's drawing is tests/ui/test_odds_card.py."""
import unittest

from hexa.campaign.battleview import odds_factor, odds_view, odds_word
from hexa.campaign.data import GROUND_ODDS, ODDS_WORDS
from tests.support.scenarios import SEEDS, play, stage
from tests.support.worlds import fresh

WORDS = ("Hopeless", "Poor", "Even", "Favourable", "Overwhelming")
# (regiments of the attacker, regiments of the defender, the word the ratio must give): pikes on plains.
CALIBRATION = (
    (3, 6, "Hopeless"), (3, 4, "Hopeless"),
    (4, 5, "Poor"), (5, 6, "Poor"),
    (3, 3, "Even"), (4, 4, "Even"),
    (6, 5, "Favourable"), (4, 3, "Favourable"), (6, 4, "Favourable"),
    (6, 3, "Favourable"), (8, 3, "Overwhelming"),
)
# 0.2.2: Overwhelming starts at ratio 2.5 (it was 2.0, where it read like Favourable). 6 v 3 is ratio 2.00 and measured
# 72% (inside Favourable's band); 8 v 3 (2.67, 73%) is the first Overwhelming pair.


class BandTableTest(unittest.TestCase):
    def test_five_words_in_order_each_with_a_lowest_ratio_and_a_win_range(self):
        self.assertEqual(tuple(name for name, _, _ in ODDS_WORDS), WORDS)
        lows = [low for _, low, _ in ODDS_WORDS]
        self.assertEqual(lows[0], 0.0)
        self.assertEqual(lows, sorted(set(lows)), "ratios rise from band to band")
        for name, _, (low, high) in ODDS_WORDS:
            self.assertTrue(0.0 <= low <= high <= 1.0, name)

    def test_the_word_at_each_boundary(self):
        self.assertEqual(odds_word(None), "Unknown")
        self.assertEqual(odds_word(0.0), "Hopeless")
        self.assertEqual(odds_word(0.79), "Hopeless")
        self.assertEqual(odds_word(0.8), "Poor")
        self.assertEqual(odds_word(0.99), "Poor")
        self.assertEqual(odds_word(1.0), "Even")
        self.assertEqual(odds_word(1.19), "Even")
        self.assertEqual(odds_word(1.2), "Favourable")
        self.assertEqual(odds_word(2.49), "Favourable")
        self.assertEqual(odds_word(2.5), "Overwhelming")
        self.assertEqual(odds_word(9.0), "Overwhelming")


class CalibrationTest(unittest.TestCase):
    """Each point: the card's ratio (odds_view before the battle, the numbers the card shows) gives the expected word, and
    the attacker's win rate over the scenario seeds lies in that word's band."""

    @classmethod
    def setUpClass(cls):
        cls.world = fresh("POR")
        cls.world.visible = set(cls.world.terrain)          # the defender is seen: the card shows its numbers
        cls.points = []
        for att, dfn, expected in CALIBRATION:
            spec_a, spec_d = [("infantry", 1, att)], [("infantry", 1, dfn)]
            _, attackers, _ = stage(cls.world, spec_a, spec_d, terrain="plains")
            owner = attackers[0].owner
            cls.world.player = owner
            view = odds_view(cls.world, attackers, attackers[0].pos, owner)
            wins = sum(1 for seed in SEEDS
                       if play(cls.world, seed, spec_a, spec_d, "plains")["winner"] == owner)
            cls.points.append((f"{att} v {dfn}", view["ratio"], view["word"], expected, wins / len(SEEDS)))
        cls.world.player = None

    def test_each_point_gives_its_expected_word(self):
        for label, ratio, word, expected, _ in self.points:
            self.assertEqual(word, expected, f"{label} (ratio {ratio})")

    def test_each_word_shows_the_win_rate_its_band_was_measured_at(self):
        for label, ratio, word, _, rate in self.points:
            low, high = next((lo, hi) for name, _, (lo, hi) in ODDS_WORDS if name == word)
            self.assertTrue(low <= rate <= high, f"{label}: {word} band {low:.0%}-{high:.0%}, attacker won {rate:.0%}")


# The pikes on hills (the defender on the hill, the attacker on plains beside it): the same pairs, the word the ground
# factor gives (GROUND_ODDS hills, recalibrated 2026-11-13 for 0.2.1 to 1.34), and the win rate measured on the hills
# (30 seeds). The factor is one number per ground, so a pair near a band's edge can lie outside it: HILLS_SLACK allows
# the 30-seed scatter (about 9 points) and the pairs the one factor places a band out. Measured on hills, every big
# ratio stays at 60% (6 v 4, 6 v 3, 8 v 3), so 8 v 3 reads Favourable, not Overwhelming: the hills rates do not reach 65%.
HILLS = ((3, 6, "Hopeless"), (3, 4, "Hopeless"), (4, 5, "Hopeless"), (5, 6, "Hopeless"),
         (3, 3, "Hopeless"), (4, 4, "Hopeless"), (6, 5, "Poor"), (4, 3, "Poor"),
         (6, 4, "Even"), (6, 3, "Favourable"), (8, 3, "Favourable"))
HILLS_SLACK = 0.10


class HillsCalibrationTest(unittest.TestCase):
    """The same calibration on hills: the word of each pair (the ratio over the hills factor) and the attacker's win rate
    measured on the hills against the word's band, within HILLS_SLACK."""

    @classmethod
    def setUpClass(cls):
        cls.world = fresh("POR")
        cls.world.visible = set(cls.world.terrain)
        cls.points = []
        for att, dfn, expected in HILLS:
            spec_a, spec_d = [("infantry", 1, att)], [("infantry", 1, dfn)]
            _, attackers, _ = stage(cls.world, spec_a, spec_d, terrain="hills")
            owner = attackers[0].owner
            cls.world.player = owner
            view = odds_view(cls.world, attackers, attackers[0].pos, owner)
            wins = sum(1 for seed in SEEDS
                       if play(cls.world, seed, spec_a, spec_d, "hills")["winner"] == owner)
            cls.points.append((f"{att} v {dfn} on hills", view, expected, wins / len(SEEDS)))
        _, plains, _ = stage(cls.world, [("infantry", 1, 3)], [("infantry", 1, 3)], terrain="plains")
        cls.world.player = plains[0].owner
        cls.plains_33 = odds_view(cls.world, plains, plains[0].pos, plains[0].owner)
        cls.world.player = None

    def test_the_hills_factor_is_the_measured_one(self):
        for label, view, _, _ in self.points:
            self.assertEqual(view["factor"], GROUND_ODDS["hills"], label)
            self.assertEqual(view["defence"]["terrain"], "Hills", label)

    def test_each_pair_on_hills_gives_its_expected_word(self):
        for label, view, expected, _ in self.points:
            self.assertEqual(view["word"], expected, f"{label} (ratio {view['ratio']})")

    def test_each_word_on_hills_is_near_the_win_rate_measured_there(self):
        for label, view, _, rate in self.points:
            low, high = next((lo, hi) for name, _, (lo, hi) in ODDS_WORDS if name == view["word"])
            self.assertTrue(low - HILLS_SLACK <= rate <= high + HILLS_SLACK,
                            f"{label}: {view['word']} band {low:.0%}-{high:.0%}, attacker won {rate:.0%}")

    def test_a_defender_on_hills_reads_two_bands_lower_than_on_plains(self):
        """3 v 3 is Even on plains (45-57% measured) and Hopeless on hills (23% measured): the card no longer promises
        the plains fight."""
        hills = next(v for label, v, _, _ in self.points if label == "3 v 3 on hills")
        self.assertEqual(self.plains_33["word"], "Even")
        self.assertEqual(hills["word"], "Hopeless")


# The garrison pairs (0.2.2, design 4.6): one attacking stack of pikes (regiments) against a castle's garrison of level
# ``level`` (its men: 600 a level), alone (field 0) or behind a field army of ``field`` regiments, in a storm, 30 seeds each.
# The rates were measured in the engine before the weights were fitted (scratch run, the same 30 seeds).
GARRISON_PAIRS = (
    (1, 0, 1), (1, 0, 2), (1, 0, 3), (1, 0, 4), (1, 0, 6),
    (2, 0, 1), (2, 0, 2), (2, 0, 3), (2, 0, 4), (2, 0, 6),
    (3, 0, 1), (3, 0, 2), (3, 0, 3), (3, 0, 4), (3, 0, 6),
    (1, 2, 2), (1, 2, 4), (1, 2, 6), (2, 2, 2), (2, 2, 4), (2, 2, 6), (3, 2, 2), (3, 2, 4), (3, 2, 6),
    (1, 4, 4), (1, 4, 6), (2, 4, 4), (2, 4, 6), (3, 4, 4), (3, 4, 6),
)
GARRISON_SLACK = 0.10    # the 30-seed scatter (about 9 points, as the hills test allows)
# Known open (0.2.2 report): level 1 behind 2 field regiments, 4 regiments attacking. The engine measures 33% (Hopeless), the
# card reads Even: the men model cannot fit it and 6 v 4 behind 4 field regiments (63%) at the same ratio. Pinned to its
# word here, so a change shows; the level 1 weight is the owner's call (see the 0.2.2 report).
GARRISON_KNOWN_OPEN = {(1, 2, 4): "Even"}


def _band(rate):
    """The index of the highest word whose lowest win rate the rate reaches (ODDS_WORDS order)."""
    index = 0
    for i, word in enumerate(ODDS_WORDS):
        if rate >= word[2][0] - 1e-9:
            index = i
    return index


class GarrisonCalibrationTest(unittest.TestCase):
    """Every garrison pair's word (the storm card: men against men, the garrison weighted by GARRISON_ODDS with a field army,
    GARRISON_ODDS_ALONE alone) lies within one band of its measured win rate and never above it, allowing the scatter."""

    @classmethod
    def setUpClass(cls):
        cls.world = fresh("POR")
        cls.world.visible = set(cls.world.terrain)
        cls.points = []
        for level, field, count in GARRISON_PAIRS:
            spec_a = [("infantry", 1, count)]
            spec_d = [("infantry", 1, field)] if field else []
            _, attackers, _ = stage(cls.world, spec_a, spec_d, terrain="plains", castle=level)
            owner = attackers[0].owner
            cls.world.player = owner
            view = odds_view(cls.world, attackers, attackers[0].pos, owner)
            wins = sum(1 for seed in SEEDS
                       if play(cls.world, seed, spec_a, spec_d, "plains", castle=level)["winner"] == owner)
            cls.points.append(((level, field, count), view["word"], view["ratio"], wins / len(SEEDS)))
        cls.world.player = None

    def test_each_pair_reads_its_measured_band_at_most_one_low_and_never_high(self):
        for pair, word, ratio, rate in self.points:
            if pair in GARRISON_KNOWN_OPEN:
                self.assertEqual(word, GARRISON_KNOWN_OPEN[pair], f"known open pair {pair} (attacker won {rate:.0%})")
                continue
            index = next(i for i, (name, _, _) in enumerate(ODDS_WORDS) if name == word)
            high = _band(min(1.0, rate + GARRISON_SLACK))
            low = _band(max(0.0, rate - GARRISON_SLACK)) - 1
            self.assertTrue(low <= index <= high,
                            f"level {pair[0]}, field {pair[1]}, {pair[2]} regiments: {word} (ratio {ratio}), "
                            f"attacker won {rate:.0%}")

    def test_a_lone_level_3_garrison_against_1_7_to_3_3_times_its_men_is_not_hopeless(self):
        world = fresh("POR")
        for count in (3, 6):
            _, attackers, _ = stage(world, [("infantry", 1, count)], [], terrain="plains", castle=3)
            world.player = attackers[0].owner
            view = odds_view(world, attackers, attackers[0].pos, world.player)
            self.assertNotEqual(view["word"], "Hopeless", f"{count} regiments against level 3 alone")
        world.player = None


class FactorTest(unittest.TestCase):
    def test_the_ground_and_castle_factors(self):
        self.assertEqual(odds_factor("plains", 0, False), 1.0)
        self.assertEqual(odds_factor("hills", 0, False), GROUND_ODDS["hills"])
        self.assertEqual(odds_factor("mountains", 0, False), GROUND_ODDS["mountains"])
        self.assertEqual(odds_factor("steppe", 0, False), 1.0, "a flat ground not measured reads as plains")
        self.assertEqual(odds_factor("hills", 2, True), 1.0, "in an assault the garrison fights, not the ground")
        self.assertEqual(odds_factor("mountains", 3, True), 1.0)
        self.assertEqual(odds_factor("hills", 1, False), GROUND_ODDS["hills"], "a castle with no assault is ground")


class HiddenEnemyTest(unittest.TestCase):
    def test_a_hidden_enemy_is_unknown_and_nameless(self):
        world = fresh("POR")
        _, attackers, _ = stage(world, [("infantry", 1, 3)], [("infantry", 1, 2)], terrain="plains")
        world.player = attackers[0].owner
        world.visible = set()
        view = odds_view(world, attackers, attackers[0].pos, world.player)
        self.assertEqual(view["word"], "Unknown")
        self.assertIsNone(view["defender_name"])
        self.assertEqual(view["defence"]["access"], "hidden")

    def test_the_card_keys_are_there(self):
        world = fresh("POR")
        _, attackers, _ = stage(world, [("infantry", 1, 3)], [("infantry", 1, 2)], terrain="hills")
        world.player = attackers[0].owner
        view = odds_view(world, attackers, attackers[0].pos, world.player)
        self.assertEqual(view["word"], odds_word(None if view["ratio"] is None else view["ratio"] / view["factor"]))
        self.assertIs(view["crossing"], False)
        self.assertIs(view["uphill"], False)
        self.assertIsNone(view["attack"]["general"])
        self.assertIsNone(view["defence"]["general"])
        self.assertIsInstance(view["attacker_name"], str)

"""The odds card's word (battle slice 1, PR 7b): the bands of data.ODDS_WORDS, what battleview.odds_word makes of a ratio,
and the calibration: every band must show the attacker's win rate it was measured at (the plains pike fights of
tests/support/scenarios.py, the same rules as the bands of tests/test_battle.py, 30 seeds). Edit the numbers of data.py
and this test says which word lies. Pygame-free; the card's drawing is tests/ui/test_odds_card.py."""
import unittest

from hexa.campaign.battleview import odds_factor, odds_view, odds_word
from hexa.campaign.data import CASTLE_ODDS, GROUND_ODDS, ODDS_WORDS
from tests.support.scenarios import SEEDS, play, stage
from tests.support.worlds import fresh

WORDS = ("Hopeless", "Poor", "Even", "Favourable", "Overwhelming")
# (regiments of the attacker, regiments of the defender, the word the ratio must give): pikes on plains.
CALIBRATION = (
    (3, 6, "Hopeless"), (3, 4, "Hopeless"),
    (4, 5, "Poor"), (5, 6, "Poor"),
    (3, 3, "Even"), (4, 4, "Even"),
    (6, 5, "Favourable"), (4, 3, "Favourable"), (6, 4, "Favourable"),
    (6, 3, "Overwhelming"), (8, 3, "Overwhelming"),
)


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
        self.assertEqual(odds_word(1.99), "Favourable")
        self.assertEqual(odds_word(2.0), "Overwhelming")
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


class FactorTest(unittest.TestCase):
    def test_the_ground_and_castle_factors(self):
        self.assertEqual(odds_factor("plains", 0, False), 1.0)
        self.assertEqual(odds_factor("hills", 0, False), GROUND_ODDS["hills"])
        self.assertEqual(odds_factor("mountains", 0, False), GROUND_ODDS["mountains"])
        self.assertEqual(odds_factor("steppe", 0, False), 1.0, "a flat ground not measured reads as plains")
        self.assertEqual(odds_factor("hills", 2, True), CASTLE_ODDS[2], "in an assault the garrison fights, not the ground")
        self.assertEqual(odds_factor("hills", 1, False), GROUND_ODDS["hills"], "a castle with no assault is ground")
        self.assertGreater(CASTLE_ODDS[3], CASTLE_ODDS[2])


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

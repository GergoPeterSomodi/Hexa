"""The battle panel's geometry (hexa/campaign/screens/battlelayout.py, battle slice 1, PR 7): pure maths, no pygame. The
panel fits 1280x720 and 1920x1080 with the regiments a full battle can put on the hex; every card lies in the field,
no two cards overlap, the side column stays inside the panel, and the log keeps the newest lines."""
import unittest

from hexa.campaign.screens import battlelayout as lay

SIZES = ((1280, 720), (1920, 1080))
MAX_REGIMENTS = 9           # most regiments a back grid holds: a stack of 12 war units less its three lanes


def inside(inner, outer):
    ix, iy, iw, ih = inner
    ox, oy, ow, oh = outer
    return ix >= ox and iy >= oy and ix + iw <= ox + ow and iy + ih <= oy + oh


def overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


class PanelTest(unittest.TestCase):
    def test_the_panel_is_centred_and_inside_the_window(self):
        for width, height in SIZES:
            with self.subTest(size=(width, height)):
                frame = lay.panel(width, height)
                self.assertTrue(inside(frame, (0, 0, width, height)))
                x, y, w, h = frame
                self.assertAlmostEqual(x * 2 + w, width, delta=1)
                self.assertAlmostEqual(y * 2 + h, height, delta=1)

    def test_header_morale_and_body_stack_down_the_panel(self):
        for width, height in SIZES:
            frame = lay.panel(width, height)
            head, morale, body = lay.header(frame), lay.morale(frame), lay.body(frame)
            self.assertEqual(head[1], frame[1])
            self.assertEqual(morale[1], head[1] + head[3])
            self.assertEqual(body[1], morale[1] + morale[3])
            self.assertTrue(inside(body, frame))
            self.assertTrue(inside(lay.close_button(frame), head))


class FieldTest(unittest.TestCase):
    def check(self, frame, top, bottom):
        slots = lay.field_slots(frame, top, bottom)
        field = lay.field_rect(frame)
        cards = slots["top"] + slots["enemy"] + slots["ours"] + slots["bottom"]
        for card in cards:
            self.assertTrue(inside(card, field), f"{card} is outside the field {field}")
        for index, a in enumerate(cards):
            for b in cards[index + 1:]:
                self.assertFalse(overlap(a, b), f"{a} overlaps {b}")
        return slots, field

    def test_a_full_battle_fits_both_sizes(self):
        for width, height in SIZES:
            for top in range(MAX_REGIMENTS + 1):
                for bottom in (0, 3, MAX_REGIMENTS):
                    with self.subTest(size=(width, height), top=top, bottom=bottom):
                        slots, field = self.check(lay.panel(width, height), top, bottom)
                        self.assertEqual(len(slots["top"]), top)
                        self.assertEqual(len(slots["bottom"]), bottom)
                        self.assertEqual(len(slots["enemy"]), 3)
                        self.assertEqual(len(slots["ours"]), 3)

    def test_the_front_sits_between_the_two_lanes(self):
        slots, _ = self.check(lay.panel(1280, 720), 3, 3)
        enemy_bottom = slots["enemy"][0][1] + slots["enemy"][0][3]
        ours_top = slots["ours"][0][1]
        self.assertLess(enemy_bottom, slots["front"])
        self.assertLess(slots["front"], ours_top)

    def test_the_enemy_is_on_top_and_our_back_line_at_the_bottom(self):
        slots, _ = self.check(lay.panel(1280, 720), 3, 3)
        self.assertLess(slots["top"][0][1], slots["enemy"][0][1])
        self.assertGreater(slots["bottom"][0][1], slots["ours"][0][1])

    def test_cards_shrink_only_as_much_as_needed(self):
        frame = lay.panel(1280, 720)
        few = lay.card_size(lay.field_rect(frame), 0, 0)[1]
        many = lay.card_size(lay.field_rect(frame), MAX_REGIMENTS, MAX_REGIMENTS)[1]
        self.assertLessEqual(many, few)
        self.assertGreaterEqual(many, 40)
        self.assertLessEqual(lay.card_size(lay.field_rect(lay.panel(1920, 1080)), 0, 0)[1], lay.CARD_H_MAX)


class SideColumnTest(unittest.TestCase):
    def test_the_side_column_is_inside_the_panel_and_clear_of_the_field(self):
        for width, height in SIZES:
            frame = lay.panel(width, height)
            side, field = lay.side_rect(frame), lay.field_rect(frame)
            self.assertTrue(inside(side, frame))
            self.assertLess(field[0] + field[2], side[0])


class HelperTest(unittest.TestCase):
    def test_split_makes_a_row_of_equal_buttons(self):
        row = lay.split(10, 20, 300, 3, 30, gap=10)
        self.assertEqual(len(row), 3)
        self.assertEqual({r[2] for r in row}, {93})         # (300 - 2 gaps of 10) / 3
        self.assertEqual([r[0] for r in row], [10, 113, 216])
        self.assertEqual({r[1] for r in row}, {20})
        self.assertEqual(lay.split(0, 0, 100, 0, 10), [])

    def test_last_lines_keeps_the_newest_whole_entries(self):
        blocks = [["a1", "a2"], ["b1"], ["c1", "c2", "c3"]]
        self.assertEqual(lay.last_lines(blocks, 10), ["a1", "a2", "b1", "c1", "c2", "c3"])
        self.assertEqual(lay.last_lines(blocks, 4), ["b1", "c1", "c2", "c3"])
        self.assertEqual(lay.last_lines(blocks, 2), ["c2", "c3"])
        self.assertEqual(lay.last_lines([], 5), [])
        self.assertEqual(lay.last_lines(blocks, 0), [])


if __name__ == "__main__":
    unittest.main()

"""The AI's technology choices: research, funding and idea cards. Run with:  python -m unittest discover -s tests -t ."""
import unittest

from hexa.campaign import ai, tech
from hexa.campaign.world import CampaignWorld


def fresh_with_techs(tag, techs):
    """A new world where `tag` knows exactly `techs` (plus nothing else), with nothing being researched."""
    w = CampaignWorld()
    country = w.countries[tag]
    country.techs = set(techs)
    country.researching = ""
    country.queue = []
    w._tech_changed(tag)
    return w


class TechAITest(unittest.TestCase):
    def test_empty_research_gets_an_available_tech(self):
        w = CampaignWorld()
        tag = "POR"
        country = w.countries[tag]
        country.researching = ""
        country.queue = []
        ai.run(w, tag)
        self.assertIn(country.researching, tech.available(country.techs, country.era))
        self.assertNotEqual(country.researching, "")

    def test_research_already_set_is_kept(self):
        w = CampaignWorld()
        tag = "POR"
        country = w.countries[tag]
        country.researching = "printing_press"
        before = country.researching
        ai.run(w, tag)
        self.assertEqual(country.researching, before)

    def test_a_country_at_war_prefers_military(self):
        # Muscovy: inland, no colonies, so no navigation pull (coastal colonial powers' cheap
        # navigation techs can outscore the x2 war multiplier; that follows the spec's cost division).
        tag = "MOS"
        w = fresh_with_techs(tag, {"streltsy"})
        rivals = sorted(w.neighbours_of(tag))
        self.assertTrue(rivals, "Muscovy has a neighbour")
        self.assertTrue(w.declare_war(tag, rivals[0]), "the war starts")
        self.assertTrue(w.enemies(tag))
        ai.run(w, tag)
        self.assertEqual(tech.TECHS[w.countries[tag].researching].branch, "military")

    def test_pending_ideas_get_picked(self):
        tag = "POR"
        w = CampaignWorld()
        country = w.countries[tag]
        country.pending_ideas = ["casa_da_india", "humanism", "fuggers_credit"]
        ideas_before = len(country.ideas)
        ai.run(w, tag)
        self.assertEqual(country.pending_ideas, [])
        self.assertEqual(len(country.ideas), ideas_before + 1)
        self.assertTrue(country.ideas & {"casa_da_india", "humanism", "fuggers_credit"})

    def test_sixty_seasons_of_research(self):
        w = CampaignWorld()
        empty_after_run = 0
        for _ in range(60):
            for tag in w.countries:
                ai.run(w, tag)
            empty_after_run += sum(1 for c in w.countries.values()
                                   if c.alive and not c.researching and tech.available(c.techs, c.era))
            w.end_round()
        alive = [c for c in w.countries.values() if c.alive]
        known = sorted(len(c.techs) for c in alive)
        self.assertGreaterEqual(known[len(known) // 2], 4, "most countries know at least 4 techs after 15 years")
        self.assertGreaterEqual(sum(1 for n in known if n >= 4), len(known) * 0.6, "most countries know 4 or more")
        self.assertEqual(empty_after_run, 0, "no country is left without research after the AI moves")

    def test_era_two_opens_after_1520_with_four_era_one_techs(self):
        tag = "POR"
        era_one = ["drill_yards", "guilds", "portolan", "tax_rolls"]
        w = CampaignWorld()
        country = w.countries[tag]
        country.techs = set(country.techs) | set(era_one)
        w._tech_changed(tag)
        self.assertEqual(country.era, 1)
        while w.year() < 1521 and not w.over:
            for t in w.countries:
                ai.run(w, t)
            w.end_round()
            if w.year() < 1520:
                self.assertEqual(country.era, 1, "no new era before 1520")
        self.assertEqual(country.era, 2)


if __name__ == "__main__":
    unittest.main()

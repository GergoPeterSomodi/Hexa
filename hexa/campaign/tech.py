"""Age of Discovery technology tree: pure data and logic (no pygame, no world import).

Keys of national techs and regional defaults are not part of TECHS (the 37 grid techs).
`tech(key)` resolves any of them. `Country.techs` holds keys; a country's national tech
(and `also_knows` extras) are added to that set by the world at start.
"""
from __future__ import annotations

from dataclasses import dataclass, field

# ---------------------------------------------------------------- dataclasses


@dataclass(frozen=True)
class Tech:
    key: str
    name: str
    branch: str
    era: int
    cost: int
    needs: tuple = ()
    effects: dict = field(default_factory=dict)  # defaulted so the fields above can default too
    text: str = ""
    flavour: str = ""
    cards: tuple = ()
    icon: str = ""
    national: str = ""
    also_knows: tuple = ()  # extra techs the owner knows from the start (Banco di Rialto -> banking)


@dataclass(frozen=True)
class Idea:
    key: str
    name: str
    branch: str
    effects: dict
    text: str
    nation: str = ""


# ---------------------------------------------------------------- constants

BRANCHES = ("military", "trade", "navigation", "statecraft")
BRANCH_NAMES = {
    "military": "Military",
    "trade": "Trade & Industry",
    "navigation": "Navigation",
    "statecraft": "Statecraft",
}
ERA_YEARS = {2: 1520, 3: 1575}  # year the era opens (era II and III)
ERA_GATE_TECHS = 4              # known techs of the current era needed to step up

# Every effect key the world understands (see the build spec, "Effect keys").
EFFECT_KEYS = frozenset({
    # unlock flags
    "guilds", "ropewalk", "powder_mill", "glass_leather", "university",
    "carrack", "atlantic", "plantations", "cartography", "galleon", "trace_italienne",
    # numbers
    "stack", "general_stack", "upgrade_max", "wagon_seasons", "siege", "vs_horse",
    "infantry_attack", "artillery_attack", "cavalry_attack", "infantry", "cavalry",
    "castle_max", "garrison_defense", "siege_points", "supply_range", "depot_supply",
    "manufactory_max", "merchants", "farm_works", "mines", "wool", "burgher_tax",
    "production_tax", "high_tax", "tax_relief", "tolls", "colonial_route_cost",
    "market_reach", "sea_range", "colony_upkeep", "colony_growth", "ship_sight",
    "ship_moves", "trading_post_share", "manpower", "research", "fund", "nav_cost",
    "diffusion_cap", "farm_invest", "castle_cost", "cavalry_cost", "money_value",
    "burgher_growth", "coffee_research",
})

# ---------------------------------------------------------------- grid techs

TECHS = {t.key: t for t in [
    # ---- Military
    Tech("drill_yards", "Drill yards", "military", 1, 40,
         effects={"upgrade_max": 1}, text="+1 drill level at barracks",
         flavour="Sergeants drill the levies until every volley lands on the same beat.",
         cards=("Pike square", "Change of front"), icon="drill"),
    Tech("supply_trains", "Supply trains", "military", 1, 40,
         effects={"wagon_seasons": 2}, text="Wagons last 6 seasons",
         flavour="Stout wagons and horse teams keep the column fed far from the depot.",
         cards=("Wagon fort", "Loot the baggage"), icon="wagon"),
    Tech("siege_craft", "Siege craft", "military", 1, 40,
         effects={"siege": 1}, text="Cannons +1 siege",
         flavour="Gunners learn to aim at the walls rather than the sky.",
         cards=("Grand battery", "Mine the walls"), icon="cannon"),
    Tech("tercio", "Tercio", "military", 2, 90, needs=("drill_yards",),
         effects={"vs_horse": 0.25}, text="Infantry +25% vs cavalry",
         flavour="Pikes and shot in a square that no charge can break.",
         cards=("Pike and shot", "Dig in"), icon="pike"),
    Tech("standing_army", "Standing army", "military", 2, 100,
         effects={"stack": 1}, text="Stack limit 6 → 7",
         flavour="A paid army that stays under arms between wars.",
         cards=("Pistol ride", "Call the ban"), icon="flag"),
    Tech("bronze_guns", "Bronze guns", "military", 2, 100,
         needs=("siege_craft", "corned_powder"),
         effects={"artillery_attack": 1}, text="Cannons +1 attack; needs copper",
         flavour="Cast in bronze and loaded with fine powder, the guns finally outrange the walls.",
         cards=("Great bombard", "Guns gallop up"), icon="cannon"),
    Tech("trace_italienne", "Trace italienne", "military", 2, 110,
         effects={"trace_italienne": 1, "castle_max": 1},
         text="Large castle (castle level 3); needs stone",
         flavour="Low angled bastions that turn a siege into a long, expensive affair.",
         cards=("Counter-mine", "Sally out"), icon="castle"),
    Tech("volley_fire", "Volley fire", "military", 3, 170, needs=("tercio",),
         effects={"infantry_attack": 1}, text="Infantry +1 attack",
         flavour="Ranks fire and file back so the line never stops shooting.",
         cards=("Rolling volley", "Countermarch"), icon="musket"),
    Tech("star_forts", "Star forts", "military", 3, 180, needs=("trace_italienne",),
         effects={"garrison_defense": 2, "siege_points": 2},
         text="Castles +2 garrison defense, +2 siege points to take",
         flavour="Arrow-head walls where every angle covers the next.",
         cards=("Burn the fields",), icon="star"),
    Tech("magazines", "Magazines", "military", 3, 170, needs=("supply_trains",),
         effects={"supply_range": 2, "depot_supply": 2},
         text="Supply range +2, depots feed +2 troops",
         flavour="Stores built along the roads turn a march into a steady supply line.",
         cards=("Night attack", "Campfires burning"), icon="barrel"),
    Tech("military_revolution", "Military revolution", "military", 3, 200,
         needs=("standing_army",),
         effects={"stack": 1, "general_stack": 1},
         text="Stack limit 7 → 8, a general adds +1 more",
         flavour="Drill, logistics and staff officers make the army a machine of its own.",
         cards=("Platoon fire",), icon="crown"),

    # ---- Trade & Industry
    Tech("guilds", "Guilds", "trade", 1, 40,
         effects={"guilds": 1, "manufactory_max": 1},
         text="Manufactories can reach level 3",
         flavour="Master craftsmen agree on standards and take on apprentices.",
         icon="guild"),
    Tech("double_entry", "Double-entry books", "trade", 1, 40,
         effects={"merchants": 1}, text="+1 merchant",
         flavour="Ledgers that balance make it possible to trust a partner overseas.",
         icon="scale"),
    Tech("crop_rotation", "Crop rotation", "trade", 1, 35,
         effects={"farm_works": 0.10}, text="Farm tiles +10% per investment level",
         flavour="Fields that rest in turn yield more with every season of care.",
         icon="wheat"),
    Tech("ropewalk", "Ropewalk", "trade", 2, 95, needs=("guilds",),
         effects={"ropewalk": 1}, text="Unlocks the ropewalk: hemp → rope",
         flavour="Long sheds where hemp is twisted into ship's rope.",
         icon="rope"),
    Tech("banking", "Banking", "trade", 2, 100, needs=("double_entry",),
         effects={"burgher_tax": 0.2}, text="Burgher tax +20%",
         flavour="Bills of exchange move money faster than any courier.",
         icon="bank"),
    Tech("corned_powder", "Corned powder", "trade", 2, 95, needs=("guilds",),
         effects={"powder_mill": 1}, text="Unlocks the powder mill",
         flavour="Powder pressed into grains burns hotter and keeps dry.",
         cards=("Through the wall", "Smoke screen"), icon="powder"),
    Tech("glass_leather", "Glass & leather", "trade", 2, 100,
         effects={"glass_leather": 1}, text="Unlocks glassworks and tannery",
         flavour="Sand becomes glass and cattle hides become good leather.",
         icon="glass"),
    Tech("joint_stock", "Joint-stock company", "trade", 3, 180,
         needs=("banking", "colonial_charters"),
         effects={"merchants": 2, "colonial_route_cost": -0.3},
         text="+2 merchants; colonial trade routes cost 30% less",
         flavour="Shares in a voyage spread the risk and the profit among many backers.",
         icon="scroll"),
    Tech("bourse", "Bourse", "trade", 3, 190, needs=("banking",),
         effects={"market_reach": 0.3}, text="Market reach +30%",
         flavour="An exchange where merchants of every nation meet to trade.",
         icon="coin"),
    Tech("coffee_houses", "Coffee houses", "trade", 3, 170,
         needs=("glass_leather", "universities"),
         effects={"coffee_research": 1},
         text="Burghers with coffee add +25% research",
         flavour="Coffee-house talk spreads new ideas across the town.",
         icon="cup"),

    # ---- Navigation
    Tech("portolan", "Portolan charts", "navigation", 1, 35,
         effects={"sea_range": 0.25}, text="Sea routes +25% range",
         flavour="Coastal charts with rhumb lines that every pilot can read.",
         icon="chart"),
    Tech("carrack", "Carrack", "navigation", 1, 40,
         effects={"carrack": 1}, text="Unlocks carracks at shipyards",
         flavour="A deep-hulled ship with castles fore and aft, built for the open sea.",
         cards=("By river and sea",), icon="ship"),
    Tech("astrolabe", "Astrolabe", "navigation", 1, 40,
         effects={"atlantic": 1},
         text="Atlantic crossings; colonists can land across the ocean",
         flavour="A brass instrument that finds latitude out of sight of land.",
         icon="compass"),
    Tech("ocean_pilots", "Ocean pilots", "navigation", 2, 95,
         needs=("portolan", "astrolabe"),
         effects={"ship_sight": 1, "sea_range": 0.5},
         text="Ships +1 sight; sea routes +50% range",
         flavour="Pilots who know the winds and currents of every ocean.",
         cards=("Know the land",), icon="globe"),
    Tech("plantations", "Plantations", "navigation", 2, 100,
         effects={"plantations": 1},
         text="Unlocks sugar, tobacco, cotton and spice plantations",
         flavour="Overseas fields worked for export crops of great value.",
         icon="plant"),
    Tech("cartography", "Cartography", "navigation", 2, 90,
         effects={"cartography": 1},
         text="Explores the coasts your markets trade with",
         flavour="Surveyors record every bay and shoal along the trade lanes.",
         cards=("Catch them crossing",), icon="map"),
    Tech("galleon", "Galleon", "navigation", 3, 180,
         needs=("carrack", "ropewalk"),
         effects={"galleon": 1}, text="Unlocks galleons (rope, iron, timber)",
         flavour="A heavy-gunned ship that carries cargo and cannon across oceans.",
         icon="galleon"),
    Tech("mercator", "Mercator charts", "navigation", 3, 170, needs=("cartography",),
         effects={"ship_moves": 1}, text="Ships +1 move",
         flavour="Projected charts that hold a straight course across the globe.",
         icon="compass"),
    Tech("overseas_factories", "Overseas factories", "navigation", 3, 180,
         needs=("ocean_pilots",),
         effects={"trading_post_share": 0.5}, text="Trading posts +50% share",
         flavour="Walled trading posts where the goods of a continent change hands.",
         icon="factory"),

    # ---- Statecraft
    Tech("tax_rolls", "Tax rolls", "statecraft", 1, 35,
         effects={"production_tax": 0.02}, text="Production tax +2%",
         flavour="A census of every household makes taxes easier to collect.",
         cards=("Turncoats",), icon="scroll"),
    Tech("printing_press", "Printing press", "statecraft", 1, 45,
         effects={"research": 0.15}, text="Research +15%",
         flavour="Movable type makes books, maps and manuals cheap enough to spread.",
         cards=("Feigned retreat",), icon="press"),
    Tech("universities", "Universities", "statecraft", 2, 110,
         needs=("printing_press",),
         effects={"university": 1}, text="Unlocks the University in cities: +1 research",
         flavour="Scholars gather in colleges to teach and to study.",
         icon="book"),
    Tech("colonial_charters", "Colonial charters", "statecraft", 2, 95,
         effects={"colony_upkeep": -0.5, "colony_growth": 0.2},
         text="Colony upkeep −50%; colony growth +20%",
         flavour="Royal charters give settlers rights, and the crown fewer costs.",
         cards=("Native allies", "Guns and horses"), icon="flag"),
    Tech("royal_bureaucracy", "Royal bureaucracy", "statecraft", 2, 100,
         needs=("tax_rolls",),
         effects={"tax_relief": 0.5}, text="High tax hurts growth half as much",
         flavour="Clerks in every province keep the crown's books and its taxes moving.",
         icon="crown"),
    Tech("absolutism", "Absolutism", "statecraft", 3, 190, needs=("royal_bureaucracy",),
         effects={"manpower": 0.25, "high_tax": 0.1},
         text="Manpower +25%; high tax rate +0.1",
         flavour="One crown, one law, and an army raised from every parish.",
         cards=("Hold the line",), icon="crown"),
    Tech("mercantilism", "Mercantilism", "statecraft", 3, 180,
         effects={"tolls": 1.0}, text="Tolls doubled on your own markets",
         flavour="The state keeps trade inside its borders and charges for every crossing.",
         icon="scale"),
]}

# ---------------------------------------------------------------- national techs

_NATIONAL_LIST = [
    Tech("sagres", "Sagres school", "navigation", 1, 0, national="POR",
         effects={"nav_cost": -0.25}, text="Navigation techs −25% cost",
         flavour="Prince Henry's school of pilots and map makers at Sagres.", icon="star"),
    Tech("tercios_viejos", "Tercios viejos", "military", 1, 0, national="CAS",
         effects={"infantry": 0.10}, text="Infantry +10%",
         flavour="Veteran Castilian infantry who have fought in every Italian war.", icon="pike"),
    Tech("banco_di_rialto", "Banco di Rialto", "trade", 1, 0, national="VEN",
         also_knows=("banking",), effects={"tolls": 0.25},
         text="Banking known; tolls +25%",
         flavour="The Rialto bank holds the deposits of half the Mediterranean.", icon="bank"),
    Tech("casa_di_san_giorgio", "Casa di San Giorgio", "statecraft", 1, 0, national="GEN",
         effects={"fund": 0.25}, text="Research funding +25%",
         flavour="The bank of Saint George lends to the state and keeps its accounts strictly.",
         icon="coin"),
    Tech("gendarmerie", "Gendarmerie", "military", 1, 0, national="FRA",
         effects={"cavalry": 0.10}, text="Cavalry +10%",
         flavour="Royal men-at-arms, paid and mounted, who keep the king's peace.", icon="flag"),
    Tech("wool_staple", "Wool staple", "trade", 1, 0, national="ENG",
         effects={"wool": 0.20}, text="Wool output +20%",
         flavour="Every bale of English wool passes through the staple towns.", icon="wheat"),
    Tech("janissary_corps", "Janissary corps", "military", 1, 0, national="TUR",
         effects={"stack": 1}, text="Stack limit +1",
         flavour="Boys taken into service who grow into the finest infantry of the age.", icon="musket"),
    Tech("kontor", "Kontor", "trade", 1, 0, national="HAN",
         effects={"merchants": 1}, text="+1 merchant",
         flavour="The Hansa counting-houses on foreign quays keep the trade flowing.", icon="scale"),
    Tech("habsburg_marriages", "Habsburg marriages", "statecraft", 1, 0, national="AUS",
         effects={"diffusion_cap": 0.2}, text="Diffusion cap +20% (up to 50%)",
         flavour="Dynastic marriages bring knowledge from every court in Europe.", icon="crown"),
    Tech("polders", "Polders", "trade", 1, 0, national="BUR",
         effects={"farm_invest": -0.25}, text="Farm investment −25% cost",
         flavour="Dikes and drainage turn the sea-marsh into rich farmland.", icon="wheat"),
    Tech("streltsy", "Streltsy", "military", 1, 0, national="MOS",
         effects={"manpower": 0.25}, text="Manpower +25%",
         flavour="The tsar's musketeers, raised from the towns and the frontier.", icon="musket"),
    Tech("hussars", "Hussars", "military", 1, 0, national="POL",
         effects={"cavalry_attack": 1}, text="Cavalry +1 attack",
         flavour="Winged lancers who charge with a roar that frightens horses.", icon="flag"),
]
NATIONAL_TECHS = {t.national: t for t in _NATIONAL_LIST}

# Regional defaults for countries without a national tech.
REGIONAL_TECHS = {
    "italian": Tech("studia_humanitatis", "Studia humanitatis", "statecraft", 1, 0,
                    effects={"research": 0.10}, text="Research +10%",
                    flavour="Humanist scholars revive the classics and the sciences.",
                    icon="book"),
    "german": Tech("mining_law", "Mining law", "trade", 1, 0,
                   effects={"mines": 0.10}, text="Mines output +10%",
                   flavour="Codes that settle claims and keep the shafts working.",
                   icon="guild"),
    "north_african": Tech("corsairs", "Corsairs", "navigation", 1, 0,
                          effects={"ship_sight": 1}, text="Ships +1 sight; ships don't fight",
                          flavour="Coastal raiders who know every cove and every sail.",
                          icon="ship"),
    "default": Tech("local_levies", "Local levies", "military", 1, 0,
                    effects={"manpower": 0.10}, text="Manpower +10%",
                    flavour="Men called up from the villages when the bell rings.",
                    icon="pike"),
}


def national_tech(tag: str, region: str = "default") -> Tech:
    """The national tech for a country tag, else the regional default for `region`."""
    if tag in NATIONAL_TECHS:
        return NATIONAL_TECHS[tag]
    return REGIONAL_TECHS.get(region, REGIONAL_TECHS["default"])


def tech(key: str):
    """Look up a grid, national or regional tech by key. None if unknown."""
    if key in TECHS:
        return TECHS[key]
    for t in NATIONAL_TECHS.values():
        if t.key == key:
            return t
    for t in REGIONAL_TECHS.values():
        if t.key == key:
            return t
    return None


# ---------------------------------------------------------------- idea cards

IDEAS = {i.key: i for i in [
    Idea("condottieri", "Condottieri", "military",
         {"cavalry_cost": -0.25, "general_stack": 1},
         "Cavalry costs 25% less gold; generals add +1 stack."),
    Idea("fuggers_credit", "Fuggers' credit", "trade",
         {"fund": 0.25}, "Research funding gives 25% more."),
    Idea("humanism", "Humanism", "statecraft",
         {"research": 0.10}, "Research +10%."),
    Idea("privateer_letters", "Privateer letters", "navigation",
         {"ship_moves": 1}, "Ships +1 move."),
    Idea("reformed_church", "Reformed church", "statecraft",
         {"burgher_growth": 0.20}, "Burgher growth +20%."),
    Idea("royal_mint", "Royal mint", "trade",
         {"money_value": 0.15}, "Silver and gold worth 15% more."),
    Idea("engineers", "Engineers", "military",
         {"castle_cost": -0.25}, "Castles cost 25% less."),
    Idea("navigators_guild", "Navigators' guild", "navigation",
         {"ship_sight": 1}, "Ships +1 sight."),
    Idea("pike_levies", "Pike levies", "military",
         {"manpower": 0.10}, "Recruits need 10% fewer men."),
    Idea("remount_stables", "Remount stables", "military",
         {"cavalry": 0.05}, "Cavalry +5%."),
    Idea("cannon_founders", "Cannon founders", "military",
         {"siege": 1}, "Cannons +1 siege."),
    Idea("farm_improvers", "Farm improvers", "trade",
         {"farm_works": 0.05}, "Farm goods +5% per investment level."),
    Idea("merchant_houses", "Merchant houses", "trade",
         {"merchants": 1}, "+1 merchant."),
    Idea("town_charters", "Town charters", "statecraft",
         {"burgher_tax": 0.10}, "Burgher tax +10%."),
    Idea("colonial_agents", "Colonial agents", "navigation",
         {"colony_upkeep": -0.25}, "Colony upkeep −25%."),
]}

NATIONAL_IDEAS = {
    "POR": [Idea("casa_da_india", "Casa da Índia", "trade",
                 {"trading_post_share": 0.5}, "Trading posts give 50% more share.", "POR")],
    "CAS": [Idea("mesta", "Mesta sheepwalks", "trade",
                 {"wool": 0.15}, "Wool +15%.", "CAS")],
    "VEN": [Idea("arsenal", "Arsenal of Venice", "trade",
                 {"tolls": 0.15}, "Toll income +15%.", "VEN")],
    "GEN": [Idea("genoese_factors", "Genoese factors", "trade",
                 {"merchants": 1}, "+1 merchant.", "GEN")],
    "FRA": [Idea("taille", "Taille royale", "statecraft",
                 {"high_tax": 0.05}, "High tax rate +0.05.", "FRA")],
    "ENG": [Idea("royal_navy", "Royal navy", "navigation",
                 {"ship_sight": 1}, "Ships +1 sight.", "ENG")],
    "TUR": [Idea("sipahi", "Sipahi levy", "military",
                 {"cavalry": 0.10}, "Cavalry +10%.", "TUR")],
    "HAN": [Idea("hansa_cogs", "Hansa cogs", "navigation",
                 {"sea_range": 0.15}, "Sea routes +15% range.", "HAN")],
    "AUS": [Idea("imperial_mines", "Imperial mines", "trade",
                 {"mines": 0.15}, "Mines output +15%.", "AUS")],
    "BUR": [Idea("flemish_cloth", "Flemish cloth halls", "trade",
                 {"burgher_growth": 0.15}, "Burgher growth +15%.", "BUR")],
    "MOS": [Idea("yasak", "Yasak tribute", "military",
                 {"manpower": 0.10}, "Recruits need 10% fewer men.", "MOS")],
    "POL": [Idea("noble_privileges", "Noble privileges", "statecraft",
                 {"tax_relief": 0.25}, "High tax hurts growth 25% less.", "POL")],
}


# ---------------------------------------------------------------- logic

def _prereqs_met(t: Tech, known: set) -> bool:
    return all(n in known for n in t.needs)


def available(known: set, era: int) -> list:
    """Grid techs not known, with prerequisites known, of an era up to `era`."""
    return [k for k, t in TECHS.items()
            if k not in known and t.era <= era and _prereqs_met(t, known)]


def path_to(key: str, known: set) -> list:
    """Unknown prerequisites first (depth first), then `key`. Empty if already known."""
    out = []

    def visit(k):
        if k in known or k in out:
            return
        t = tech(k)
        if t is None:
            return
        for n in t.needs:
            visit(n)
        out.append(k)

    visit(key)
    return out


# Pacing: listed costs times this per era (tuned so a country learns most of the tree by 1650,
# about a tech every few years; the design's numbers are the relative prices).
COST_SCALE = {1: 2.5, 2: 2.5, 3: 4.0}


def cost(key: str, known_by_neighbours: int, bonuses: dict) -> int:
    """Research cost after the era scale, diffusion (capped) and the navigation discount."""
    t = TECHS[key]
    cap = 0.30 + bonuses.get("diffusion_cap", 0)
    disc = min(cap, 0.10 * known_by_neighbours)
    c = t.cost * COST_SCALE.get(t.era, 1.0) * (1 - disc)
    if t.branch == "navigation":
        c *= 1 + bonuses.get("nav_cost", 0)
    return int(round(c))


def _era_count(known: set, era: int) -> int:
    """Techs of `era` learned in the tree (the free national tech does not count toward the gate)."""
    return sum(1 for k in known if k in TECHS and TECHS[k].era == era)


def era_ready(era: int, year: int, known: set) -> bool:
    """Can the country step from `era` to era + 1? Needs the year and ERA_GATE_TECHS techs.

    Only techs of the tree count; the national tech does not.
    """
    if era + 1 not in ERA_YEARS:
        return False
    if year < ERA_YEARS[era + 1]:
        return False
    return _era_count(known, era) >= ERA_GATE_TECHS


def draw_ideas(tag: str, branch_counts: dict, taken: set, rng) -> list:
    """Three distinct idea cards: the nation's own (if one is free), then general cards.

    General cards are weighted 3 when their branch has the most known techs, else 1.
    `taken` are idea keys already used by the country (or by others, as the world decides).
    """
    picks = []
    own = [i for i in NATIONAL_IDEAS.get(tag, ()) if i.key not in taken]
    if own:
        picks.append(rng.choice(own))
    top = max(branch_counts.values(), default=0)
    top_branches = {b for b, n in branch_counts.items() if top > 0 and n == top}
    pool = [i for i in IDEAS.values() if i.key not in taken]
    need = 3 - len(picks)
    while need > 0 and pool:
        weights = [3 if i.branch in top_branches else 1 for i in pool]
        idx = rng.choices(range(len(pool)), weights=weights, k=1)[0]
        picks.append(pool.pop(idx))
        need -= 1
    return picks


def effects(techs: set, ideas: set, national: str) -> dict:
    """Sum of effects over known techs, chosen ideas and the national tech.

    `national` is the national tech key (e.g. "sagres", "studia_humanitatis").
    A country tag is also accepted and resolved through NATIONAL_TECHS.
    """
    out = {}

    def add(d):
        for k, v in (d or {}).items():
            out[k] = out.get(k, 0) + v

    for k in techs:
        t = tech(k)
        if t is not None:
            add(t.effects)
    idea_pool = dict(IDEAS)
    for lst in NATIONAL_IDEAS.values():
        for i in lst:
            idea_pool[i.key] = i
    for k in ideas:
        if k in idea_pool:
            add(idea_pool[k].effects)
    if national:
        t = tech(national) or NATIONAL_TECHS.get(national)
        if t is not None:
            add(t.effects)
    return out


def research_points(base, burghers, universities, coffee_share, bonuses) -> float:
    """RP per season: base + burghers/40 + universities, plus coffee, all times (1 + research)."""
    coffee = coffee_share * burghers / 40 * 0.25 * bonuses.get("coffee_research", 0)
    return (base + burghers / 40 + universities + coffee) * (1 + bonuses.get("research", 0))

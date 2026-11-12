"""The country panel: the chooser before play, your own country (research, treasury, taxes, wars, merchants) and
another country (war or peace, diplomacy)."""
import pygame

from ...ui.kit import heading, panel_frame
from ...ui.theme import BAD_C, GOLD, GOOD_C, MUTED, TEXT
from .. import tech
from ..data import GOODS, TAX_LEVELS

TIPS = {"POR": "Best placed to sail around Africa and across the Atlantic.",
        "CAS": "Big, rich, and close to the Atlantic.", "ENG": "An island with good harbours.",
        "VEN": "Rich in trade but walled in by the Mediterranean.",
        "TUR": "Huge and strong, far from the Atlantic."}
INCOME_LINES = (("production", "Taxes on goods produced"), ("taxes", "Taxes on people"),
                ("buildings", "Manufactories"), ("trade", "Trade (merchants and tolls)"),
                ("upkeep", "Building upkeep"), ("military", "Armies and ships"),
                ("colonies", "Young colonies"), ("interest", "Interest on debt"))
TAX_HINTS = {"low": "Less money, people grow faster", "normal": "Balanced", "high": "More money, people grow slower"}
PEACE_TERMS = (("take", "Take land", "Demand the provinces you occupy"),
               ("white", "White peace", "Everyone keeps their own land"),
               ("yield", "Give up", "They keep what they occupy"))


def tech_name(key):
    """The tech's name, or its raw key when the tech is unknown (an old save or a renamed tech)."""
    t = tech.tech(key)
    return t.name if t else key


def war_line(world, tag):
    """'War: they declared war on you, 2 seasons ago.' for the country panel, or '' when there is no war."""
    me = world.player
    war = next((w for w in world.wars if {w.a, w.b} == {tag, me}), None)
    if war is None:
        return ""
    ago = world.turn - war.start
    when = "this season" if ago <= 0 else f"{ago} season{'s' * (ago != 1)} ago"
    who = "they declared war on you" if war.b == me else "you declared war on them"
    return f"War: {who}, {when}."


def research_line(world):
    """'Researching Drill yards: 12 / 40 RP, 2 queued' for the player, or 'Nothing is being researched'."""
    country = world.countries[world.player]
    if not country.researching:
        return "Nothing is being researched"
    cost = world.tech_cost(world.player, country.researching)
    text = f"Researching {tech_name(country.researching)}: {int(country.research)} / {cost} RP"
    if country.queue:
        text += f", {len(country.queue)} queued"
    return text


def draw(ctx, world, ui, tag):
    """Draw the panel of the country `tag`."""
    x, y, w = panel_frame(ctx)
    country = world.countries[tag]
    y = _header(ctx, world, tag, country, x, y, w)
    if world.player is None:
        _chooser(ctx, tag, country, x, y, w)
    elif tag == world.player:
        _own(ctx, world, tag, country, x, y, w)
    else:
        _other(ctx, world, tag, country, x, y, w)


def _header(ctx, world, tag, country, x, y, w):
    pygame.draw.rect(ctx.screen, country.color, (x, y + 4, 18, 18), border_radius=3)
    ctx.text(ctx.title, country.name, (x + 26, y))
    y += 32
    provs = world.provinces_of(tag)
    ctx.text(ctx.font, f"{len(provs)} provinces, {world.total_pop(tag):,.0f}k people, "
                       f"army {world.army_strength(tag)} regiments", (x, y), width=w)
    y += 20
    colonies = world.colonies_of(tag)
    if colonies:
        ctx.text(ctx.font, f"{len(colonies)} colonies and trading posts", (x, y))
        y += 20
    return y


def _chooser(ctx, tag, country, x, y, w):
    """Before play: the treasury, the Play as button and a tip about the country."""
    y += 10
    ctx.text(ctx.font, f"Treasury {country.treasury:,.0f} ducats, {country.balance:+.1f} a season", (x, y))
    y += 30
    ctx.button((x, y, w, 36), f"Play as {country.name}", True, ("choose", tag), "Start the campaign with this country")
    y += 50
    if tag in TIPS:
        ctx.text(ctx.small, TIPS[tag], (x, y), MUTED, w)


def _own(ctx, world, tag, country, x, y, w):
    y += 6
    ctx.button((x, y, w, 26), "Technology (T)", True, ("tech",), "Research, ideas and the tech tree (T)", small=True)
    y += 32
    ctx.text(ctx.small, research_line(world), (x, y), GOLD, w)
    y += 18
    for i, key in enumerate(country.queue[:4]):
        ctx.text(ctx.small, f"{i + 1}. {tech_name(key)}", (x + 8, y), MUTED, w - 8)
        y += 16
    y = _treasury(ctx, country, x, y + 6, w)
    y = _wars(ctx, world, tag, x, y, w)
    _merchants(ctx, world, tag, country, x, y + 4, w)


def _treasury(ctx, country, x, y, w):
    """The treasury, each source of income, the balance and the tax level buttons; returns the y below."""
    y = heading(ctx, "Treasury", y)
    ctx.text(ctx.font, f"{country.treasury:,.0f} ducats", (x, y), GOLD)
    y += 22
    for key, label in INCOME_LINES:
        if key not in country.income:
            continue
        value = country.income[key]
        ctx.text(ctx.small, label, (x, y), MUTED)
        ctx.text(ctx.small, f"{value:+.1f}", (x + w - 60, y), GOOD_C if value >= 0 else BAD_C)
        y += 17
    ctx.text(ctx.bold, "Each season", (x, y + 2))
    ctx.text(ctx.bold, f"{country.balance:+.1f}", (x + w - 60, y + 2), GOOD_C if country.balance >= 0 else BAD_C)
    y += 28
    ctx.text(ctx.font, "Tax level", (x, y + 4))
    bx = x + 90
    for level in TAX_LEVELS:
        r = ctx.button((bx, y, 82, 26), level.title(), True, ("tax", level), TAX_HINTS[level], small=True)
        if country.tax == level:
            pygame.draw.rect(ctx.screen, GOLD, r, 1, border_radius=5)
        bx += 88
    return y + 36


def _wars(ctx, world, tag, x, y, w):
    """Each war of the player with its score, its age and the three ways out."""
    y = heading(ctx, "Wars", y)
    enemies = world.enemies(tag)
    if not enemies:
        ctx.text(ctx.small, "At peace. Click a neighbour's province to declare war.", (x, y), MUTED)
        y += 20
    for enemy in sorted(enemies):
        ctx.text(ctx.font, f"{world.countries[enemy].name} (war score {world.war_score(tag, enemy):+d})", (x, y))
        y += 20
        ctx.text(ctx.small, war_line(world, enemy), (x, y), BAD_C, w)
        y += 18
        bw = (w - 8) // 3
        for i, (terms, label, hint) in enumerate(PEACE_TERMS):
            ctx.button((x + i * (bw + 4), y, bw, 24), label, True, ("peace", enemy, terms), hint, small=True)
        y += 30
    return y


def _merchants(ctx, world, tag, country, x, y, w):
    """The merchants' standing orders with a Recall button each, and the button to the home market."""
    y = heading(ctx, f"Merchants {len(country.orders)}/{world.merchants(tag)}", y)
    for rid, g, src in country.orders[:6]:
        route = next((r for r in world.routes if r.id == rid), None)
        if not route:
            continue
        dst = route.b.name if src == route.a.name else route.a.name
        result = next((res for res in route.results if res[0] == tag and res[1] == g), None)
        profit = f"{result[3]:+.0f}" if result else "new"
        ctx.text(ctx.small, f"{GOODS[g].name}: {src} > {dst}  ({profit} last season)", (x, y + 4),
                 BAD_C if result and result[3] < 0 else TEXT, w - 70)
        ctx.button((x + w - 64, y, 64, 22), "Recall", True, ("recall", route, (g, src)), small=True)
        y += 26
    free = world.merchants(tag) - len(country.orders)
    if free > 0:
        ctx.text(ctx.small, f"{free} merchant{'s' * (free != 1)} free: open a market, press + on a route.", (x, y), GOLD)
        y += 20
    ctx.button((x, y + 4, w, 26), "Open your home market", True, ("panel", "market"), small=True)


def _other(ctx, world, tag, country, x, y, w):
    """Another country: its treasury, and either the peace terms (at war) or the Declare war button."""
    me = world.player
    y += 6
    relation = "at war with you" if world.at_war(tag, me) else "at peace with you"
    ctx.text(ctx.font, f"Treasury about {country.treasury:,.0f} ducats; {relation}.", (x, y), width=w)
    y += 28
    if world.at_war(tag, me):
        ctx.text(ctx.small, war_line(world, tag), (x, y), BAD_C, w)
        y += 20
        ctx.text(ctx.font, f"War score {world.war_score(me, tag):+d}", (x, y))
        y += 24
        for label, terms, hint in (("Demand the land you occupy", "take", "They accept if you are clearly winning"),
                                   ("Offer white peace", "white", "Everyone keeps their own land"),
                                   ("Give up", "yield", "They keep what they occupy")):
            ctx.button((x, y, w, 26), label, True, ("peace", tag, terms), hint, small=True)
            y += 30
    else:
        ok, reason = world.war_check(me, tag)
        ctx.button((x, y, w, 28), f"Declare war on {country.name}", ok, ("war", tag),
                   reason or "Armies can then enter their land and occupy provinces", small=True)
        y += 34
    ctx.button((x, y, w, 26), "Show their capital", True, ("goto", country.capital), small=True)

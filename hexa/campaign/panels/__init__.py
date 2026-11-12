"""The side panels of the Age of Discovery window, one module each.

A panel is a function ``draw(ctx, world, ui, subject)``: ``ctx`` is the window that draws (``CampaignApp``: its
``text``, ``button`` and ``hoverable`` methods and fonts), ``world`` the game, ``ui`` the selection state and
``subject`` what the panel shows (a province, a unit, a country tag or a market; the ledger has none). Panels read
the world and register buttons; the window's ``press()`` acts on them. ``cards`` builds the hover cards.
"""
from . import country, ledger, market, province, raise_, unit

# panel name -> (its draw function, the ui attribute it shows or None). Kept here, not looked up as
# ``province.draw`` at draw time, so the table does not depend on the package's submodule attributes.
_PANELS = {"province": (province.draw, "province"), "unit": (unit.draw, "selected"),
           "raise": (raise_.draw, "province"), "country": (country.draw, "country"),
           "market": (market.draw, "market"), "ledger": (ledger.draw, None)}


def draw(ctx, world, ui):
    """Draw the panel that ``ui.panel`` names, if what it shows is still there."""
    entry = _PANELS.get(ui.panel)
    if entry is None:
        return
    draw_panel, attribute = entry
    if attribute is None:
        draw_panel(ctx, world, ui)
    elif getattr(ui, attribute):
        draw_panel(ctx, world, ui, getattr(ui, attribute))

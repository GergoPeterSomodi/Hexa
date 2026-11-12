"""The market panel: the table of goods (price, supply, demand, trade) and the trade routes with merchant orders."""
import pygame

from ...ui.kit import heading, panel_frame
from ...ui.theme import BAD_C, GOLD, GOOD_C, MUTED, TEXT
from ..data import GOODS
from .cards import good_card


def draw(ctx, world, ui, market):
    """Draw the panel of `market`."""
    tag = world.player
    x, y, w = panel_frame(ctx)
    owner = world.market_owner(market)
    ctx.text(ctx.title, f"{market.name} market", (x, y))
    y += 28
    ctx.text(ctx.small, f"Centre held by {world.countries[owner].name if owner else 'nobody'}, "
                        f"{len(market.provinces)} provinces trade here", (x, y), MUTED, w)
    y += 22
    y = _table(ctx, world, market, x, y, w)
    y = heading(ctx, "Trade routes", y + 6)
    mine = tag and market in world.merchant_markets(tag)
    routes = sorted(world.routes_of(market), key=lambda r: -r.profit)
    if ui.order_route in routes:
        routes.remove(ui.order_route)
        routes.insert(0, ui.order_route)
    bottom = ctx.panel_rect().bottom
    for route in routes[:7]:
        if y > bottom - 40:
            break
        y = _route(ctx, world, ui, market, route, tag, x, y, w)
    if tag and not mine:
        ctx.text(ctx.small, "Your merchants can only work routes from markets where you own land.", (x, y + 4), MUTED, w)


def _table(ctx, world, market, x, y, w):
    """The goods table: one row a good that is made, bought or money, each with a hover card."""
    cols = (x, x + 92, x + 158, x + 220, x + 282)
    for cx, label in zip(cols, ("Good", "Price", "Supply", "Demand", "Trade")):
        ctx.text(ctx.small, label, (cx, y), MUTED)
    y += 18
    for g, good in GOODS.items():
        supply, demand = market.supply.get(g, 0), market.demand.get(g, 0)
        if supply < 0.05 and demand < 0.05 and good.kind != "money":
            continue
        price = market.price[g]
        ratio = price / good.price
        color = BAD_C if ratio > 1.25 else GOOD_C if ratio < 0.8 else TEXT
        pygame.draw.rect(ctx.screen, good.color, (cols[0], y + 4, 8, 8))
        ctx.text(ctx.small, good.name, (cols[0] + 12, y))
        ctx.hoverable((x, y, w, 16), good_card(world, market, g))
        ctx.text(ctx.small, f"{price:.2f}", (cols[1], y), color)
        ctx.text(ctx.small, f"{supply:.1f}", (cols[2], y))
        ctx.text(ctx.small, f"{demand:.1f}", (cols[3], y))
        net = market.imports.get(g, 0) - market.exports.get(g, 0)
        if abs(net) >= 0.05:
            ctx.text(ctx.small, f"{'in' if net > 0 else 'out'} {abs(net):.1f}", (cols[4], y), GOOD_C if net > 0 else GOLD)
        y += 16
    return y


def _route_card(market, other, route):
    return (f"{market.name} - {other.name}", [
        ("Background trade moves goods from cheap to dear by itself.", TEXT),
        (f"Moving a unit costs {route.cost:.2f} ducats; market owners take tolls.", MUTED),
        ("Press + to give one of your merchants an order on this route:", TEXT),
        ("export or import a good you choose. The profit (or loss) is yours.", GOOD_C)])


def _route(ctx, world, ui, market, route, tag, x, y, w):
    """One trade route: its line and card, the + button, the player's merchants on it and the open order list."""
    other = route.other(market)
    goods = ", ".join(sorted({GOODS[f[0]].name.lower() for f in route.flows})[:3]) or "nothing"
    ctx.text(ctx.small, f"{other.name}{' (sea)' if route.sea else ''}: trade carries {goods}", (x, y + 3), TEXT, w - 40)
    ctx.hoverable((x, y, w - 40, 22), _route_card(market, other, route))
    if tag:
        ok, reason = world.send_merchant_check(tag, route)
        ctx.button((x + w - 34, y, 32, 22), "+", ok, ("merchant", route),
                   reason or "Give a merchant an order on this route", small=True)
    y += 25
    if tag:
        y = _my_orders(ctx, route, tag, x, y, w)
    if tag and ui.order_route is route:
        y = _options(ctx, world, route, tag, x, y, w)
    return y


def _my_orders(ctx, route, tag, x, y, w):
    for owner, g, src in route.orders:
        if owner != tag:
            continue
        dst = route.b.name if src == route.a.name else route.a.name
        result = next((res for res in route.results if res[0] == tag and res[1] == g), None)
        note = f"{result[3]:+.0f} last season" if result else "starts next season"
        ctx.text(ctx.small, f"  your merchant: {GOODS[g].name.lower()} {src} > {dst}, {note}", (x, y + 2),
                 BAD_C if result and result[3] < 0 else GOLD, w - 70)
        ctx.button((x + w - 64, y, 64, 20), "Recall", True, ("recall", route, (g, src)), small=True)
        y += 23
    return y


def _option_card(route, g, src, dst, margin, amount, verb, ok, reason):
    lines = [
        (f"Buy {amount:.0f} at {src.price[g]:.2f} in {src.name}, sell at {dst.price[g]:.2f} in {dst.name}", TEXT),
        (f"Transport {route.cost:.2f} a unit: {margin:+.2f} a unit, about {margin * amount:+.0f} a season",
         GOOD_C if margin > 0 else BAD_C),
        ("Exporting raises the price at home; importing lowers it.", MUTED)]
    if margin <= 0:
        lines.append(("This order loses money on every unit.", BAD_C))
    if not ok:
        lines.insert(0, (reason, BAD_C))
    return f"{verb} {GOODS[g].name.lower()}", lines


def _options(ctx, world, route, tag, x, y, w):
    """The goods a merchant could carry on `route`, best first, each a button that gives the order."""
    options = world.merchant_options(tag, route)[:5]
    if not options:
        ctx.text(ctx.small, "  Nothing worth carrying on this route right now.", (x, y), MUTED)
        y += 20
    for g, src, dst, margin, amount in options:
        verb = "Export" if src in world.merchant_markets(tag) else "Import"
        label = f"{verb} {GOODS[g].name.lower()}: {src.name} > {dst.name}"
        detail = f"{margin:+.1f} x {amount:.0f} = {margin * amount:+.0f}"
        ok, reason = world.send_merchant_check(tag, route)
        ctx.button((x + 10, y, w - 10, 22), label, ok, ("merchant", route, g, src),
                   _option_card(route, g, src, dst, margin, amount, verb, ok, reason), detail, small=True)
        y += 25
    return y

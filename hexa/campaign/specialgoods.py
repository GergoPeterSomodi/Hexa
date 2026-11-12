"""Where the special goods belonged in 1480 (moved out of campaign/world.py, unchanged). Pure: no state, no pygame."""


def special_good(prov, lon, lat, t, r, americas, near):
    """Horses, cattle, stone, copper, hemp, olives, silk, dyes, cocoa and coffee, where they belonged in 1480."""
    if t in ("mountains", "hills") and (near(15.5, 60.5, 3) or near(19.0, 48.7, 2) or near(13.0, 50.5, 1.5)
                                       or near(33.0, 35.0, 1.5) or (americas and lon < -95)) and r < 0.35:
        return "copper"
    if t in ("hills", "mountains") and not americas and lat > 35 and r < (0.3 if near(10.5, 44.0, 3) else 0.16):
        return "stone"
    if t == "steppe" and r < 0.35:
        return "horses"
    if t in ("plains", "savanna") and (near(19.5, 47.0, 3) or near(-5.5, 37.5, 2)) and r < 0.3:
        return "horses"
    if t in ("plains", "marsh", "steppe") and not americas and 44 < lat < 56 and r < 0.12:
        return "cattle"
    if t == "savanna" and not americas and r < 0.15:
        return "cattle"
    if t in ("plains", "marsh") and not americas and lat > 50 and -6 < lon < 45 and r < 0.18:
        return "hemp"
    if t in ("plains", "hills") and (near(29.0, 40.0, 2.5) or near(10.5, 45.2, 1.8) or near(-3.6, 37.2, 1.0)) \
            and r < 0.35:
        return "silk"
    if t in ("plains", "hills", "beach") and not americas and 30 < lat < 43.8 and -10 < lon < 37 and r < 0.3:
        return "olives"
    if americas and t in ("jungle", "savanna", "plains") and lat < 22 and lon > -98:
        if r < 0.16:
            return "cocoa" if lon < -75 else "dyes"
        if r < 0.24:
            return "dyes"
    if t in ("hills", "mountains", "plains", "savanna") and lon > 36 and 8 < lat < 18 and r < 0.4:
        return "coffee"
    return None

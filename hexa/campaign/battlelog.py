"""The battle log as text (battle slice 1b, owner decision 2026-11-13: the log is data, the words are made when shown).

A battle's ``log`` (state.Battle) holds structured records: a dict with ``kind``, ``turn``, ``day`` and the numbers and
tags of the event (combat.record writes them). The panel and the feed call ``describe(entry, names)`` to get a sentence
in the player's language, where ``names`` maps a country tag to its name. A saved sentence can not be translated, so
none is saved.

Old saves kept the text itself: a ``(turn, day, text)`` tuple. ``describe`` shows those as they were written.
Pygame-free.
"""

LANES = ("left", "centre", "right")


def _name(names, tag):
    return names.get(tag, tag) if tag is not None else "nobody"


def describe(entry, names):
    """One log entry as a sentence. ``names``: country tag -> name."""
    if isinstance(entry, (tuple, list)):          # a text line from an older save: shown as written
        return str(entry[-1])
    kind = entry.get("kind")
    if kind == "attacked":
        text = f"{_name(names, entry['attacker'])} attacked {_name(names, entry['defender'])}"
        return text + (" in its castle" if entry.get("assault") else "")
    if kind == "joined":
        side = entry.get("side", "")
        return f"{_name(names, entry['tag'])} joined the {side} side with {entry['men']:,} men"
    if kind == "lane_broken":
        return f"{_name(names, entry['side'])} lost its {LANES[entry['lane']]} lane"
    if kind == "day":
        killed, wounded = entry["killed"], entry["wounded"]
        tags = list(killed)
        parts = [f"{_name(names, t)} {killed[t]:.0f} killed, {wounded.get(t, 0):.0f} wounded" for t in tags]
        text = f"Day {entry['day']}: " + "; ".join(parts)
        if entry.get("broke") is not None:
            fate = "fled" if entry.get("cause") in (None, "morale") else f"broke ({entry['cause']})"
            text += f". {_name(names, entry['broke'])} {fate}"
        return text
    return str(kind)

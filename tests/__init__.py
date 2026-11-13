"""The tests. Importing this package changes two defaults of ``hexa.settings`` for the whole test process.

The window plays the moves the player can see hex by hex and blocks End season while it does (campaign/replay.py), and it
shows the unfinished things in the task flag (hud/tasks.py, campaign/reminders.py). Both are on in the shipped game
(``SHIPPED_DEFAULTS``) and off here, so the many tests that press End season and expect the next season at once do not
wait or find a screen in the way. The tests of the two features switch them on themselves
(``app.settings["movement"] = "normal"``, ``app.settings["reminders"] = True``), and ``test_settings`` checks the shipped
values.
"""
from hexa import settings

SHIPPED_DEFAULTS = dict(settings.DEFAULTS)
settings.DEFAULTS.update(movement="off", reminders=False)

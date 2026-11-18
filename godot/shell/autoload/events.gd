## The event bus (autoload "Events"; docs/architecture/m1-build-spec.md section 8): one signal per kind of event. The
## rules never see it: they append events to Game.events, and Session turns each one into a signal here after an
## action. Handlers read the game and draw; they never change it.
extends Node

## A hex's state changed (build, upgrade, clear): the map view redraws it and its neighbours, the panel refreshes.
signal hex_changed(hex: Vector2i)
## A new game began (or a game was put in place): everything that shows the game starts again from Session.game.
signal game_started
## The current game ended and Session.game is now null.
signal game_ended
## Land changed owner (Territory.transfer): the map redraws those hexes' overlay, borders and labels, the dock refreshes.
signal owners_changed(hexes: Array[Vector2i])
## The human player chose a country (choose_country): the pick ends, the top bar and the map show it.
signal country_chosen(tag: StringName)

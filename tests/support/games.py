"""Whole Conquest and Colonisation games for tests and tools: the computer plays every side, or a stand-in plays yours.

    play_conquest(world)            until somebody wins (at the latest on the turn limit)
    play_colony(world, turns)       whole rounds until ``world.turn > turns`` or somebody wins

``player`` (optional) is called as ``player(world)`` instead of the AI on the human player's turns. ``after_turn``
is called with the world after every ``end_turn()``, that is after each side's turn. For the campaign use
``worlds.play_seasons``.

No pygame here.
"""
from hexa import ai as conquest_ai
from hexa.colony import ai as colony_ai
from hexa.colony.rules import PLAYER as COLONY_PLAYER
from hexa.rules import PLAYER as CONQUEST_PLAYER


def play_conquest(world, after_turn=None, player=None):
    while not world.winner:
        if player and world.current == CONQUEST_PLAYER:
            player(world)
        else:
            for _ in conquest_ai.take_turn(world, world.current):
                pass
        world.end_turn()
        if after_turn:
            after_turn(world)
    return world


def play_colony(world, turns, after_turn=None, player=None):
    while not world.winner and world.turn <= turns:
        if player and world.current == COLONY_PLAYER:
            player(world)
        else:
            for _ in colony_ai.take_turn(world, world.current):
                pass
        world.end_turn()
        if after_turn:
            after_turn(world)
    return world

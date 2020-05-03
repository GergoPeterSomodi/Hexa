from Setting import *


def create_dict():
    temp = {
        '0': 'none.png',
        '1': 'grass_01.png',
        '2': 'grass_02.png',
        '3': 'grass_03.png',
        '4': 'grass_04.png',
        '5': 'grass_05.png',
        '6': 'grass_06.png',
        '7': 'grass_07.png',
        '8': 'grass_08.png',
        '9': 'grass_09.png',
        '10': 'grass_10.png',
        '11': 'grass_11.png',
        '12': 'grass_12.png',
        '13': 'grass_13.png',
        '14': 'grass_14.png',
        '15': 'grass_15.png',
        '16': 'grass_16.png',
        '17': 'grass_17.png',
        '18': 'grass_18.png',
        '19': 'grass_19.png',
        '20': 'none.png',
        '21': 'grass_selection.png',
        '22': 'dirt_01.png',
        '23': 'dirt_02.png',
        '24': 'dirt_03.png',
        '25': 'dirt_04.png',
        '26': 'dirt_05.png',
        '27': 'dirt_06.png',
        '28': 'dirt_07.png',
        '29': 'dirt_08.png',
        '30': 'dirt_09.png',
        '31': 'dirt_10.png',
        '32': 'dirt_11.png',
        '33': 'dirt_12.png',
        '34': 'dirt_13.png',
        '35': 'dirt_14.png',
        '36': 'dirt_15.png',
        '37': 'dirt_16.png',
        '38': 'dirt_17.png',
        '39': 'dirt_18.png',
        '40': 'dirt_19.png',
        '41': 'castle_large.png',
        '42': 'castle_open.png',
        '43': 'castle_small.png',
        '44': 'river_01.png',
        '45': 'river_02.png',
        '46': 'river_03.png',
        '47': 'river_04.png',
        '48': 'river_05.png',
        '49': 'river_06.png',
        '50': 'water_full.png',
        '51': 'lake.png',
    }
    return temp


def create_hex_tile(position_row, position_col, image):
    horizontal_shift = (game_settings.asset_size[0] + game_settings.gap) / 2 * int(position_row % 2)
    left = position_col * game_settings.asset_size[0] + horizontal_shift + position_col * game_settings.gap
    top = position_row * int(game_settings.asset_size[1] * 3 / 4) + position_row * game_settings.gap
    return HexTile((left, top), image)


def load_game():
    temp = create_dict()
    with open('./map.tmx') as base_map:
        data_map = [line.strip().split(',') for line in base_map]
        # print(data_map)
        array = []
        for index_x, x in enumerate(data_map):
            row = []
            for index_y, y in enumerate(x):
                hex_tile = create_hex_tile(index_x, index_y, temp[y])
                row.append(hex_tile)
            array.append(row)
        return array


if __name__ == '__main__':
    load_game()

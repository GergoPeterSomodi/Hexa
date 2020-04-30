from Setting import *


def create_dict():
    temp = {
        '1': 'grass_01.png'
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
                if y == '1':
                    hex_tile = create_hex_tile(index_x, index_y, temp[y])
                    row.append(hex_tile)
            array.append(row)
        return array


if __name__ == '__main__':
    load_game()



    # for rows, tiles in enumerate(map_data):
    #     #     for columns, tile in enumerate(tiles):
    #     #         if tile == '1':
    #     #             print(rows, columns)
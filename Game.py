

def load_game():

    with open('./map.tmx') as base_map:
        data_map = [line.strip().split(',') for line in base_map]
        #print(data_map)


if __name__ == '__main__':
    load_game()


    # for rows, tiles in enumerate(map_data):
    #     #     for columns, tile in enumerate(tiles):
    #     #         if tile == '1':
    #     #             print(rows, columns)
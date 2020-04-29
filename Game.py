

map_data = []
with open('/Users/gergopetersomodi/PycharmProjects/Hexa/map.tmx') as base_map:
    for line in base_map:
        map_data.append(line.strip())

for rows, tiles in enumerate(map_data):
    for columns, tile in enumerate(tiles):
        if tile == '1':
            print(rows, columns)
import math
import pygame
import pygame_gui


class Settings:
    def __init__(self):
        self.scale = 5
        self.asset_size = (self.scale * 12, self.scale * 14)
        self.display_size = (650, 650)
        self.game_size = (self.display_size[0] * 2 / 3, self.display_size[1])
        self.workstation_size = (self.display_size[0] * 1 / 3, self.display_size[1] / 2)


class HexTile:
    def __init__(self, left_top, image):
        self.left_top = left_top
        self.center = (left_top[0] + width / 2, left_top[1] + height / 2)
        self.corners = HexTile.pointy_hex_corner(self.center)
        self.color = white
        self.side_color = black
        self.image = image

    @staticmethod
    def pointy_hex_corner(center):
        points = []
        for corner in range(6):
            angle_deg = 60 * corner - 30
            angle_rad = math.pi / 180 * angle_deg
            pos_x = center[0] + radius * math.cos(angle_rad)
            pos_y = center[1] + radius * math.sin(angle_rad)
            points.append((pos_x, pos_y))
        return points


pygame.init()
game_settings = Settings()

white = (255, 255, 255)
black = (0, 0, 0)
red = (255, 0, 0)
green = (0, 255, 0)
silver = (192, 192, 192)
side_color = silver
surface_color = white

display_size = game_settings.display_size
game_size = game_settings.game_size
workstation_size = game_settings.workstation_size

radius = game_settings.scale * 7
width = game_settings.asset_size[0]
height = game_settings.asset_size[1]
sides_width = 1
gap = 2
num_columns = int(game_size[0] / width)
num_rows = int(game_size[1] / height / (3 / 4))

gameBackground = pygame.display.set_mode(display_size)
manager = pygame_gui.UIManager(display_size)

assets_grass_path = './hexagon-pack/PNG/Tiles/Terrain/Grass/'
assets_dirt_path = './hexagon-pack/PNG/Tiles/Terrain/Dirt/'

green_land = [
    pygame.image.load(assets_grass_path + 'grass_05.png'),
]

green_selected_land = [
    pygame.image.load(assets_grass_path + 'grass_selection.png'),
    pygame.image.load(assets_grass_path + 'grass_06.png'),
    pygame.image.load(assets_grass_path + 'grass_07.png'),
    pygame.image.load(assets_grass_path + 'grass_08.png'),
    pygame.image.load(assets_grass_path + 'grass_09.png')
]

green_forest_land = [
    pygame.image.load(assets_grass_path + 'grass_10.png'),
    pygame.image.load(assets_grass_path + 'grass_11.png'),
    pygame.image.load(assets_grass_path + 'grass_12.png'),
    pygame.image.load(assets_grass_path + 'grass_13.png')
]

dirt_land = [
    pygame.image.load(assets_dirt_path + 'dirt_01.png'),
    pygame.image.load(assets_dirt_path + 'dirt_02.png'),
    pygame.image.load(assets_dirt_path + 'dirt_03.png'),
    pygame.image.load(assets_dirt_path + 'dirt_04.png'),
    pygame.image.load(assets_dirt_path + 'dirt_05.png'),
    pygame.image.load(assets_dirt_path + 'dirt_06.png'),
    pygame.image.load(assets_dirt_path + 'dirt_07.png'),
    pygame.image.load(assets_dirt_path + 'dirt_08.png'),
    pygame.image.load(assets_dirt_path + 'dirt_08.png'),
    pygame.image.load(assets_dirt_path + 'dirt_10.png'),
    pygame.image.load(assets_dirt_path + 'dirt_11.png'),
    pygame.image.load(assets_dirt_path + 'dirt_12.png'),
    pygame.image.load(assets_dirt_path + 'dirt_13.png'),

]

grass_tile = []
for i in range(1):
    grass_tile_render = pygame.transform.scale(green_land[i], game_settings.asset_size)
    grass_tile.append(grass_tile_render)

grass_tile_outside = []
for i in range(4):
    grass_tile_outside_render = pygame.transform.scale(green_selected_land[i], game_settings.asset_size)
    grass_tile_outside.append(grass_tile_outside_render)

grass_tile_forest = []
for i in range(4):
    grass_tile_forest_render = pygame.transform.scale(green_forest_land[i], game_settings.asset_size)
    grass_tile_forest.append(grass_tile_forest_render)

dirt_tiles = []
for i in range(13):
    dirt_land_render = pygame.transform.scale(dirt_land[i], game_settings.asset_size)
    dirt_tiles.append(dirt_land_render)


def get_rectangle(color, x_pos, y_pos, w, h, s):
    pygame.draw.rect(gameBackground, color, [x_pos, y_pos, w, h], s)


def hit_test_rectangle(mouse_position, x, y, w, h):
    if x < mouse_position[0] < (x + h) and y < mouse_position[1] < (y + w):
        return True


def triangle_area(v1, v2, v3):
    return 1 / 2 * abs((v1[0] - v3[0]) * (v2[1] - v1[1]) - (v1[0] - v2[0]) * (v3[1] - v1[1]))


def create_map():
    def create_hex_tile(position_row, position_col, image):
        horizontal_shift = (width + gap) / 2 * int(position_row % 2)
        left = position_col * width + horizontal_shift + position_col * gap
        top = position_row * int(height * 3 / 4) + position_row * gap
        image = grass_tile[0]
        return HexTile((left, top), image)

    def generate_columns(row):
        return [create_hex_tile(row, col, grass_tile[0])
                for col in range(num_columns)]

    return [generate_columns(row)
            for row in range(num_rows)]


def create_workstation(textures):
    columns_size = 3
    a = [textures[x:x + columns_size]
         for x in range(0, len(textures), columns_size)]

    # [[0, 1], [2]]

    def create_hex_tile(position_row, position_col, image):
        #horizontal_shift = (width + gap) / 2 * int(position_row % 2)
        left = position_col * width + position_col * gap + game_size[0] + width / 2 + gap
        top = position_row * height + position_row * gap + int(height * 3 / 4) + gap
        return HexTile((left, top), image)

    def generate_columns(row_index, row_texture):
        return [create_hex_tile(row_index, col_index, texture)
                for col_index, texture in enumerate(row_texture)]

    return [generate_columns(row_index, row_texture)
            for row_index, row_texture in enumerate(a)]


def hit_test(mouse_position, tile):
    corners = tile.corners
    center = tile.center
    values = []
    for corner_num in range(6):
        pos = (corner_num + 1) % 6
        area_total = triangle_area(center, corners[corner_num], corners[pos])
        area1 = triangle_area(mouse_position, corners[corner_num], corners[pos])
        area2 = triangle_area(mouse_position, center, corners[pos])
        area3 = triangle_area(mouse_position, corners[corner_num], center)

        is_inside = area_total >= area1 + area2 + area3 - 1
        values.append(is_inside)

    return any(values)


game_map_1 = create_map()
game_map_2 = create_map()
game_map_3 = create_map()
game_map = game_map_1
workstation_grass = create_workstation(grass_tile_forest)
workstation_dirt = create_workstation(dirt_tiles)
workstation = workstation_grass

base_image = grass_tile[0]
num_layers = 1

options = ["Grass", "Dirt"]
game_map_opt = ["Map1", "Map2", "Map3"]

dropdown = pygame_gui.elements.UIDropDownMenu(relative_rect=pygame.Rect((game_size[0] + width / 2, 20), (80, 30)),
                                              manager=manager,
                                              options_list=options,
                                              starting_option='Grass',
                                              object_id='1',
                                              )

dropdown2 = pygame_gui.elements.UIDropDownMenu(relative_rect=pygame.Rect((game_size[0] + width / 2 + 85, 20), (80, 30)),
                                              manager=manager,
                                              options_list=game_map_opt,
                                              starting_option='Map1',
                                              object_id='1',
                                              )

#add_button = pygame_gui.elements.UIButton(relative_rect=pygame.Rect((500, 510), (30, 30)),
#                                         text='+', manager=manager)

#subtract_button = pygame_gui.elements.UIButton(relative_rect=pygame.Rect((550, 510), (30, 30)),
#                                               text='-', manager=manager)

clock = pygame.time.Clock()

running = True
while running:
    time_delta = clock.tick(60) / 1000.0
    for event in pygame.event.get():
        cursor_x, cursor_y = pygame.mouse.get_pos()
        if event.type == pygame.QUIT:
            running = False

        manager.process_events(event)
        gameBackground.fill(silver)

        for z in game_map:
            for index, i in enumerate(z):
                gameBackground.blit(i.image, i.left_top)

        for z in workstation:
            for index, i in enumerate(z):
                gameBackground.blit(i.image, i.left_top)

        if event.type == pygame.USEREVENT:
            if event.user_type == pygame_gui.UI_DROP_DOWN_MENU_CHANGED:
                if event.text == 'Grass':
                    workstation = workstation_grass
                elif event.text == 'Dirt':
                    workstation = workstation_dirt
                elif event.text == 'Map1':
                    game_map = game_map_1
                elif event.text == 'Map2':
                    game_map = game_map_2
                elif event.text == 'Map3':
                    game_map = game_map_3

            #if event.user_type == pygame_gui.UI_BUTTON_PRESSED:
                #if event.ui_element == subtract_button:
                #    if num_layers > 1:
                #        num_layers -= 1
                #elif event.ui_element == add_button:
                #    if num_layers < 3:
                #        num_layers += 1
                #if event.ui_element == layer_1_button:
                #    game_map = game_map_1
                #elif event.ui_element == layer_2_button:
                #    game_map = game_map_2
                #elif event.ui_element == layer_3_button:
                #    game_map = game_map_3

        if event.type == pygame.MOUSEBUTTONUP:
            mouse_pos = pygame.mouse.get_pos()
            for z in workstation:
                for index, i in enumerate(z):
                    if hit_test(mouse_pos, i):
                        base_image = i.image
                        gameBackground.blit(grass_tile_outside[0], i.left_top)

        if event.type == pygame.MOUSEMOTION:
            mouse_pos = pygame.mouse.get_pos()
            for z in game_map:
                for index, i in enumerate(z):
                    if hit_test(mouse_pos, i):
                        gameBackground.blit(grass_tile_outside[0], i.left_top)

        if event.type == pygame.MOUSEMOTION:
            mouse_pos = pygame.mouse.get_pos()
            for z in workstation:
                for index, i in enumerate(z):
                    if hit_test(mouse_pos, i):
                        gameBackground.blit(grass_tile_outside[0], i.left_top)

        if event.type == pygame.MOUSEBUTTONUP:
            mouse_pos = pygame.mouse.get_pos()
            for z in game_map:
                for index, i in enumerate(z):
                    if hit_test(mouse_pos, i):
                        i.image = base_image
                        gameBackground.blit(i.image, i.left_top)

    manager.update(time_delta)
    manager.draw_ui(gameBackground)
    pygame.display.flip()

pygame.quit()

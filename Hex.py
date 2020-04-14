import math
import pygame


class Settings:
    def __init__(self):
        self.scale = 5
        self.asset_size = (self.scale * 12, self.scale * 14)
        self.display_size = (650, 650)


class HexTile:
    def __init__(self, left_top):
        self.left_top = left_top
        self.center = (left_top[0] + height // 2, left_top[1] + width // 2)
        self.corners = HexTile.pointy_hex_corner(self.center)
        self.color = white
        self.side_color = black

    @staticmethod
    def pointy_hex_corner(center):
        points = []
        for corner in range(6):
            angle_deg = 60 * corner - 30
            angle_rad = math.pi / 180 * angle_deg
            pos_x = center[0] + radius * math.cos(angle_rad)
            pos_y = center[1] + radius * math.sin(angle_rad)
            points.append([int(pos_x), int(pos_y)])
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

radius = 7
width = game_settings.asset_size[0]
height = game_settings.asset_size[1]
sides_width = 1
gap = 2
num_columns = int(display_size[0] / width)
num_rows = int(display_size[1] / height / (3 / 4))

gameBackground = pygame.display.set_mode(display_size)


def triangle_area(v1, v2, v3):
    return 1 / 2 * abs((v1[0] - v3[0]) * (v2[1] - v1[1]) - (v1[0] - v2[0]) * (v3[1] - v1[1]))


def create_map():
    def create_hex_tile(position_row, position_col):
        horizontal_shift = (width + gap) / 2 * int(position_row % 2)
        left = position_col * width + horizontal_shift + position_col * gap
        top = position_row * int(height * 3 / 4) + position_row * gap
        return HexTile((left, top))

    def generate_columns(row):
        return [create_hex_tile(row, col)
                for col in range(num_columns)]

    return [generate_columns(row)
            for row in range(num_rows)]


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


game_map = create_map()
assets_grass_path = './hexagon-pack/PNG/Tiles/Terrain/Grass/'
Grass_tile_mid = pygame.image.load(assets_grass_path + 'grass_15.png')
Grass_tile = pygame.image.load(assets_grass_path + 'grass_05.png')
Grass_tile_mid = pygame.transform.scale(Grass_tile_mid, game_settings.asset_size)
Grass_tile = pygame.transform.scale(Grass_tile, game_settings.asset_size)

running = True
while running:

    for event in pygame.event.get():
        cursor_x, cursor_y = pygame.mouse.get_pos()
        if event.type == pygame.QUIT:
            running = False

        if event.type == pygame.MOUSEBUTTONUP:
            mouse_pos = pygame.mouse.get_pos()
            for z in game_map:
                for i in z:
                    i.color = white
                    if hit_test(mouse_pos, i):
                        i.color = green

        if event.type == pygame.MOUSEMOTION:
            mouse_pos = pygame.mouse.get_pos()
            for z in game_map:
                for i in z:
                    i.side_color = silver
                    if hit_test(mouse_pos, i):
                        i.side_color = red

    gameBackground.fill(silver)
    for z in game_map:
        for index, i in enumerate(z):
            texture = Grass_tile_mid
            if index % 2 == 0:
                texture = Grass_tile
            gameBackground.blit(texture, i.left_top)

    pygame.display.flip()

pygame.quit()

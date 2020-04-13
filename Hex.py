import pygame
import math

pygame.init()

white = (255, 255, 255)
black = (0, 0, 0)
red = (255, 0, 0)
green = (0, 255, 0)
silver = (192, 192, 192)
side_color = silver
surface_color = white

display_size = [650, 650]

radius = 32
height = 2 * radius
width = math.sqrt(3) * radius
sides_width = 1
x = 0 + width // 2
y = 0 + radius
num_columns = int(display_size[0] / width)
num_rows = int(display_size[1] / height / (3 / 4))

gameBackground = pygame.display.set_mode(display_size)


def pointy_hex_corner(x, y, radius):
    points = []
    for i in range(6):
        angle_deg = 60 * i - 30
        angle_rad = math.pi / 180 * angle_deg
        pos_x = x + radius * math.cos(angle_rad)
        pos_y = y + radius * math.sin(angle_rad)
        points.append([int(pos_x), int(pos_y)])
    return points


def triangle_area(v1, v2, v3):
    return 1 / 2 * abs((v1[0] - v3[0]) * (v2[1] - v1[1]) - (v1[0] - v2[0]) * (v3[1] - v1[1]))


class hex_tile:
    def __init__(self, corners, color, side_color, center_x, center_y):
        self.corners = corners
        self.color = color
        self.side_color = side_color
        self.center_x = center_x
        self.center_y = center_y

def create_map():
    map = []

    for z in range(num_rows):
        row = []
        map.append(row)
        for i in range(num_columns):
            if z % 2 == 0:
                column = pointy_hex_corner(x + i * width, y + z * height * 3 / 4, radius)
                center_x = x + i * width
                center_y = y + z * height * 3 / 4
                tile = hex_tile(column, white, black, center_x, center_y)

            else:
                column = pointy_hex_corner((x + i * width) + width / 2, y + z * height * 3 / 4, radius)
                center_x = (x + i * width) + width / 2
                center_y = y + z * height * 3 / 4
                tile = hex_tile(column, white, black, center_x, center_y)

            row.append(tile)
    return map


def hit_test(mouse_pos, tile):
    corners = tile.corners
    center = (tile.center_x, tile.center_y)
    values = []
    for i in range(6):
        pos = (i + 1) % 6
        area_total = triangle_area(center, corners[i], corners[pos])
        area1 = triangle_area(mouse_pos, corners[i], corners[pos])
        area2 = triangle_area(mouse_pos, center, corners[pos])
        area3 = triangle_area(mouse_pos, corners[i], center)

        is_inside = area_total >= area1 + area2 + area3 - 1
        values.append(is_inside)

    if any(values):
        return True

    else:
        return False


game_map = create_map()
Grass_tile_mid = pygame.image.load('military_rockets.png')
Grass_tile_mid = pygame.transform.scale(Grass_tile_mid, (int(width), int(height)))

running = True
while running:

    for event in pygame.event.get():
        cursor_x, cursor_y = pygame.mouse.get_pos()
        if event.type == pygame.QUIT:
            running = False

        if event.type == pygame.MOUSEBUTTONUP:
            mouse_pos = pygame.mouse.get_pos()
            for x, z in enumerate(game_map):
                for y, i in enumerate(z):
                    i.color = white
                    if hit_test(mouse_pos, i):
                        i.color = green

        if event.type == pygame.MOUSEMOTION:
            mouse_pos = pygame.mouse.get_pos()
            for x, z in enumerate(game_map):
                for y, i in enumerate(z):
                    i.side_color = silver
                    if hit_test(mouse_pos, i):
                        i.side_color = red

    gameBackground.fill(silver)
    for z in game_map:
        for i in z:
            pygame.draw.polygon(gameBackground, i.color, i.corners)
            #gameBackground.blit(Grass_tile_mid, (i.center_x - width // 2, i.center_y - radius))
            pygame.draw.polygon(gameBackground, i.side_color, i.corners, sides_width)

    pygame.display.flip()

pygame.quit()

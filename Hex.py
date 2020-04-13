import pygame
import math

pygame.init()

white = (255, 255, 255)
black = (0, 0, 0)
red = (255, 0, 0)
green = (0, 255, 0)
sides_color = black
surface_color = white

display_size = [1000, 1000]

radius = 50
height = 2 * radius
width = math.sqrt(3) * radius
sides_width = 1
x = 0
y = 0 + radius / 2
num_columns = int(display_size[0] / width)
num_rows = int(display_size[1] / height / (3 / 4))

gameBackground = pygame.display.set_mode(display_size)


def pointy_hex(x, y, radius):
    points = []
    for i in range(6):
        angle_deg = 60 * i - 30
        angle_rad = math.pi / 180 * angle_deg
        x = x + radius * math.cos(angle_rad)
        y = y + radius * math.sin(angle_rad)
        points.append([int(x), int(y)])
    pygame.draw.polygon(gameBackground, surface_color, points)
    pygame.draw.polygon(gameBackground, sides_color, points, sides_width)

running = True
while running:

    for event in pygame.event.get():
        cursor_x, cursor_y = pygame.mouse.get_pos()
        if event.type == pygame.QUIT:
            running = False
            pygame.quit()

        gameBackground.fill(white)
        surface_color = white
        for z in range(num_rows):
            for i in range(num_columns):
                if z % 2 == 0:
                    pointy_hex(x + i * width, y + z * height * 3 / 4, radius)

                else:
                    pointy_hex((x + i * width) + width / 2, y + z * height * 3 / 4, radius)

        if event.type == pygame.MOUSEBUTTONDOWN:
            surface_color = green
            pointy_hex(cursor_x, cursor_y, radius)

    pygame.display.flip()

pygame.quit()

import pygame
import math

pygame.init()

white = (255, 255, 255)
black = (0, 0, 0)

display_size = [1000, 1000]

radius = 50
height = 2 * radius
width = math.sqrt(3) * radius
sides_width = 1
gap = 2
x = 0
y = 0 + radius / 2
num_columns = int(display_size[0] / width)
num_rows = int(display_size[1] / height / (3 / 4))

gameBackground = pygame.display.set_mode(display_size)


def pointy_hex_corner(x, y, radius):
    points = []
    for i in range(6):
        angle_deg = 60 * i - 30
        angle_rad = math.pi / 180 * angle_deg
        x = x + radius * math.cos(angle_rad)
        y = y + radius * math.sin(angle_rad)
        points.append([int(x), int(y)])
    pygame.draw.polygon(gameBackground, black, points, sides_width)


running = True
while running:

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
            pygame.quit()

        gameBackground.fill(white)

        for z in range(num_rows):
            for i in range(num_columns):
                if z % 2 == 0:
                    pointy_hex_corner(x + i * width, y + z * height * 3 / 4, radius)
                else:
                    pointy_hex_corner((x + i * width) + width / 2, y + z * height * 3 / 4, radius)



    pygame.display.flip()

pygame.quit()







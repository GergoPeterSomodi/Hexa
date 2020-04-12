import pygame
import math

pygame.init()

white = (255, 255, 255)
black = (0, 0, 0)

x = 100
y = 100
radius = 50

gameBackground = pygame.display.set_mode([500, 500])


def pointy_hex_corner(x, y, radius):
    points = []
    for i in range(6):
        angle_deg = 60 * i - 30
        angle_rad = math.pi / 180 * angle_deg
        x = x + radius * math.cos(angle_rad)
        y = y + radius * math.sin(angle_rad)
        points.append([int(x), int(y)])
    pygame.draw.polygon(gameBackground, black, points)


running = True
while running:

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
            pygame.quit()

        gameBackground.fill(white)

        pointy_hex_corner(x, y, radius)

    pygame.display.flip()

pygame.quit()







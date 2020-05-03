import math


class Settings:
    def __init__(self):
        self.scale = 5
        self.asset_size = (self.scale * 12, self.scale * 14)
        self.asset_size_medium = (self.scale * 10, self.scale * 12)
        self.asset_size_small = (self.scale * 8, self.scale * 10)
        self.display_size = (650, 650)
        self.game_size = (self.display_size[0] * 2 / 3, self.display_size[1])
        self.workstation_size = (self.display_size[0] * 1 / 3, self.display_size[1] / 2)
        self.side_width = 1
        self.gap = 2
        self.radius = self.scale * 7
        self.width = self.asset_size[0]
        self.height = self.asset_size[1]


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

sides_width = 1
gap = 2
num_columns = int(game_size[0] / game_settings.width)
num_rows = int(game_size[1] / game_settings.height / (3 / 4))

class HexTile:
    def __init__(self, left_top, image_path):
        self.left_top = left_top
        self.center = (left_top[0] + game_settings.width / 2, left_top[1] + game_settings.height / 2)
        self.corners = HexTile.pointy_hex_corner(self.center)
        self.color = white
        self.side_color = black
        self.image_path = image_path

    @staticmethod
    def pointy_hex_corner(center):
        points = []
        for corner in range(6):
            angle_deg = 60 * corner - 30
            angle_rad = math.pi / 180 * angle_deg
            pos_x = center[0] + game_settings.radius * math.cos(angle_rad)
            pos_y = center[1] + game_settings.radius * math.sin(angle_rad)
            points.append((pos_x, pos_y))
        return points
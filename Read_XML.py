import xml.etree.ElementTree as ET
from Game import *

image = ['none.png', "grass_01.png", "grass_02.png", "grass_03.png"]


def get_hex_id(images):

    temp = create_dict()
    layer_map = []

    for image in images:
        for key, value in temp.items():
            if value == image:
                layer_id = key
                layer_map.append(layer_id)
    return layer_map

id = get_hex_id(image)
print(id)


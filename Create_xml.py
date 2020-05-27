from xml.etree import ElementTree, cElementTree
from xml.dom import minidom
from Setting import *


num_columns = str(int(game_size[0] / game_settings.width))
num_rows =str(int(game_size[1] / game_settings.height / (3 / 4)))
layer_id = 1


root = ElementTree.Element('map', width=num_columns, height=num_rows, tilewidth="32", tileheight="32")
child1 = ElementTree.SubElement(root, 'layer', id="1", name="Tile Layer 1", width=num_columns, height=num_rows)
child1_1 = ElementTree.SubElement(child1, 'data')
child2 = ElementTree.SubElement(root, 'layer', id="2", name="Tile Layer 2", width=num_columns, height=num_rows)
child2_1 = ElementTree.SubElement(child2, 'data')
child3 = ElementTree.SubElement(root, 'layer', id="3", name="Tile Layer 3", width=num_columns, height=num_rows)
child3_1 = ElementTree.SubElement(child3, 'data')

child1_1.text = "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"
child2_1.text = "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"
child3_1.text = "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"


print(ElementTree.tostring(root))
tree = cElementTree.ElementTree(root) # wrap it in an ElementTree instance, and save as XML

t = minidom.parseString(ElementTree.tostring(root)).toprettyxml() # Since ElementTree write() has no pretty printing support, used minidom to beautify the xml.
tree1 = ElementTree.ElementTree(ElementTree.fromstring(t))

tree1.write("map3.xml",encoding='utf-8', xml_declaration=True)

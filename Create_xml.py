from xml.etree import ElementTree, cElementTree
from xml.dom import minidom

root = ElementTree.Element('map', width="5", height="5", tilewidth="32", tileheight="32")
child1 = ElementTree.SubElement(root, 'layer', id="1", name="Tile Layer 1", width="5", height="5")
child1_1 = ElementTree.SubElement(child1, 'data')

lines = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

child1_1.text = "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"


print(ElementTree.tostring(root))
tree = cElementTree.ElementTree(root) # wrap it in an ElementTree instance, and save as XML

t = minidom.parseString(ElementTree.tostring(root)).toprettyxml() # Since ElementTree write() has no pretty printing support, used minidom to beautify the xml.
tree1 = ElementTree.ElementTree(ElementTree.fromstring(t))

tree1.write("map3.xml",encoding='utf-8', xml_declaration=True)

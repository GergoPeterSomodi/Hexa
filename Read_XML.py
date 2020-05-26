import xml.etree.ElementTree as ET

print((1))
def read_xml(layer_id):
    tree = ET.parse('map2.tmx')
    root = tree.getroot()

    for layer in root.findall(".//layer"):
        #print(layer.get('id'))
        for data in layer:
            if layer.get('id') == '1':
                #print(data.text)
                base_map = data.text
    return base_map

print(read_xml('2'))

with open('./map.tmx') as base_map:
    print(base_map)

#print(root.tag)
#print(root.attrib)

#for child in root:
#    print(child.tag, child.attrib)

#for data in root.iter('data'):
#    print(data.attrib)

#for data in root.iter('data'):
#    print(data.text)

#for data in root.findall("./layer/[@id='1']"):
#    print(data.tag, data.attrib)
#    print(data.get('name'))
#    print(data.get('id'))

#for data in root.findall("./layer/[@id='1'])"):
#        print(data.text)

#for data in root.findall('layer/data'):
#        print(data.text)


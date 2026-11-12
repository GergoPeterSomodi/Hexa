"""The historical regions of the Europe 1480 map: a name, a longitude and latitude, and the country that held it.

Every land hex belongs to the region of the nearest anchor, and an anchor of the hex's own country counts as
closer (see naming.py). The New World and tropical Africa have the native peoples' lands, which all end in
" lands" like the old tribe names ("Ojibwe lands"). Plain data: no pygame, no game rules.
"""

# name | longitude | latitude | country tag in 1480 (empty: no country on the map)
_OLD_WORLD = """
Minho|-8.35|41.75|POR
Douro|-8.2|41.05|POR
Trás-os-Montes|-7.1|41.6|POR
Beira Alta|-7.6|40.6|POR
Beira Litoral|-8.5|40.2|POR
Beira Baixa|-7.4|39.9|POR
Ribatejo|-8.5|39.3|POR
Estremadura|-9.0|39.0|POR
Alto Alentejo|-7.6|38.9|POR
Baixo Alentejo|-8.0|37.9|POR
Algarve|-8.1|37.2|POR
Madeira|-16.9|32.7|POR
Azores|-27.5|38.6|POR
Galicia|-8.0|42.7|CAS
Asturias|-5.9|43.3|CAS
Cantabria|-4.1|43.1|CAS
Biscay|-2.9|43.2|CAS
Guipúzcoa|-2.2|43.1|CAS
Álava|-2.7|42.85|CAS
León|-5.7|42.6|CAS
Tierra de Campos|-4.9|42.0|CAS
Old Castile|-3.7|42.3|CAS
Soria|-2.5|41.8|CAS
Salamanca|-5.8|40.9|CAS
Segovia|-4.1|40.9|CAS
New Castile|-3.5|39.9|CAS
Alcarria|-2.6|40.6|CAS
New Castile|-3.7|40.4|CAS
La Mancha|-3.0|39.0|CAS
Extremadura|-6.2|39.0|CAS
Seville|-5.8|37.4|CAS
Córdoba|-4.8|37.9|CAS
Jaén|-3.8|37.9|CAS
Cádiz|-6.0|36.5|CAS
Granada|-3.4|37.0|GRA
Almería|-2.4|37.0|GRA
Murcia|-1.4|38.0|CAS
Valencia|-0.7|39.5|ARA
Alicante|-0.6|38.5|ARA
Aragon|-0.8|41.7|ARA
Upper Aragon|-0.2|42.3|ARA
Teruel|-1.1|40.4|ARA
Catalonia|1.5|41.8|ARA
Lleida|0.8|41.6|ARA
Roussillon|2.6|42.65|ARA
Navarre|-1.6|42.7|
La Rioja|-2.4|42.3|CAS
Majorca|2.9|39.6|ARA
Ibiza|1.4|38.9|ARA
Malta|14.4|35.9|ARA
Cagliari|9.1|39.3|ARA
Logudoro|8.9|40.5|ARA
Gallura|9.3|41.0|ARA
Corsica|9.1|42.1|GEN
Val di Mazara|12.9|37.8|ARA
Val Demone|14.8|38.0|ARA
Val di Noto|14.8|37.0|ARA
Île-de-France|2.4|48.8|FRA
Picardy|2.8|49.8|FRA
Normandy|0.2|49.0|FRA
Caux|1.0|49.7|FRA
Brittany|-2.8|48.2|BRI
Cornouaille|-4.0|48.0|BRI
Léon|-4.4|48.5|BRI
Maine|-0.2|48.0|FRA
Anjou|-0.5|47.4|FRA
Touraine|0.7|47.4|FRA
Orléanais|1.9|47.9|FRA
Berry|2.0|47.0|FRA
Nivernais|3.4|47.0|FRA
Bourbonnais|3.3|46.3|FRA
Auvergne|3.1|45.5|FRA
Limousin|1.5|45.6|FRA
La Marche|2.0|46.2|FRA
Poitou|-0.3|46.6|FRA
Saintonge|-0.8|45.8|FRA
Angoumois|0.1|45.7|FRA
Guyenne|-0.2|44.6|FRA
Gascony|0.2|43.8|FRA
Landes|-0.9|44.0|FRA
Béarn|-0.5|43.2|FRA
Foix|1.6|42.9|FRA
Languedoc|3.0|43.5|FRA
Rouergue|2.4|44.3|FRA
Quercy|1.5|44.6|FRA
Périgord|0.8|45.1|FRA
Gévaudan|3.5|44.6|FRA
Vivarais|4.5|44.8|FRA
Provence|5.8|43.7|FRA
Dauphiné|5.7|45.0|FRA
Lyonnais|4.6|45.9|FRA
Burgundy|4.7|47.2|BUR
Franche-Comté|5.9|47.0|BUR
Champagne|4.3|48.6|FRA
Lorraine|6.2|48.7|
Alsace|7.5|48.3|
Comtat Venaissin|4.9|44.0|PAP
Bresse|5.2|46.2|SAV
Artois|2.6|50.4|BUR
Flanders|3.2|51.0|BUR
Brabant|4.7|50.9|BUR
Hainaut|3.9|50.4|BUR
Namur|4.9|50.3|BUR
Luxembourg|6.0|49.8|BUR
Liège|5.6|50.6|
Limburg|5.8|51.1|BUR
Holland|4.6|52.2|BUR
Zeeland|3.8|51.5|BUR
Utrecht|5.1|52.1|
Guelders|5.9|52.0|BUR
Overijssel|6.3|52.4|
Friesland|5.8|53.1|
Groningen|6.6|53.2|
Cleves|6.2|51.7|
Oldenburg Marsh|8.0|53.5|
Middlesex|-0.3|51.55|ENG
Surrey|-0.4|51.3|ENG
Cornwall|-4.8|50.4|ENG
Devon|-3.7|50.7|ENG
Somerset|-2.8|51.1|ENG
Dorset|-2.3|50.8|ENG
Hampshire|-1.3|51.0|ENG
Sussex|-0.4|50.95|ENG
Kent|0.7|51.2|ENG
Essex|0.5|51.8|ENG
East Anglia|1.0|52.5|ENG
The Fens|0.0|52.6|ENG
Wiltshire|-1.9|51.3|ENG
Thames Valley|-1.2|51.6|ENG
Gloucestershire|-2.2|51.9|ENG
Warwickshire|-1.5|52.3|ENG
Staffordshire|-1.9|52.8|ENG
Leicestershire|-1.0|52.7|ENG
Lincolnshire|-0.2|53.1|ENG
Nottinghamshire|-1.0|53.1|ENG
Welsh Marches|-2.8|52.5|ENG
West Riding|-1.8|53.8|ENG
North Riding|-1.1|54.3|ENG
East Riding|-0.5|53.9|ENG
Lancashire|-2.6|53.8|ENG
Cheshire|-2.6|53.2|ENG
Cumberland|-3.0|54.6|ENG
Durham|-1.6|54.7|ENG
Northumberland|-1.9|55.2|ENG
North Wales|-3.9|53.0|ENG
Mid Wales|-3.7|52.4|ENG
South Wales|-3.6|51.7|ENG
Dyfed|-4.7|51.9|ENG
Lothian|-3.2|55.9|SCO
The Borders|-2.8|55.5|SCO
Galloway|-4.3|55.0|SCO
Clydesdale|-4.0|55.7|SCO
Fife|-3.1|56.2|SCO
Atholl|-3.9|56.6|SCO
Angus|-2.8|56.7|SCO
Mar|-2.7|57.3|SCO
Moray|-3.5|57.5|SCO
Ross|-4.7|57.7|SCO
Sutherland|-4.3|58.2|SCO
Caithness|-3.4|58.4|SCO
Argyll|-5.2|56.2|SCO
Lordship of the Isles|-6.2|57.0|
Orkney|-3.0|59.0|SCO
Ulster|-6.8|54.7|IRE
Connacht|-8.8|53.7|IRE
Munster|-8.8|52.2|IRE
Leinster|-7.0|52.9|IRE
The Pale|-6.5|53.6|IRE
Desmond|-9.5|52.0|IRE
Zealand|11.8|55.4|DAN
Funen|10.4|55.3|DAN
Jutland|9.3|56.2|DAN
North Jutland|9.9|57.2|DAN
Scania|13.4|55.9|DAN
Halland|12.7|56.9|DAN
Blekinge|15.0|56.3|DAN
Slesvig|9.5|54.7|DAN
Holstein|9.9|54.0|DAN
Bornholm|14.9|55.1|DAN
Gotland|18.5|57.5|DAN
Viken|10.8|59.5|DAN
Opplandene|10.8|61.2|DAN
Agder|7.8|58.4|DAN
Rogaland|6.0|59.0|DAN
Hordaland|6.0|60.4|DAN
Sogn|7.0|61.2|DAN
Møre|7.5|62.3|DAN
Västergötland|13.2|58.2|SWE
Östergötland|15.4|58.4|SWE
Småland|14.8|57.2|SWE
Närke|15.0|59.3|SWE
Södermanland|16.7|59.1|SWE
Uppland|17.6|59.9|SWE
Västmanland|16.2|59.7|SWE
Värmland|13.1|59.7|SWE
Dalarna|14.8|60.9|SWE
Gästrikland|16.8|60.8|SWE
Hälsingland|16.0|61.8|SWE
Medelpad|16.8|62.4|SWE
Finland Proper|22.3|60.5|SWE
Nyland|25.0|60.4|SWE
Tavastia|24.8|61.2|SWE
Savonia|27.5|62.2|SWE
Ostrobothnia|22.5|62.3|SWE
Åland|20.0|60.2|SWE
Karelia|30.0|61.5|MOS
Mecklenburg|12.0|53.7|
Brunswick-Lüneburg|10.5|52.8|BRU
Hanover|9.7|52.4|BRU
Oldenburg|8.2|53.1|
East Frisia|7.4|53.4|
Westphalia|7.8|51.7|COL
Electorate of Cologne|7.0|50.8|COL
Berg|7.2|51.1|COL
Hesse|9.2|51.1|HES
Wetterau|8.6|50.3|HES
Thuringia|11.0|50.9|SAX
Electoral Saxony|12.7|51.7|SAX
Meissen|13.5|51.1|SAX
Lusatia|14.5|51.4|BOH
Altmark|11.5|52.7|BRA
Mittelmark|13.2|52.4|BRA
Neumark|15.0|52.7|BRA
Uckermark|13.8|53.1|BRA
West Pomerania|13.5|53.9|POM
East Pomerania|16.5|54.1|POM
Upper Bavaria|11.8|48.0|BAV
Lower Bavaria|12.7|48.6|BAV
Upper Palatinate|12.0|49.5|BAV
Swabia|9.7|48.2|WUR
Württemberg|9.2|48.7|WUR
Franconia|10.3|49.8|
Baden|8.3|48.8|
Palatinate|8.1|49.3|PAL
Rhineland|7.3|50.2|PAL
Hunsrück|7.2|49.8|PAL
Swiss Plateau|7.9|47.1|SWI
Central Switzerland|8.5|46.9|SWI
Graubünden|9.5|46.7|SWI
Valais|7.6|46.1|
Savoy|6.2|45.6|SAV
Piedmont|7.8|44.8|SAV
Aosta|7.3|45.7|SAV
Lombardy|9.7|45.5|MLO
Montferrat|8.3|45.0|
Liguria|8.8|44.4|GEN
Emilia|10.9|44.6|
Mantua|10.8|45.3|
Romagna|12.0|44.3|PAP
The Marches|13.2|43.4|PAP
Umbria|12.5|42.9|PAP
Lazio|12.8|41.8|PAP
Tuscany|11.0|43.4|TUS
Maremma|11.1|42.7|TUS
Trentino|11.1|46.2|
Veneto|11.8|45.6|VEN
Friuli|13.1|46.1|VEN
Istria|13.9|45.2|VEN
Abruzzo|13.9|42.2|NAP
Molise|14.7|41.6|NAP
Campania|14.8|40.9|NAP
Apulia|16.3|41.0|NAP
Salento|18.1|40.2|NAP
Basilicata|16.0|40.5|NAP
Calabria|16.4|39.0|NAP
Tyrol|11.2|47.1|AUS
Salzburg|13.1|47.6|
Upper Austria|14.2|48.2|AUS
Lower Austria|15.8|48.3|AUS
Styria|15.0|47.2|AUS
Carinthia|14.1|46.7|AUS
Carniola|14.5|46.0|AUS
Bohemia|14.9|50.0|BOH
Moravia|16.9|49.4|BOH
Lower Silesia|16.5|51.1|BOH
Upper Silesia|18.0|50.4|BOH
Greater Poland|17.2|52.2|POL
Kuyavia|18.5|52.7|POL
Chełmno Land|18.7|53.2|POL
Pomerelia|18.2|53.9|POL
Royal Prussia|19.8|54.1|POL
Lesser Poland|20.3|50.2|POL
Masovia|21.0|52.4|POL
Podlachia|22.8|52.8|POL
Sandomierz|21.7|50.7|POL
Lublin Land|22.8|51.2|POL
Red Ruthenia|24.0|49.8|POL
Podolia|26.7|49.0|POL
Prussia|21.0|54.3|TEU
Nadruvia|21.3|54.7|TEU
Samland|20.4|54.9|TEU
Masuria|21.6|53.7|TEU
Samogitia|22.8|55.7|LIT
Lithuania|24.6|54.9|LIT
Black Ruthenia|25.7|53.4|LIT
Polesia|27.5|52.0|LIT
Volhynia|25.5|51.0|LIT
White Ruthenia|29.5|54.0|LIT
Vitebsk|30.0|55.3|LIT
Smolensk|32.0|54.8|LIT
Kiev Land|30.7|50.4|LIT
Chernihiv|31.5|51.5|LIT
Severia|34.0|52.0|LIT
Livonia|25.0|57.0|LIV
Estonia|25.3|58.8|LIV
Courland|22.5|56.8|LIV
Semigallia|23.5|56.4|LIV
Wild Fields|33.5|48.2|HOR
Zaporozhia|35.0|47.5|HOR
Crimea|34.5|45.0|CRI
Budjak|30.0|45.7|MOL
Bessarabia|29.0|46.8|MOL
Don Steppe|40.5|48.0|HOR
Kuban|38.5|45.2|HOR
Volga Steppe|45.5|50.0|HOR
Circassia|40.2|44.2|
Dagestan|46.3|43.0|
Muscovy|37.6|55.8|MOS
Novgorod Land|32.0|58.5|MOS
Pskov|28.3|57.8|MOS
Tver|35.9|56.9|MOS
Yaroslavl|39.9|57.6|MOS
Vladimir-Suzdal|40.4|56.1|MOS
Ryazan|39.7|54.6|MOS
Meshchera|41.5|55.0|MOS
Mordovia|44.0|54.2|
Nizhny Novgorod Land|44.0|56.3|MOS
Kazan Khanate|47.0|56.0|
Kostroma|41.5|58.0|MOS
Vyatka|46.0|58.5|
Tula|37.0|53.9|MOS
Beloozero|37.8|60.0|MOS
Vologda|40.0|59.2|MOS
Onega|38.0|62.0|MOS
Kargopol|38.8|61.2|MOS
Vytegra|36.0|61.2|MOS
Sarpa Steppe|44.5|48.0|HOR
Manych Steppe|43.0|46.0|HOR
Khoper Steppe|42.0|51.5|HOR
Donets Steppe|38.0|49.3|HOR
Saratov Steppe|46.0|51.6|HOR
Volga Delta|46.3|46.5|HOR
Terek Steppe|45.0|43.8|
Kalmyk Steppe|44.5|45.5|HOR
Ingria|30.5|59.6|MOS
Seversk Steppe|37.0|51.0|MOS
Transdanubia|17.8|47.0|HUN
Upper Hungary|19.0|48.8|HUN
Alföld|20.0|46.8|HUN
Transylvania|24.0|46.2|HUN
Banat|21.2|45.6|HUN
Slavonia|18.0|45.4|HUN
Croatia|15.9|45.4|HUN
Carpathian Ruthenia|23.3|48.4|HUN
Dalmatia|16.0|43.7|VEN
Ragusa|18.1|42.65|
Bosnia|17.9|44.1|TUR
Herzegovina|18.2|43.2|TUR
Serbia|21.0|43.8|TUR
Kosovo|21.0|42.6|TUR
Zeta|19.2|42.5|VEN
Albania|20.0|41.0|TUR
Epirus|20.8|39.6|TUR
Thessaly|22.2|39.6|TUR
Macedonia|22.0|41.0|TUR
Thrace|26.5|41.3|TUR
Bulgaria|25.0|43.0|TUR
Dobruja|28.4|44.3|TUR
Wallachia|25.0|44.6|WAL
Oltenia|23.7|44.5|WAL
Moldavia|27.0|47.0|MOL
Bukovina|25.8|47.8|MOL
Morea|22.1|37.5|TUR
Boeotia|23.3|38.4|TUR
Attica|23.7|38.0|TUR
Negroponte|23.8|38.5|VEN
Ionian Islands|20.5|38.5|VEN
Aegean Islands|25.5|37.5|VEN
Rhodes|28.0|36.2|
Crete|25.0|35.2|VEN
Cyprus|33.2|35.0|VEN
Bithynia|30.0|40.3|TUR
Ionia|27.8|38.2|TUR
Phrygia|30.5|39.0|TUR
Caria|28.3|37.2|TUR
Lycia|30.0|36.8|TUR
Karaman|32.5|37.4|TUR
Galatia|32.5|39.8|TUR
Paphlagonia|33.5|41.2|TUR
Pontus|37.5|40.8|TUR
Cappadocia|34.8|38.5|TUR
Rum|37.0|39.7|
Cilicia|35.0|36.9|MAM
Dulkadir|37.0|37.8|MAM
Upper Armenia|41.0|40.0|AKK
Armenia|44.0|40.0|AKK
Karabakh|46.4|39.9|AKK
Azerbaijan|46.0|38.0|AKK
Diyar Bakr|40.2|37.9|AKK
Jazira|41.0|36.8|AKK
Kurdistan|43.5|37.5|AKK
Iraq|44.3|33.3|AKK
Kartli|44.3|41.9|GEO
Imereti|42.8|42.2|GEO
Samegrelo|41.8|42.6|GEO
Northern Syria|37.0|36.2|MAM
Syria|36.3|33.5|MAM
Lebanon|35.7|34.0|MAM
Palestine|35.0|31.8|MAM
Transjordan|36.0|30.8|MAM
Hejaz|39.5|22.5|MAM
Midian|36.0|27.5|MAM
Tihama|42.0|17.0|MAM
Asir|43.0|19.0|
Najran|44.5|17.8|
Yemen|44.0|14.8|
Hadhramaut|46.0|15.5|
Sinai|33.8|29.0|MAM
Lower Egypt|31.2|30.5|MAM
Middle Egypt|30.9|28.0|MAM
Upper Egypt|32.7|25.5|MAM
Western Desert|28.0|28.0|
Cyrenaica|21.5|32.2|TUN
Tripolitania|13.5|32.5|TUN
Ifriqiya|10.0|35.8|TUN
Djerid|8.5|33.8|TUN
Constantine|6.6|36.4|TUN
Bejaia|5.1|36.6|TUN
Kabylia|4.2|36.7|
Tlemcen|-1.3|34.9|TLE
Oran|-0.6|35.7|TLE
Titteri|3.0|36.2|TLE
Fez|-5.0|34.0|MOR
Rif|-4.0|35.0|MOR
Tingitana|-5.8|35.7|MOR
Haouz|-8.0|31.6|MOR
Souss|-9.0|30.0|MOR
Tafilalt|-4.4|31.3|MOR
Middle Atlas|-5.5|32.8|MOR
"""

# The native peoples' lands: the Americas and Africa south of the Sahara's northern edge.
_NATIVE = """
Inuit lands|-62.0|58.5|
Innu lands|-64.0|52.0|
Naskapi lands|-67.0|55.5|
Cree lands|-84.0|51.0|
Eastern Cree lands|-77.0|52.5|
Swampy Cree lands|-93.0|53.0|
Assiniboine lands|-100.0|50.5|
Dakota lands|-97.0|45.0|
Ojibwe lands|-90.0|47.0|
Odawa lands|-85.0|45.5|
Menominee lands|-88.5|45.0|
Ho-Chunk lands|-89.0|43.5|
Illinois lands|-89.0|40.0|
Miami lands|-85.5|40.8|
Potawatomi lands|-86.0|42.0|
Shawnee lands|-84.0|39.0|
Erie lands|-81.0|41.5|
Huron lands|-80.0|45.0|
Neutral lands|-79.5|43.0|
Iroquois lands|-76.0|43.0|
Susquehannock lands|-77.0|41.0|
Lenape lands|-75.0|40.0|
Abenaki lands|-71.5|44.5|
Massachusett lands|-71.0|42.3|
Narragansett lands|-71.5|41.5|
Maliseet lands|-67.0|46.5|
Mi'kmaq lands|-64.0|46.0|
Beothuk lands|-56.0|49.0|
Powhatan lands|-77.0|37.5|
Tuscarora lands|-77.5|35.3|
Catawba lands|-81.0|34.8|
Cherokee lands|-84.0|35.5|
Yamasee lands|-81.5|32.0|
Muscogee lands|-85.5|32.5|
Apalachee lands|-84.0|30.5|
Timucua lands|-82.0|29.0|
Calusa lands|-81.5|26.5|
Choctaw lands|-89.0|33.0|
Chickasaw lands|-89.8|35.2|
Natchez lands|-91.0|31.5|
Caddo lands|-95.0|32.0|
Atakapa lands|-93.0|30.0|
Osage lands|-94.0|37.5|
Pawnee lands|-98.0|41.0|
Comanche lands|-99.0|31.0|
Chichimec lands|-100.0|25.0|
Huastec lands|-98.5|22.5|
Totonac lands|-97.5|20.3|
Mexica lands|-99.0|19.5|
Mixtec lands|-97.5|17.2|
Zapotec lands|-96.3|16.9|
Maya lands|-89.0|18.0|
Yucatec Maya lands|-88.8|20.6|
Highland Maya lands|-91.0|15.0|
Chorotega lands|-85.5|11.5|
Miskito lands|-84.0|13.0|
Talamanca lands|-82.8|9.5|
Cueva lands|-79.0|8.8|
Muisca lands|-74.0|5.0|
Tairona lands|-73.8|11.0|
Sinú lands|-76.0|9.0|
Quimbaya lands|-75.8|4.7|
Lucayan lands|-76.0|24.0|
Cubanacán lands|-79.0|22.0|
Taíno lands|-72.5|19.0|
Xaymaca lands|-77.3|18.1|
Borikén lands|-66.5|18.2|
Carib lands|-61.5|14.0|
Kalinago lands|-66.0|9.5|
Caquetío lands|-69.8|11.3|
Arawak lands|-60.0|6.0|
Galibi lands|-54.0|4.5|
Amazon lands|-60.0|-5.0|
Manao lands|-62.0|-3.5|
Tapajó lands|-55.0|-3.0|
Omagua lands|-72.0|-4.0|
Jivaro lands|-77.5|-3.0|
Quitu lands|-78.5|-1.0|
Pasto lands|-77.5|1.0|
Chachapoya lands|-77.8|-6.0|
Chimú lands|-79.0|-8.0|
Quechua lands|-74.0|-10.0|
Tupinambá lands|-45.0|-3.0|
Potiguar lands|-35.8|-5.5|
Tupi lands|-38.0|-8.0|
Caeté lands|-36.0|-9.5|
Tupiniquim lands|-39.5|-12.5|
Wolof lands|-16.0|15.0|
Sanhaja lands|-10.0|21.0|
Mandinka lands|-12.0|11.0|
Mali lands|-8.0|12.5|
Songhai lands|-2.0|15.5|
Mossi lands|-1.5|12.0|
Gonja lands|-1.0|9.0|
Akan lands|-1.5|6.5|
Kru lands|-8.0|5.5|
Yoruba lands|4.0|8.0|
Nupe lands|5.5|9.5|
Benin lands|5.6|6.5|
Igbo lands|7.5|6.0|
Jukun lands|10.0|8.0|
Hausa lands|8.5|12.0|
Aïr lands|8.5|18.0|
Tuareg lands|4.0|23.0|
Tebu lands|17.0|21.5|
Kanem lands|15.0|13.0|
Zaghawa lands|24.0|15.0|
Fang lands|11.0|1.0|
Loango lands|12.0|-4.3|
Kongo lands|14.5|-5.5|
Kuba lands|21.0|-5.0|
Ndongo lands|15.5|-9.5|
Lunda lands|22.0|-10.0|
Luba lands|25.0|-8.0|
Bantu lands|25.0|0.0|
Great Lakes lands|30.5|-1.0|
Alodia lands|33.0|14.0|
Nubian lands|33.0|18.5|
Abyssinian lands|38.5|11.0|
Somali lands|45.0|6.0|
Swahili lands|39.0|-5.0|
Makua lands|38.0|-12.0|
Bedouin lands|42.0|25.0|
Guanche lands|-15.5|28.3|
Ungava Inuit lands|-73.0|60.5|
Atikamekw lands|-74.0|48.0|
Algonquin lands|-77.5|46.0|
Moose Cree lands|-83.0|53.5|
Severn Cree lands|-88.0|56.5|
Western Cree lands|-98.0|57.0|
Chipewyan lands|-99.0|60.5|
Saulteaux lands|-96.5|50.0|
Maasai lands|36.5|-2.5|
Gikuyu lands|37.0|-0.5|
Nyamwezi lands|33.0|-5.0|
Gogo lands|36.0|-6.8|
Oromo lands|39.5|5.0|
Ogaden lands|44.0|7.8|
Afar lands|41.0|12.0|
Tigray lands|39.0|13.5|
Shewa lands|39.5|9.0|
Gojjam lands|37.5|11.0|
Sidama lands|38.0|6.5|
Fezzan lands|13.5|26.0|
Kufra lands|23.0|24.0|
Adrar lands|-8.0|20.5|
Azawad lands|-2.0|19.0|
Tenere lands|10.0|16.5|
Bilma lands|14.0|19.0|
Wadai lands|20.5|13.0|
Libyan Desert lands|27.0|23.0|
Eastern Desert lands|34.5|24.0|
Mongo lands|22.0|-1.5|
Teke lands|16.0|-2.0|
Azande lands|27.0|4.0|
Bemba lands|30.0|-11.0|
Chokwe lands|21.5|-10.0|
Xingu lands|-52.0|-11.0|
Ge lands|-46.5|-10.0|
Juruá lands|-68.0|-7.0|
Madeira lands|-62.0|-9.0|
Mojos lands|-65.0|-12.5|
Napo lands|-75.0|-1.5|
Yanomami lands|-64.0|2.0|
Rio Negro lands|-67.0|0.0|
Orinoco lands|-67.0|6.5|
Macushi lands|-60.5|3.5|
Guajajara lands|-47.5|-5.0|
Torngat lands|-64.0|59.8|
Ungava Bay lands|-68.0|59.0|
Hudson Strait lands|-73.0|62.0|
Labrador lands|-60.0|54.5|
Mistassini lands|-72.0|51.0|
Caniapiscau lands|-70.0|56.5|
Saguenay lands|-71.0|49.0|
Churchill River lands|-62.0|53.5|
Michikamau lands|-65.0|54.0|
James Bay lands|-79.0|53.5|
Eastmain lands|-76.0|53.0|
Great Whale lands|-76.0|55.8|
Winisk lands|-87.0|54.5|
Attawapiskat lands|-83.0|52.5|
Lac Seul lands|-91.0|50.5|
Red Lake lands|-94.5|48.5|
Island Lake lands|-94.0|53.5|
Cumberland lands|-99.0|54.0|
Oxford lands|-95.0|54.8|
Reindeer Lake lands|-99.5|57.8|
Churchill lands|-94.0|58.8|
Seal River lands|-98.0|60.0|
Hoggar lands|6.0|23.5|
Tanezrouft lands|1.0|24.5|
Ajjer lands|9.0|25.5|
Tademait lands|2.0|28.0|
Tagant lands|-11.0|18.0|
Hodh lands|-8.0|17.0|
Zemmour lands|-12.0|24.0|
Draa lands|-8.0|28.0|
Erg Iguidi lands|-6.0|26.5|
Ghat lands|10.5|25.0|
Awbari lands|12.5|26.5|
Sirtica lands|18.0|30.0|
Jufra lands|16.0|28.0|
Zaramo lands|38.5|-7.5|
Rufiji lands|37.5|-8.8|
Ruvuma lands|37.0|-10.8|
Yao lands|36.0|-12.5|
Pokomo lands|40.0|-2.0|
Mijikenda lands|39.3|-3.5|
Usambara lands|38.3|-4.8|
Kilimanjaro lands|37.3|-3.2|
Tana lands|39.5|-1.0|
Turkana lands|35.5|3.2|
Pokot lands|35.5|1.5|
Karamojong lands|34.3|2.8|
Mangbetu lands|28.0|2.8|
Ubangi lands|22.0|4.0|
Dar Runga lands|21.0|10.0|
Dinka lands|28.5|7.5|
Nuer lands|31.0|8.5|
Shilluk lands|31.5|10.5|
Bahr el Ghazal lands|26.0|8.5|
Batha lands|18.0|13.5|
Bahr Salamat lands|19.5|10.5|
Ennedi lands|23.0|17.5|
Chari lands|16.5|11.0|
Borkou lands|17.5|17.5|
Darfur lands|25.5|13.0|
Kordofan lands|30.0|12.5|
Nuba lands|30.5|11.0|
Butana lands|34.5|16.0|
Atbara lands|33.5|17.8|
Jaghbub lands|24.5|29.5|
Dakhla lands|29.0|25.5|
Tocantins lands|-49.0|-6.0|
Araguaia lands|-50.0|-10.0|
Iriri lands|-54.0|-7.0|
Jamanxim lands|-56.0|-6.5|
Teles Pires lands|-56.0|-10.5|
Trombetas lands|-57.0|-1.0|
Jari lands|-53.0|0.5|
Marajó lands|-50.0|-1.0|
Gurupi lands|-46.0|-3.5|
Purus lands|-65.0|-8.5|
Guaporé lands|-62.5|-12.0|
"""


def _parse(text):
    out = []
    for line in text.strip().splitlines():
        name, lon, lat, tag = line.split("|")
        out.append((name, float(lon), float(lat), tag or None))
    return out


OLD_WORLD = _parse(_OLD_WORLD)
NATIVE = _parse(_NATIVE)
REGIONS = OLD_WORLD + NATIVE          # (name, lon, lat, tag or None)


# The region of each geo city's hex, and so of the country around it (each city is also an anchor of its region).
CITY_REGION = {
    "Lisbon": "Estremadura", "Porto": "Douro", "Seville": "Seville", "Toledo": "New Castile", "Burgos": "Old Castile",
    "Valladolid": "Old Castile", "Granada": "Granada", "Barcelona": "Catalonia", "Valencia": "Valencia",
    "Zaragoza": "Aragon", "Paris": "Île-de-France", "Lyon": "Lyonnais", "Bordeaux": "Guyenne",
    "Toulouse": "Languedoc", "Rouen": "Normandy", "Marseille": "Provence", "Rennes": "Brittany", "Nantes": "Brittany",
    "Dijon": "Burgundy", "London": "Middlesex", "York": "North Riding", "Bristol": "Gloucestershire",
    "Edinburgh": "Lothian", "Dublin": "The Pale", "Galway": "Connacht", "Antwerp": "Brabant", "Bruges": "Flanders",
    "Ghent": "Flanders", "Amsterdam": "Holland", "Brussels": "Brabant", "Cologne": "Electorate of Cologne",
    "Frankfurt": "Wetterau", "Nuremberg": "Franconia", "Augsburg": "Swabia", "Munich": "Upper Bavaria",
    "Vienna": "Lower Austria", "Prague": "Bohemia", "Dresden": "Meissen", "Berlin": "Mittelmark", "Lübeck": "Holstein",
    "Hamburg": "Holstein", "Bremen": "Oldenburg", "Copenhagen": "Zealand", "Bergen": "Hordaland", "Oslo": "Viken",
    "Stockholm": "Uppland", "Danzig": "Pomerelia", "Königsberg": "Samland", "Riga": "Livonia", "Kraków": "Lesser Poland",
    "Poznań": "Greater Poland", "Vilnius": "Lithuania", "Kiev": "Kiev Land", "Moscow": "Muscovy",
    "Novgorod": "Novgorod Land", "Buda": "Transdanubia", "Zagreb": "Croatia", "Venice": "Veneto", "Milan": "Lombardy",
    "Genoa": "Liguria", "Florence": "Tuscany", "Rome": "Lazio", "Bologna": "Emilia", "Naples": "Campania",
    "Palermo": "Val di Mazara", "Turin": "Piedmont", "Bern": "Swiss Plateau", "Constantinople": "Thrace",
    "Edirne": "Thrace", "Thessaloniki": "Macedonia", "Athens": "Attica", "Bursa": "Bithynia", "Ankara": "Galatia",
    "Belgrade": "Serbia", "Sofia": "Bulgaria", "Trebizond": "Pontus", "Suceava": "Bukovina", "Kaffa": "Crimea",
    "Tbilisi": "Kartli", "Diyarbakır": "Diyar Bakr", "Cairo": "Lower Egypt", "Alexandria": "Lower Egypt",
    "Damascus": "Syria", "Aleppo": "Northern Syria", "Jerusalem": "Palestine", "Tunis": "Ifriqiya",
    "Tripoli": "Tripolitania", "Algiers": "Titteri", "Tlemcen": "Tlemcen", "Fez": "Fez", "Marrakesh": "Haouz",
    "Timbuktu": "Songhai lands", "Benin": "Benin lands", "Tenochtitlan": "Mexica lands", "Cusco": "Quechua lands",
    "Candia": "Crete", "Mecca": "Hejaz", "Medina": "Hejaz", "Baghdad": "Iraq", "Mosul": "Jazira", "Smyrna": "Ionia",
    "Konya": "Karaman",
}

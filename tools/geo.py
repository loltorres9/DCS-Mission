import math
# Transverse Mercator (WGS84) mit den Caucasus-Parametern aus pydcs
A = 6378137.0; F = 1/298.257223563
E2 = F*(2-F); EP2 = E2/(1-E2)
K0 = 0.9996; LON0 = math.radians(33.0)
FE = -99516.9999999732; FN = -4998114.999999984

def ll_to_dcs(lat, lon):
    phi = math.radians(lat); lam = math.radians(lon)
    N = A/math.sqrt(1-E2*math.sin(phi)**2)
    T = math.tan(phi)**2; C = EP2*math.cos(phi)**2
    Aa = (lam-LON0)*math.cos(phi)
    M = A*((1-E2/4-3*E2**2/64-5*E2**3/256)*phi - (3*E2/8+3*E2**2/32+45*E2**3/1024)*math.sin(2*phi)
           + (15*E2**2/256+45*E2**3/1024)*math.sin(4*phi) - (35*E2**3/3072)*math.sin(6*phi))
    east = K0*N*(Aa+(1-T+C)*Aa**3/6+(5-18*T+T*T+72*C-58*EP2)*Aa**5/120)
    north = K0*(M+N*math.tan(phi)*(Aa*Aa/2+(5-T+9*C+4*C*C)*Aa**4/24+(61-58*T+T*T+600*C-330*EP2)*Aa**6/720))
    return north+FN, east+FE   # DCS: x = Nord, y = Ost

AIRFIELDS = {
 12:("Anapa-Vityazevo",45.0130,37.3473), 13:("Krasnodar-Center",45.0869,38.9256),
 14:("Novorossiysk",44.6731,37.7869), 15:("Krymsk",44.9614,37.9856),
 16:("Maykop-Khanskaya",44.6714,40.0214), 17:("Gelendzhik",44.5672,38.0044),
 18:("Sochi-Adler",43.4441,39.9467), 19:("Krasnodar-Pashkovsky",45.0347,39.1700),
 20:("Sukhumi-Babushara",42.8581,41.1281), 21:("Gudauta",43.1036,40.5794),
 22:("Batumi",41.6103,41.5997), 23:("Senaki-Kolkhi",42.2386,42.0611),
 24:("Kobuleti",41.9294,41.8669), 25:("Kutaisi",42.1764,42.4825),
 26:("Mineralnye Vody",44.2253,43.0819), 27:("Nalchik",43.5131,43.6367),
 28:("Mozdok",43.7914,44.6200), 29:("Tbilisi-Lochini",41.6697,44.9547),
 30:("Soganlug",41.6436,44.9447), 31:("Vaziani",41.6292,45.0275),
 32:("Beslan",43.2086,44.5886),
}
# Syria: Flugplätze (ohne Hubschrauber-Landeplätze) mit DCS-x/y, ausgelesen per F10 DEBUG "Write airfield list to dcs.log" (DCS 2026-10)
SYRIA_AIRFIELDS = {
      1: ('Abu al-Duhur', 75930, 112670),
      2: ('Adana Sakirpasa', 220150, -47276),
      3: ('Al Qusayr', -52204, 61288),
      4: ('An Nasiriyah', -123819, 86408),
      5: ("Tha'lah", -259061, 39318),
      6: ('Beirut-Rafic Hariri', -132953, -42477),
      7: ('Damascus', -179748, 50728),
      8: ('Marj as Sultan South', -171681, 48153),
      9: ('Al-Dumayr', -158140, 75309),
     10: ('Eyn Shemer', -283373, -93393),
     11: ('Gaziantep', 210761, 145931),
     12: ('H4', -279644, 208278),
     13: ('Haifa', -243103, -87584),
     14: ('Hama', 8420, 75522),
     15: ('Hatay', 148654, 40404),
     16: ('Incirlik', 220388, -36464),
     17: ('Jirah', 115648, 185665),
     18: ('Khalkhalah', -216085, 52697),
     19: ('King Hussein Air College', -297492, 25897),
     20: ('Kiryat Shmona', -199858, -34832),
     21: ('Bassel Al-Assad', 43238, 5841),
     22: ('Marj as Sultan North', -170226, 47430),
     23: ('Marj Ruhayyil', -194159, 44795),
     24: ('Megiddo', -266880, -71995),
     25: ('Mezzeh', -171642, 25889),
     26: ('Minakh', 163871, 106743),
     27: ('Aleppo', 125377, 124380),
     28: ('Palmyra', -55602, 221508),
     29: ('Qabr as Sitt', -174612, 37141),
     30: ('Ramat David', -260106, -74491),
     31: ('Kuweires', 126034, 154263),
     32: ('Rayak', -131016, 3065),
     33: ('Rene Mouawad', -48864, 7502),
     34: ('Rosh Pina', -225657, -37521),
     35: ('Sayqal', -151737, 116321),
     36: ('Shayrat', -60851, 89478),
     37: ('Tabqa', 77070, 242232),
     38: ('Taftanaz', 103379, 83166),
     39: ('Tiyas', -58877, 155636),
     40: ('Wujah Al Hajar', -80912, -22454),
     41: ('Gazipasa', 158095, -320441),
     42: ('Deir ez-Zor', 25960, 388412),
     43: ('Nicosia', 24126, -238342),
     44: ('Akrotiri', -35297, -270072),
     45: ('Kingsfield', 7776, -198993),
     46: ('Paphos', -18147, -315370),
     47: ('Larnaca', -8466, -209773),
     48: ('Lakatamia', 19751, -234974),
     49: ('Ercan', 24209, -218571),
     50: ('Gecitkale', 32255, -199006),
     51: ('Pinarbashi', 39147, -238857),
     52: ('Naqoura', -209938, -78643),
     53: ('H3', -234882, 351282),
     54: ('H3 Northwest', -220616, 339425),
     55: ('H3 Southwest', -257447, 340150),
     56: ('Zarqa', -332705, 12185),
     57: ('Ruwayshid', -294673, 296175),
     58: ('Sanliurfa', 266092, 275094),
     59: ('Kharab Ishk', 164820, 245880),
     60: ('Tal Siman', 133309, 275979),
     61: ('H4 Emergency', -295923, 167588),
     62: ('Nevatim', -420022, -95606),
     63: ('At Tanf', -172365, 247032),
     64: ('Prince Hassan', -319145, 107257),
     65: ('King Abdullah II', -336187, 21316),
     66: ('Herzliya', -312199, -109136),
     67: ('Marka', -337872, -25),
     68: ('Muwaffaq Salti', -357348, 73697),
     75: ('Kahramanmaras', 276902, 102781),
     81: ('Hatzerim', -415315, -131889),
     88: ('Kedem', -412945, -133127),
     90: ('Chukurova', 211731, -66528),
     91: ('Teyman', -410937, -124185),
    216: ('Gulechoba', 327048, 366450),
    217: ('Diyarbakir', 313127, 388712),
    218: ('Konya', 341730, -283489),
    219: ('Adiyaman', 295660, 235244),
    220: ('Tel Nof', -350749, -111207),
    221: ('Ben Gurion', -330594, -107307),
    222: ('Hatzor', -357424, -121212),
    223: ('Palmachim', -342960, -125050),
    225: ('T2', -74246, 389224),
    226: ('T3', -59252, 258868),
}

# Syria: freundliche Plätze (kein Ziel), wie D.cfg.maps.Syria im Skript: Türkei, Zypern, Jordanien
SYRIA_FRIENDLY = {16, 2, 90, 15, 11, 75, 58, 219, 216, 217, 218, 41,      # Türkei
                  43, 44, 45, 46, 47, 48, 49, 50, 51,                    # Zypern
                  19, 56, 57, 12, 61, 64, 65, 67, 68}                    # Jordanien

if __name__ == "__main__":
    x,y = ll_to_dcs(42.2386,42.0611)
    print("Senaki berechnet: x=%.0f y=%.0f" % (x,y))
    print("Senaki Vorlage:   x=-281394 y=647267")
    print("Abweichung: %.0f m" % math.hypot(x+281393.65625, y-647266.5))

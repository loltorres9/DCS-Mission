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
if __name__ == "__main__":
    x,y = ll_to_dcs(42.2386,42.0611)
    print("Senaki berechnet: x=%.0f y=%.0f" % (x,y))
    print("Senaki Vorlage:   x=-281394 y=647267")
    print("Abweichung: %.0f m" % math.hypot(x+281393.65625, y-647266.5))

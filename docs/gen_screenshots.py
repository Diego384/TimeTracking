from PIL import Image, ImageDraw, ImageFont
import math

W, H = 1080, 1920

BLUE = (25, 118, 210)
BLUE_DARK = (13, 71, 161)
BLUE_LIGHT = (227, 242, 253)
WHITE = (255, 255, 255)
GREY = (245, 245, 245)
GREY2 = (224, 224, 224)
TEXT = (33, 33, 33)
TEXT2 = (117, 117, 117)
GREEN = (76, 175, 80)
ORANGE = (255, 152, 0)

def load_fonts():
    try:
        return {
            'bold': ImageFont.truetype("C:/Windows/Fonts/Arialbd.ttf", 48),
            'bold_lg': ImageFont.truetype("C:/Windows/Fonts/Arialbd.ttf", 60),
            'bold_xl': ImageFont.truetype("C:/Windows/Fonts/Arialbd.ttf", 72),
            'regular': ImageFont.truetype("C:/Windows/Fonts/Arial.ttf", 38),
            'small': ImageFont.truetype("C:/Windows/Fonts/Arial.ttf", 30),
            'tiny': ImageFont.truetype("C:/Windows/Fonts/Arial.ttf", 26),
            'title': ImageFont.truetype("C:/Windows/Fonts/Arialbd.ttf", 52),
        }
    except:
        f = ImageFont.load_default()
        return {k: f for k in ['bold','bold_lg','bold_xl','regular','small','tiny','title']}

def base_img():
    img = Image.new('RGB', (W, H), WHITE)
    return img, ImageDraw.Draw(img)

def draw_statusbar(draw, fonts):
    draw.rectangle([0, 0, W, 80], fill=BLUE_DARK)
    draw.text((40, 22), "9:41", fill=WHITE, font=fonts['small'])
    draw.rectangle([W-50, 28, W-20, 52], outline=WHITE, width=2)
    draw.rectangle([W-47, 31, W-32, 49], fill=WHITE)
    draw.rectangle([W-20, 35, W-16, 45], fill=WHITE)

def draw_appbar(draw, title, fonts, subtitle=None):
    height = 210 if subtitle else 180
    draw.rectangle([0, 80, W, height], fill=BLUE)
    draw.text((50, 100), title, fill=WHITE, font=fonts['bold_lg'])
    if subtitle:
        draw.text((50, 162), subtitle, fill=(200, 230, 255), font=fonts['small'])
    return height

def draw_card(draw, x, y, w, h, radius=20):
    draw.rounded_rectangle([x+4, y+4, x+w+4, y+h+4], radius=radius, fill=(210,210,210))
    draw.rounded_rectangle([x, y, x+w, y+h], radius=radius, fill=WHITE)

fonts = load_fonts()

# ── SCREENSHOT 1: Calendar ──
img, draw = base_img()
draw.rectangle([0, 0, W, H], fill=GREY)
draw_statusbar(draw, fonts)
appbar_h = draw_appbar(draw, "Time Tracking", fonts, "Mario Rossi  |  Marzo 2026")

draw.rectangle([0, appbar_h, W, appbar_h+80], fill=WHITE)
days = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom']
col_w = W // 7
for i, d in enumerate(days):
    color = (220, 50, 50) if i == 6 else TEXT2
    draw.text((i*col_w + col_w//2 - 18, appbar_h+22), d, fill=color, font=fonts['tiny'])

draw.line([0, appbar_h+80, W, appbar_h+80], fill=GREY2, width=2)

weeks = [
    [None,None,None,None,None,1,2],
    [3,4,5,6,7,8,9],
    [10,11,12,13,14,15,16],
    [17,18,19,20,21,22,23],
    [24,25,26,27,28,29,30],
    [31,None,None,None,None,None,None],
]
for wi, week in enumerate(weeks):
    for di, day in enumerate(week):
        if day is None:
            continue
        cx = di*col_w + col_w//2
        cy = appbar_h+80 + wi*100 + 38
        if day == 27:
            draw.ellipse([cx-34, cy-34, cx+34, cy+34], fill=BLUE)
            draw.text((cx-18, cy-22), str(day), fill=WHITE, font=fonts['bold'])
        else:
            col = (220,50,50) if di == 6 else TEXT
            draw.text((cx-(18 if day >= 10 else 10), cy-22), str(day), fill=col, font=fonts['regular'])
        if day and 3 <= day <= 26 and di < 5:
            draw.ellipse([cx-6, cy+22, cx+6, cy+34], fill=BLUE)

sep_y = appbar_h + 80 + 6*100 + 20
draw.line([0, sep_y, W, sep_y], fill=GREY2, width=2)

draw.rectangle([0, sep_y, W, sep_y+60], fill=WHITE)
draw.text((50, sep_y+14), "Oggi  27 Marzo 2026", fill=TEXT2, font=fonts['small'])

entries = [
    ("Assistenza domiciliare", "8:00 - 12:00", "4.0h", "Trento"),
    ("Supporto educativo",     "14:00 - 17:00","3.0h", "Lavis"),
    ("Attivita ricreativa",    "18:00 - 20:00","2.0h", "Trento"),
]
y = sep_y + 70
for name, time, hours, place in entries:
    draw_card(draw, 30, y, W-60, 130)
    draw.rounded_rectangle([30, y, 44, y+130], radius=8, fill=BLUE)
    draw.text((80, y+14), name, fill=TEXT, font=fonts['bold'])
    draw.text((80, y+68), time + "   " + place, fill=TEXT2, font=fonts['small'])
    draw.rounded_rectangle([W-160, y+40, W-50, y+92], radius=20, fill=BLUE_LIGHT)
    draw.text((W-148, y+48), hours, fill=BLUE, font=fonts['bold'])
    y += 150

draw.rectangle([0, H-130, W, H], fill=WHITE)
draw.line([0, H-130, W, H-130], fill=GREY2, width=1)

img.save(r'C:\Users\diego\Documents\GitHub\TimeTracking\docs\screenshot1.png')
print("Screenshot 1 done")

# ── SCREENSHOT 2: Weekly Grid ──
img, draw = base_img()
draw.rectangle([0, 0, W, H], fill=GREY)
draw_statusbar(draw, fonts)
appbar_h = draw_appbar(draw, "Griglia Oraria", fonts, "Settimana 24-29 Marzo 2026")

day_data = [
    ("Lunedi 24",    [("08:00","13:00","5h","M. Bianchi","Ass. Dom."),("14:00","17:00","3h","L. Verdi","Supporto")]),
    ("Martedi 25",   [("09:00","12:00","3h","A. Neri","Educativo")]),
    ("Mercoledi 26", [("08:00","14:00","6h","M. Bianchi","Ass. Dom.")]),
    ("Giovedi 27",   [("10:00","13:00","3h","L. Verdi","Supporto"),("15:00","18:00","3h","A. Neri","Educativo")]),
    ("Venerdi 28",   [("08:00","12:00","4h","M. Bianchi","Ass. Dom.")]),
    ("Sabato 29",    []),
]

y = appbar_h + 20
for day, entries in day_data:
    has = len(entries) > 0
    hcolor = BLUE if has else (158, 158, 158)
    draw.rounded_rectangle([20, y, W-20, y+62], radius=12, fill=hcolor)
    total = sum(int(e[2][0]) for e in entries)
    draw.text((50, y+10), day, fill=WHITE, font=fonts['bold'])
    if total > 0:
        draw.text((W-160, y+10), str(total)+"h tot", fill=(200,230,255), font=fonts['small'])
    y += 62
    if entries:
        bg_h = len(entries) * 88 + 10
        draw.rectangle([20, y, W-20, y+bg_h], fill=WHITE)
        for e in entries:
            draw.text((40, y+8), e[0]+"-"+e[1], fill=BLUE, font=fonts['small'])
            draw.text((40, y+44), e[3]+"  |  "+e[4], fill=TEXT2, font=fonts['tiny'])
            draw.rounded_rectangle([W-130, y+8, W-35, y+52], radius=16, fill=BLUE_LIGHT)
            draw.text((W-118, y+14), e[2], fill=BLUE, font=fonts['bold'])
            y += 88
        y += 10
    y += 10

draw.rounded_rectangle([20, y, W-20, y+80], radius=16, fill=BLUE_DARK)
draw.text((50, y+16), "Totale settimana:", fill=WHITE, font=fonts['bold'])
draw.text((W-210, y+10), "24h", fill=(255,220,100), font=fonts['bold_xl'])

img.save(r'C:\Users\diego\Documents\GitHub\TimeTracking\docs\screenshot2.png')
print("Screenshot 2 done")

# ── SCREENSHOT 3: Documents ──
img, draw = base_img()
draw.rectangle([0, 0, W, H], fill=GREY)
draw_statusbar(draw, fonts)
appbar_h = draw_appbar(draw, "Documenti", fonts)

docs = [
    ("PDF", "Contratto_2026.pdf",    "245 KB", "15 Mar 2026", BLUE),
    ("IMG", "Foto_documento.jpg",    "1.2 MB",  "20 Mar 2026", GREEN),
    ("PDF", "Scheda_operatore.pdf",  "180 KB", "10 Mar 2026", BLUE),
    ("PDF", "Modulo_ferie.pdf",      "98 KB",  "5 Mar 2026",  BLUE),
    ("IMG", "Certificato_medico.jpg","890 KB", "1 Mar 2026",  GREEN),
    ("PDF", "Orari_febbraio.pdf",    "120 KB", "28 Feb 2026", BLUE),
]

y = appbar_h + 30
draw.text((50, y), str(len(docs)) + " documenti", fill=TEXT2, font=fonts['small'])
y += 55

for ftype, name, size, date, color in docs:
    draw_card(draw, 25, y, W-50, 120)
    draw.rounded_rectangle([50, y+28, 128, y+76], radius=10, fill=color)
    draw.text((58, y+36), ftype, fill=WHITE, font=fonts['small'])
    draw.text((155, y+20), name, fill=TEXT, font=fonts['bold'])
    draw.text((155, y+72), size + "   " + date, fill=TEXT2, font=fonts['small'])
    draw.text((W-95, y+30), "dl", fill=BLUE, font=fonts['bold'])
    y += 145

draw.ellipse([W-140, H-230, W-20, H-110], fill=BLUE)
draw.text((W-100, H-202), "+", fill=WHITE, font=fonts['bold_xl'])

img.save(r'C:\Users\diego\Documents\GitHub\TimeTracking\docs\screenshot3.png')
print("Screenshot 3 done")

# ── SCREENSHOT 4: Sync ──
img, draw = base_img()
draw.rectangle([0, 0, W, H], fill=GREY)
draw_statusbar(draw, fonts)
appbar_h = draw_appbar(draw, "Sincronizzazione", fonts, "Mario Rossi")

y = appbar_h + 30

draw_card(draw, 30, y, W-60, 160)
draw.ellipse([55, y+38, 125, y+108], fill=(232,245,233))
draw.text((68, y+42), "OK", fill=GREEN, font=fonts['bold'])
draw.text((155, y+30), "Connesso al server", fill=TEXT, font=fonts['bold'])
draw.text((155, y+88), "Ultima sync: oggi 12:34", fill=TEXT2, font=fonts['small'])
y += 185

draw.rounded_rectangle([30, y, W-30, y+100], radius=20, fill=BLUE)
draw.text((W//2 - 170, y+24), "Sincronizza ora", fill=WHITE, font=fonts['bold_lg'])
y += 130

draw.text((50, y), "Statistiche mese corrente", fill=TEXT2, font=fonts['small'])
y += 50

stats = [("Ore lavorate","87h",BLUE),("Giorni lav.","18",GREEN),("Servizi","6",ORANGE)]
card_w = (W - 80) // 3
for i, (label, value, color) in enumerate(stats):
    cx = 30 + i * (card_w + 10)
    draw_card(draw, cx, y, card_w, 160)
    draw.text((cx + card_w//2 - 35, y+20), value, fill=color, font=fonts['bold_xl'])
    draw.text((cx + card_w//2 - len(label)*7, y+105), label, fill=TEXT2, font=fonts['tiny'])
y += 185

draw.text((50, y), "Ultime sincronizzazioni", fill=TEXT2, font=fonts['small'])
y += 50

syncs = [
    ("Oggi 12:34",   "32 record sincronizzati"),
    ("Ieri 18:10",   "28 record sincronizzati"),
    ("25 Mar 09:22", "15 record sincronizzati"),
]
for time, desc in syncs:
    draw_card(draw, 30, y, W-60, 105)
    draw.ellipse([52, y+26, 82, y+56], fill=(232,245,233))
    draw.text((58, y+26), "ok", fill=GREEN, font=fonts['small'])
    draw.text((108, y+16), time, fill=TEXT, font=fonts['bold'])
    draw.text((108, y+62), desc, fill=TEXT2, font=fonts['small'])
    y += 120

img.save(r'C:\Users\diego\Documents\GitHub\TimeTracking\docs\screenshot4.png')
print("Screenshot 4 done")
print("All screenshots saved in docs/")

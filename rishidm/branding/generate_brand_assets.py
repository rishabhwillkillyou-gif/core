#!/usr/bin/env python3
"""Generate RishiDM Windows and Chromium branding using only Pillow.
No external binary assets, bundled fonts, API requests, or runtime downloads.
The SVG in this folder is the editable source for the visual concept.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def mix(a, b, f):
    return tuple(round(a[i] * (1 - f) + b[i] * f) for i in range(3))


def cubic(a, b, c, d, steps=24):
    return [tuple((1-t)**3*a[i] + 3*(1-t)**2*t*b[i] +
                  3*(1-t)*t*t*c[i] + t**3*d[i] for i in range(2))
            for t in (j/steps for j in range(steps+1))]


def scale(points, s):
    return [(round(x*s), round(y*s)) for x, y in points]


def gradient(size, top, bottom, direction='diagonal'):
    px = []
    for y in range(size):
        for x in range(size):
            f = (x + y)/(2*size) if direction == 'diagonal' else y/size
            px.append((*mix(top, bottom, min(1, f)), 255))
    im = Image.new('RGBA', (size, size))
    im.putdata(px)
    return im


def brand_icon(size=512):
    s = size/512
    image = Image.new('RGBA', (size, size), (0,0,0,0))
    bounds = tuple(round(z*s) for z in (24,23,488,487))
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(bounds, radius=round(102*s), fill=255)
    background = gradient(size, (38,51,101), (16,17,34))
    image.paste(background, (0,0), mask)
    edge = ImageDraw.Draw(image)
    edge.rounded_rectangle(bounds, radius=round(102*s),
                           outline=(126,90,221,220), width=max(1,round(4*s)))
    # Gentle speed accents—kept clear of the central R at 16 px.
    edge.arc(tuple(round(z*s) for z in (46,56,336,332)),
             211, 259, fill=(84,169,245,140), width=max(1,round(10*s)))
    edge.arc(tuple(round(z*s) for z in (275,288,473,465)),
             12, 107, fill=(172,86,248,125), width=max(1,round(9*s)))

    outer = [(128,113),(248,113)]
    outer += cubic((248,113),(325,113),(356,152),(356,210))
    outer += cubic((356,210),(356,250),(334,280),(302,293))
    outer += [(360,376),(267,376),(215,298),(206,298),(206,376),(128,376)]
    hole = [(206,178),(242,178)]
    hole += cubic((242,178),(265,178),(281,186),(281,208))
    hole += cubic((281,208),(281,230),(265,238),(242,238))
    hole += [(206,238)]
    letter_mask = Image.new('L', (size, size), 0)
    lm = ImageDraw.Draw(letter_mask)
    lm.polygon(scale(outer,s), fill=255)
    lm.polygon(scale(hole,s), fill=0)
    letter = gradient(size, (255,255,255), (165,170,231))
    image.paste(letter, (0,0), letter_mask)

    arrow_points = [(348,267),(396,267),(396,339),(429,339),
                    (372,415),(316,339),(348,339)]
    arrow_mask = Image.new('L', (size,size), 0)
    ImageDraw.Draw(arrow_mask).polygon(scale(arrow_points,s), fill=255)
    arrow = gradient(size, (72,225,255), (203,71,255))
    image.paste(arrow, (0,0), arrow_mask)
    edge = ImageDraw.Draw(image)
    edge.line(scale(arrow_points+[arrow_points[0]],s),
              fill=(158,226,255,180), width=max(1,round(2*s)), joint='curve')
    return image


def ui_text_image(width, height, sidebar=False):
    img = Image.new('RGB', (width,height), (19,23,47))
    pix = img.load()
    for y in range(height):
        for x in range(width):
            f = (x / max(1,width))*.3 + (y / max(1,height))*.7
            pix[x,y] = mix((31,46,92),(20,18,42),f)
    drawer = ImageDraw.Draw(img)
    icon_size = 74 if sidebar else 42
    logo = brand_icon(256).resize((icon_size,icon_size), Image.Resampling.LANCZOS)
    img.paste(logo, (round((width-icon_size)/2),40) if sidebar else (8,round((height-icon_size)/2)),logo)
    drawer = ImageDraw.Draw(img)
    fonts = [r'C:\Windows\Fonts\segoeuib.ttf',r'C:\Windows\Fonts\arialbd.ttf']
    font_path = next((p for p in fonts if Path(p).exists()), None)
    if sidebar:
        text = 'RishiDM'
        position = (20,135)
        font_size=23
    else:
        text = 'RishiDM'
        position = (62,18)
        font_size=18
    font = ImageFont.truetype(font_path,font_size) if font_path else ImageFont.load_default()
    drawer.text(position,text,font=font,fill=(239,241,255))
    return img


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source-root',required=True)
    parser.add_argument('--extension-root',required=True)
    ns=parser.parse_args()
    app = Path(ns.source_root)/'desktop/app'
    ext = Path(ns.extension_root)/'public/icons'
    (app/'icons').mkdir(parents=True,exist_ok=True)
    (app/'resources/installer').mkdir(parents=True,exist_ok=True)
    ext.mkdir(parents=True,exist_ok=True)

    icon=brand_icon(512)
    icon.save(app/'icons/icon.png')
    icon.save(app/'icons/icon.ico',format='ICO',
              sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
    for size in (48,96,128):
        icon.resize((size,size),Image.Resampling.LANCZOS).save(ext/f'icon-{size}.png')
    ui_text_image(150,57).save(app/'resources/installer/abdm-header-image.bmp')
    ui_text_image(164,314,sidebar=True).save(app/'resources/installer/abdm-sidebar-image.bmp')
    print('RishiDM original Windows, installer and extension icons generated.')


if __name__ == '__main__':
    main()

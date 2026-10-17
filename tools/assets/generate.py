"""Original, deterministic vector and pixel assets. Requires Pillow >= 9.

Run from any directory: python tools/assets/generate.py
Image-generator artwork is intentionally not overwritten by this script.
"""
from pathlib import Path
import math
import json
import html
import re
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2] / 'Assets' / 'Generated'
ICONS = {}


def line(*points):
    return ('line', points)


def poly(*points):
    return ('poly', points)


def circle(x, y, r):
    return ('circle', (x, y, r))


def box(x, y, w, h):
    return poly((x, y), (x+w, y), (x+w, y+h), (x, y+h))


def arc(x, y, r, start, end, steps=24):
    return line(*[(x+r*math.cos(math.radians(start+(end-start)*i/steps)),
                   y+r*math.sin(math.radians(start+(end-start)*i/steps))) for i in range(steps+1)])


def icon(name, *shapes):
    ICONS['ic-'+name] = list(shapes)


icon('tab-map', poly((3,5),(9,3),(15,5),(21,3),(21,19),(15,21),(9,19),(3,21)), line((9,3),(9,19)), line((15,5),(15,21)))
icon('tab-explore', circle(12,12,9), poly((16,7),(14,14),(8,17),(10,10)))
icon('tab-styles', poly((3,9),(7,4),(17,4),(21,9),(12,21)), line((3,9),(21,9)), line((7,4),(9,9),(12,21),(15,9),(17,4)))
icon('tab-profile', circle(12,7,3), line((4,21),(5,16),(9,13),(15,13),(19,16),(20,21)))
icon('search', circle(10,10,6), line((14.5,14.5),(21,21)))
icon('mic', poly((9,4),(12,3),(15,4),(15,12),(12,14),(9,12)), line((6,10),(6,14),(9,17),(15,17),(18,14),(18,10)), line((12,17),(12,21)), line((9,21),(15,21)))
icon('layers', poly((3,8),(12,3),(21,8),(12,13)), line((3,13),(12,18),(21,13)), line((3,17),(12,21),(21,17)))
icon('friends', circle(8,7,3), circle(17,8,2.5), line((3,20),(3,16),(6,13),(10,13),(13,16),(13,20)), line((15,14),(19,14),(21,17),(21,20)))
icon('locate', poly((12,3),(20,21),(12,17),(4,21)))
icon('north', poly((8,20),(12,8),(16,20),(12,17)), line((9,6),(9,3),(15,6),(15,3)))
for suffix in ('in','out'):
    icon('zoom-'+suffix, circle(10,10,6), line((15,15),(21,21)), line((7,10),(13,10)), *([line((10,7),(10,13))] if suffix=='in' else []))
speaker = [poly((3,9),(7,9),(12,5),(12,19),(7,15),(3,15))]
icon('volume-on', *speaker, arc(12,12,5,-50,50), arc(12,12,9,-55,55))
icon('volume-off', *speaker, line((16,9),(21,15)), line((21,9),(16,15)))
icon('clip', box(3,5,13,14), poly((16,10),(21,7),(21,17),(16,14)), circle(7,9,0.5))
icon('share', circle(5,12,2), circle(18,5,2), circle(18,19,2), line((7,11),(16,6)), line((7,13),(16,18)))
icon('more', circle(5,12,0.6), circle(12,12,0.6), circle(19,12,0.6))
icon('close', line((5,5),(19,19)), line((19,5),(5,19)))
icon('back', line((12,4),(4,12),(12,20)), line((4,12),(21,12)))
icon('chevron', line((8,4),(16,12),(8,20)))
icon('reroute', line((6,21),(6,7),(10,3),(18,3),(21,6),(21,11),(18,14),(11,14)), line((14,10),(10,14),(14,18)))
icon('settings', poly(*[(12+(9 if i%2==0 else 7)*math.cos(i*math.pi/8),12+(9 if i%2==0 else 7)*math.sin(i*math.pi/8)) for i in range(16)]), circle(12,12,3))
icon('end-route', line((4,21),(4,3),(20,3),(20,15),(4,15)), line((9,6),(15,12)), line((15,6),(9,12)))
icon('route-options', line((12,21),(12,3)), line((12,15),(5,10),(5,4)), line((12,15),(19,10),(19,4)), line((3,6),(5,3),(7,6)), line((10,5),(12,3),(14,5)), line((17,6),(19,3),(21,6)))
icon('favorite', poly(*[(12+(9 if i%2==0 else 4)*math.sin(i*math.pi/5),12-(9 if i%2==0 else 4)*math.cos(i*math.pi/5)) for i in range(10)]))
icon('history', arc(12,12,8,-145,180), line((3,5),(5,8),(8,7)), line((12,7),(12,12),(16,14)))
icon('contact', box(4,3,17,18), circle(12,9,2.5), line((8,17),(8,15),(12,13),(16,15),(16,17)), line((3,7),(6,7)), line((3,17),(6,17)))
icon('calendar', box(3,5,18,16), line((3,10),(21,10)), line((7,3),(7,7)), line((17,3),(17,7)), line((7,14),(10,14)), line((14,17),(17,17)))
icon('home', poly((3,10),(12,3),(21,10),(19,10),(19,21),(14,21),(14,14),(10,14),(10,21),(5,21),(5,10)))
icon('work', box(3,8,18,13), line((8,8),(8,3),(16,3),(16,8)), line((3,13),(9,15),(15,15),(21,13)), line((12,13),(12,17)))
icon('fuel', box(4,3,11,18), box(6,5,7,5), line((15,12),(18,12),(18,19),(21,19),(21,8),(18,5)), line((3,21),(16,21)))
icon('parking', poly((5,3),(19,3),(21,5),(21,19),(19,21),(5,21),(3,19),(3,5)), line((9,18),(9,6),(15,6),(17,8),(17,10),(15,12),(9,12)))
icon('charging', line((7,3),(7,7)), line((15,3),(15,7)), poly((5,7),(17,7),(17,12),(13,16),(9,16),(5,12)), line((11,16),(11,21)), line((20,13),(18,17),(21,17),(19,21)))
icon('food', line((4,3),(4,9),(7,12),(10,9),(10,3)), line((7,3),(7,21)), line((20,21),(20,3),(16,7),(16,13),(20,13)))
icon('fog', line((3,12),(3,8),(6,6),(9,6),(11,3),(16,3),(19,7),(21,8),(21,12)), poly((3,17),(7,14),(17,14),(21,17),(17,20),(7,20)), circle(12,17,2))
icon('district', poly((3,4),(8,3),(9,5),(15,4),(21,6),(20,21),(14,20),(8,21),(3,19)), poly((12,18),(7,10),(8,7),(12,6),(16,7),(17,10)), circle(12,10,1.5))
icon('badge', circle(12,9,6), line((7,14),(5,21),(10,19),(12,21),(14,19),(19,21),(17,14)), circle(12,9,2))
icon('goal', circle(12,12,9), circle(12,12,5), circle(12,12,1))
icon('stats', line((3,3),(3,21),(21,21)), box(6,13,3,5), box(12,8,3,10), box(18,4,3,14))
icon('streak', poly((12,3),(11,8),(15,11),(17,8),(20,14),(19,18),(15,21),(9,21),(5,18),(4,14),(8,8),(8,13),(11,10)))
icon('lock', box(4,10,16,11), line((7,10),(7,6),(9,3),(15,3),(17,6),(17,10)), line((12,14),(12,17)))
icon('eye-off', line((3,11),(7,7),(13,6),(18,8),(21,12),(17,16),(12,18),(7,17)), line((3,3),(21,21)), arc(12,12,3,-90,30))
icon('location-off', line((8,5),(12,3),(17,5),(19,9),(18,13),(12,21),(7,15),(5,10)), line((3,3),(21,21)))


def geometry(shapes, western=False, fill='none'):
    out = []
    for kind, values in shapes:
        if kind=='circle':
            x,y,r=values
            out.append(f'<circle cx="{x:g}" cy="{y:g}" r="{r:g}"'+(' fill="currentColor"' if r<1 else '')+'/>')
            continue
        pts=list(values)
        if western:
            revised=[]
            for i,p in enumerate(pts):
                revised.append(p)
                if i+1<len(pts):
                    q=pts[i+1]
                    revised.append(((p[0]+q[0])/2+.12, (p[1]+q[1])/2-.10))
            pts=revised
        d='M '+' L '.join(f'{x:.3f},{y:.3f}' for x,y in pts)+(' Z' if kind=='poly' else '')
        out.append(f'<path d="{d}"'+(' fill="none"' if kind=='line' else '')+'/>')
        if western and len(pts)>1 and kind=='line':
            x,y=pts[0]
            out.append(f'<path d="M {x-.32:.3f},{y+.28:.3f} L {x+.32:.3f},{y-.28:.3f}" stroke-width="0.65"/>')
    return ''.join(out)


def svg(shapes, size=24, stroke='currentColor', width=2, fill='none', western=False, extra='', dimensions=None):
    dims=dimensions or size
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{dims}" height="{dims}"><g fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}>{geometry(shapes,western)}</g></svg>\n'


def write(folder, name, content):
    path=ROOT/folder/name
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(content,encoding='utf-8')


def save_pixel(folder,name,im,export4=True):
    path=ROOT/folder/(name+'.png')
    path.parent.mkdir(parents=True,exist_ok=True)
    im.save(path)
    if export4:
        im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST).save(path.with_name(name+'@4x.png'))


def raster(shapes, source=24, size=16, weight=1, color='#FFFFFF'):
    mask=Image.new('L',(size,size))
    draw=ImageDraw.Draw(mask)
    def pt(x,y):
        return (round(x/source*(size-3)+1),round(y/source*(size-3)+1))
    for kind,v in shapes:
        if kind=='circle':
            x,y,r=v
            draw.ellipse((*pt(x-r,y-r),*pt(x+r,y+r)),outline=255,width=weight)
        else:
            points=[pt(x,y) for x,y in v]
            if kind=='poly': points.append(points[0])
            draw.line(points,fill=255,width=weight)
    out=Image.new('RGBA',(size,size))
    out.paste('#000000',(0,0),mask.filter(ImageFilter.MaxFilter(3)))
    out.paste(color,(0,0),mask)
    return out


def generate_icons():
    for name,shapes in ICONS.items():
        write('Icons/Neon',name+'.svg',svg(shapes))
        write('Icons/Western',name+'.svg',svg(shapes,width=1.8,western=True))
        save_pixel('Icons/Pixel',name,raster(shapes))


def arrow(points, head=12):
    x,y=points[-1]; px,py=points[-2]
    a=math.atan2(y-py,x-px)
    return [line(*points),line((x-head*math.cos(a-.7),y-head*math.sin(a-.7)),(x,y),(x-head*math.cos(a+.7),y-head*math.sin(a+.7)))]


MANEUVERS={
    'straight':arrow([(48,82),(48,14)]),
    'slight-left':arrow([(56,82),(56,52),(28,17)]),
    'left':arrow([(68,82),(68,36),(15,36)]),
    'sharp-left':arrow([(70,82),(70,24),(60,18),(22,60)]),
    'uturn-left':arrow([(70,82),(70,30),(62,18),(39,18),(26,30),(26,65)]),
    'merge-left':arrow([(78,82),(60,59),(48,39),(48,14)])+[line((48,82),(48,49))],
    'fork-left':arrow([(48,82),(48,58),(22,19)])+[line((48,58),(76,19))],
    'ramp-exit-left':arrow([(61,82),(61,57),(21,20)])+[line((61,57),(61,14))],
    'keep-left':arrow([(63,82),(63,64),(34,40),(34,14)]),
}
for name,shapes in list(MANEUVERS.items()):
    if name.endswith('left'):
        MANEUVERS[name[:-4]+'right']=[(kind,tuple((96-x,y) for x,y in pts)) for kind,pts in shapes]
for i,angle in enumerate((0,-55,-110,-165,-220),1):
    # Enter from south, travel east, north, west: counter-clockwise on screen.
    pts=[(48,84),(48,68)]
    pts += [(48+20*math.cos(math.radians(a)),48+20*math.sin(math.radians(a))) for a in [90+(angle-90)*j/32 for j in range(33)]]
    pts += [(48+38*math.cos(math.radians(angle)),48+38*math.sin(math.radians(angle)))]
    MANEUVERS[f'roundabout-exit-{i}']=arrow(pts,10)+([arc(48,48,20,115,angle+335,24)] if angle+335>115 else [])
MANEUVERS['destination']=[line((27,82),(27,16)),poly((27,18),(70,18),(62,34),(70,49),(27,49))]
for side in ('left','right'):
    flag=[(kind,tuple((x*.55+(40 if side=='right' else 4),y*.65+4) for x,y in pts)) for kind,pts in MANEUVERS['destination']]
    MANEUVERS['destination-'+side]=flag+arrow([(48,83),(48,68),(78 if side=='right' else 18,68)],10)


def generate_maneuvers():
    for name,shapes in MANEUVERS.items():
        write('Maneuvers/Neon','maneuver-'+name+'.svg',svg(shapes,96,width=10))
        write('Maneuvers/Western','maneuver-'+name+'.svg',svg(shapes,96,width=8,western=True))
        save_pixel('Maneuvers/Pixel','maneuver-'+name,raster(shapes,96,24,2),False)


BLIPS = {
    'fuel':('#F08A2C',[box(7,4,12,24),line((19,13),(24,13),(24,25),(28,25),(28,10),(24,6))]),
    'parking':('#5FB6FF',[poly((8,28),(8,4),(21,4),(26,8),(26,16),(21,20),(14,20),(14,28))]),
    'food':('#7EE06A',[poly((5,4),(7,4),(7,10),(9,10),(9,4),(11,4),(11,10),(13,10),(13,4),(15,4),(15,14),(12,17),(12,28),(8,28),(8,17),(5,14)),poly((24,4),(26,4),(26,28),(22,28),(22,18),(19,18),(19,10))]),
    'shop':('#F5D742',[poly((7,8),(28,8),(24,21),(11,21)),line((4,4),(7,4),(12,26),(25,26)),circle(13,28,1),circle(24,28,1)]),
    'charging':('#33E1C7',[poly((7,10),(25,10),(25,17),(19,23),(19,28),(13,28),(13,23),(7,17)),box(10,4,3,6),box(19,4,3,6)]),
    'hospital':('#FF5A5A',[poly((12,4),(20,4),(20,12),(28,12),(28,20),(20,20),(20,28),(12,28),(12,20),(4,20),(4,12),(12,12))]),
    'friend':('#FF4FD8',[circle(16,9,5),poly((5,28),(6,22),(11,18),(21,18),(26,22),(27,28))]),
    'home':('#FFFFFF',[poly((4,15),(16,4),(28,15),(25,15),(25,28),(7,28),(7,15))]),
    'work':('#FFFFFF',[box(4,11,24,17),poly((10,11),(10,5),(22,5),(22,11))]),
    'destination':('#F5D742',[circle(16,16,10)]),
    'waypoint':('#A13DF0',[poly((16,4),(28,16),(16,28),(4,16))]),
}

# Hand-authored native 10x10 silhouettes, not downsampled illustrations.
SPRITES={
 'fuel':['..........','..kkkkkk..','..krrrrk..','..kwwwwkk.','..kwwwwkrk','..krrrrkrk','..krrrrkkk','..krrrrk..','.kkkkkkkk.','..........'],
 'parking':['.kkkkkkkk.','.kbbbbbbk.','.kbwwwbbk.','.kbwbwbbk.','.kbwwwbbk.','.kbwbbbbk.','.kbwbbbbk.','.kbbbbbbk.','.kkkkkkkk.','..........'],
 'food':['..........','....kkk...','...krrrk..','..krrrrrk.','..krrrrrk.','...krrrk..','..kwkkk...','.kwwk.....','.kwk......','..k.......'],
 'shop':['..........','kk........','.kyyyyyyyk','.kyyyyyyyk','..kyyyyyk.','..kyyyyyk.','...kkkkk..','...kyyyyk.','...kk.kk..','..........'],
 'charging':['...kkkk...','..kggggk..','..kggygk..','..kgyggk..','..kgyyyk..','..kggy gk..'.replace(' ',''),'..kgyggk..','..kggggk..','..kkkkkk..','..........'],
 'hospital':['..........','.kkkkkkkk.','.kwwwwwwk.','.kwwrrwwk.','.kwrrrrwk.','.kwrrrrwk.','.kwwrrwwk.','.kwwwwwwk.','.kkkkkkkk.','..........'],
 'friend':['...kkkk...','..kyyyyk..','.kyyyyyyk.','.kykyykyk.','.kyyyyyyk.','.kykyykyk.','..kykkyk..','..kyyyyk..','...kkkk...','..........'],
 'home':['....kk....','...krrk...','..krrrrk..','.krrrrrrk.','kkkkkkkkkk','.kwwwwwwk.','.kwbwwbwk.','.kwwkkwwk.','.kwwkkwwk.','.kkkkkkkk.'],
 'work':['...kkkk...','..kwwwwk..','..kbwwbk..','..kwwwwk..','..kbwwbk..','..kwwwwk..','..kbwwbk..','..kwwwwk..','..kwkkwk..','..kkkkkk..'],
 'destination':['..........','..kkkkkk..','.krrrrrrk.','krrrrrrrrk','kyyyyyyyyk','krrryyrrrk','krrryyrrrk','krrrrrrrrk','kkkkkkkkkk','..........'],
 'waypoint':['...kkkk...','..kyyyyk..','.kyyyyyyk.','.kyykyyyk.','.kyykyyyk.','.kyykyyyk.','.kyykyyyk.','..kyyyyk..','...kkkk...','..........'],
}
PALETTE={'k':'#000000','w':'#FFFFFF','r':'#E8372C','b':'#5FB6FF','g':'#60C650','y':'#FFCC33'}


def sprite(rows,palette=PALETTE):
    assert len({len(row) for row in rows}) == 1, 'Sprite rows must have identical widths'
    im=Image.new('RGBA',(len(rows[0]),len(rows)))
    d=ImageDraw.Draw(im)
    for y,row in enumerate(rows):
        for x,c in enumerate(row):
            if c in palette:d.point((x,y),fill=palette[c])
    return im


def generate_blips():
    for name,(color,shapes) in BLIPS.items():
        details=''
        if name=='fuel': details='<path fill="#000" d="M9 7h8v6H9z"/>'
        if name=='parking': details='<path fill="#000" d="M14 9h6v6h-6z"/>'
        if name=='charging': details='<path fill="#000" d="M17 11l-5 7h4l-1 5 6-8h-4z"/>'
        if name=='home': details='<path fill="#000" d="M13 21h6v7h-6z"/>'
        s=svg(shapes,32,stroke='#000000',width=3,fill=color,extra='paint-order="stroke fill"')
        write('Blips/Neon','blip-'+name+'.svg',s.replace('</svg>',details+'</svg>'))
        west=shapes if name!='destination' else [poly((7,4),(16,12),(25,5),(28,9),(20,17),(27,25),(23,28),(16,21),(7,28),(4,24),(12,16),(4,8))]
        s=svg(west,32,stroke='#F2E4BF',width=6,fill='#C0261F' if name=='destination' else '#3A2414',western=True,extra='paint-order="stroke fill"')
        # Halo first, then ink linework so open portions also remain visible.
        s=s.replace('</svg>',f'<g fill="none" stroke="{"#C0261F" if name=="destination" else "#3A2414"}" stroke-width="1.3">{geometry(west,True)}</g>'+details.replace('#000','#F2E4BF')+'</svg>')
        write('Blips/Western','blip-'+name+'.svg',s)
        save_pixel('Blips/Pixel','blip-'+name,sprite(SPRITES[name]))


def generate_toy_blips():
    colors={'parking':'#1F6FE0','fuel':'#F08A2C','food':'#2FB94A',
            'shop':'#F5D742','charging':'#33E1C7','hospital':'#FF5A5A',
            'friend':'#1F6FE0','home':'#FF7A00','work':'#1F6FE0',
            'waypoint':'#FF7A00'}
    for name,(_,shapes) in BLIPS.items():
        if name=='destination':
            # A self-contained checkered flag, rather than another disc glyph.
            body='<path d="M7 28V4" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/><path d="M7 28V4" fill="none" stroke="#2F3640" stroke-width="2" stroke-linecap="round"/>'
            body+='<path d="M8 5H28V20H8Z" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="4"/>'
            body+=''.join(f'<rect x="{8+5*x}" y="{5+5*y}" width="5" height="5" fill="#2F3640"/>' for y in range(3) for x in range(4) if (x+y)%2==0)
            body+='<path d="M8 5H28V20H8Z" fill="none" stroke="#2F3640" stroke-width="1"/>'
        else:
            body=f'<circle cx="16" cy="16" r="14" fill="{colors[name]}" stroke="#FFFFFF" stroke-width="2"/><circle cx="16" cy="16" r="15.4" fill="none" stroke="#2F3640" stroke-width="0.6"/>'
            glyph=geometry(shapes)
            # Open glyph strokes are white, edged by a thin charcoal underlay.
            body+='<g transform="translate(5.6 5.6) scale(.65)" stroke-linecap="round" stroke-linejoin="round">'
            body+=f'<g fill="#FFFFFF" stroke="#2F3640" stroke-width="3.2">{glyph}</g><g fill="#FFFFFF" stroke="#FFFFFF" stroke-width="1.6">{glyph}</g>'
            details={'parking':'M14 9h6v6h-6z','fuel':'M9 7h8v6H9z',
                     'charging':'M17 11l-5 7h4l-1 5 6-8h-4z','home':'M13 21h6v7h-6z'}
            if name in details:body+=f'<path d="{details[name]}" fill="#2F3640"/>'
            body+='</g>'
        write('Blips/Toy','blip-'+name+'.svg',f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">{body}</svg>\n')


def generate_player():
    shape=[poly((32,5),(56,56),(32,45),(8,56))]
    write('Player','player-neon.svg',svg(shape,64,'#000000',5,'#E9E9E9'))
    write('Player','player-western.svg',svg(shape,64,'#3A2414',5,'#F6EAD0',True))
    marker=sprite(['...k...','..kwk..','..kwk..','.kwwsk.','.kwwsk.','kdwwdsk','kdwwdsk','kdwwdsk','ksssssk','kkkkkkk'],
                  {'k':'#000000','w':'#FFFFFF','d':'#DCDCDC','s':'#A4A4A4'})
    # Expanded canvases preserve the pointed tip and flat back at every heading.
    for i,heading in enumerate(('n','ne','e','se','s','sw','w','nw')):
        im=marker.rotate(-45*i,resample=Image.Resampling.NEAREST,expand=True)
        save_pixel('Player','player-pixel-'+heading,im)
    toy='''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
<defs><filter id="toy-car-shadow" x="-50%" y="-30%" width="200%" height="170%"><feDropShadow dx="0" dy="2" stdDeviation="1.6" flood-color="#2F3640" flood-opacity=".35"/></filter></defs>
<g filter="url(#toy-car-shadow)" stroke="#2F3640" stroke-width="3" stroke-linejoin="round">
<rect x="12" y="15" width="8" height="12" rx="3" fill="#2F3640"/><rect x="44" y="15" width="8" height="12" rx="3" fill="#2F3640"/>
<rect x="12" y="39" width="8" height="12" rx="3" fill="#2F3640"/><rect x="44" y="39" width="8" height="12" rx="3" fill="#2F3640"/>
<rect x="17" y="5" width="30" height="52" rx="11" fill="#E8372C"/>
<path d="M23 19Q32 16 41 19L39 28H25Z" fill="#9DDFFF"/>
<path d="M25 39H39L41 46Q32 49 23 46Z" fill="#9DDFFF"/>
<path d="M21 11H27V15H21ZM37 11H43V15H37Z" fill="#FFCC33" stroke-width="1.5"/>
<path d="M24 52H28M36 52H40" fill="none" stroke-linecap="round"/>
</g></svg>\n'''
    write('Player','player-toy.svg',toy)


def generate_carplay():
    names={'search':'search','style':'layers','friends':'friends','zoom-in':'zoom-in','zoom-out':'zoom-out','locate':'locate','home':'home','work':'work','fuel':'fuel','parking':'parking','charging':'charging','favorite':'favorite','history':'history'}
    for name,source in names.items():
        # Base is 30 pt; explicit 44 pt variants cover list and map templates.
        for suffix,size in (('',30),('-list',44),('-map',44)):
            shapes=ICONS['ic-'+source]
            if name=='parking':
                # No text in CarPlay templates: original parked-car silhouette.
                shapes=[poly((4,16),(4,10),(7,6),(17,6),(20,10),(20,16)),line((4,10),(20,10)),line((7,16),(7,19)),line((17,16),(17,19)),line((7,13),(8,13)),line((16,13),(17,13))]
            write('CarPlay','cp-'+name+suffix+'.svg',svg(shapes,stroke='#000000',dimensions=size))


def generate_badges():
    themes={'first-drive':'locate','10-km':'route-options','100-km':'reroute','night-owl':None,'early-bird':None,'old-town':None,'explorer-25':'district','explorer-50':'district','explorer-100':'district','weekly-goal':'goal','streak-7':'streak','convoy':None}
    for name,source in themes.items():
        for tier,color in {'gold':'#D9AD3A','silver':'#B9BEC4','bronze':'#B87333','locked':'#555555'}.items():
            inner=geometry(ICONS['ic-'+source]) if source else ''
            if name=='night-owl':inner='<path d="M16 3C3 0 1 18 12 21C17 22 21 17 21 14C12 18 7 8 16 3Z"/>'
            if name=='early-bird':inner=geometry([circle(12,12,5)]+[line((12+8*math.cos(a),12+8*math.sin(a)),(12+10*math.cos(a),12+10*math.sin(a))) for a in [i*math.pi/4 for i in range(8)]])
            if name=='old-town':inner=geometry([poly((5,21),(5,8),(3,8),(3,3),(7,3),(7,6),(10,6),(10,3),(14,3),(14,6),(17,6),(17,3),(21,3),(21,8),(19,8),(19,21)),line((10,21),(10,16),(14,16),(14,21))])
            if name=='convoy':
                car=geometry([poly((3,15),(3,8),(6,3),(18,3),(21,8),(21,15)),line((3,8),(21,8)),line((6,15),(6,19)),line((18,15),(18,19))])
                inner=''.join(f'<g transform="translate({x} {y}) scale(.45)">{car}</g>' for x,y in [(0,10),(12,10),(6,0)])
            ticks=''
            if name.startswith('explorer-'):
                ticks=''.join(f'<circle cx="{52+12*i}" cy="104" r="3" fill="#201B18"/>' for i in range({'explorer-25':1,'explorer-50':2,'explorer-100':3}[name]))
            s=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128"><circle cx="64" cy="64" r="59" fill="{color}" stroke="#201B18" stroke-width="4"/><circle cx="64" cy="64" r="49" fill="none" stroke="#201B18" stroke-opacity=".3" stroke-width="2"/><g transform="translate(28 27) scale(3)" fill="none" stroke="#201B18" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">{inner}</g>{ticks}</svg>'
            write('Badges',f'badge-{name}-{tier}.svg',s)


def previews():
    folders=sorted({p.parent for p in ROOT.rglob('*') if p.suffix in ('.svg','.png')})
    for folder in folders:
        relative=folder.relative_to(ROOT).as_posix()
        bg='#DCC59A' if 'Western' in relative else '#1A2A6C' if 'Pixel' in relative else '#3D3E40'
        if relative=='Icons/Western': bg='#EFE2C0'
        if relative=='CarPlay': bg='#FFFFFF'
        if relative=='Blips/Toy': bg='#8DC63F'
        cards=[]
        for p in sorted(folder.iterdir()):
            if p.suffix not in ('.svg','.png'):continue
            if p.suffix=='.png':
                with Image.open(p) as im:w,h=im.size
            else:
                import xml.etree.ElementTree as ET
                e=ET.fromstring(p.read_text(encoding='utf-8'));w=float(e.get('width','24'));h=float(e.get('height','24'))
            scales=(1,2,4,8) if 'Icons/Pixel' in relative else (1,2,4)
            samples=[]
            for scale in scales:
                visual=p.read_text(encoding='utf-8') if p.suffix=='.svg' else f'<img src="{p.name}" alt="" width="{w*scale:g}" height="{h*scale:g}">'
                if p.suffix=='.svg':
                    # Each inline copy needs independent filter/clip definitions.
                    for identifier in re.findall(r'id="([^"]+)"',visual):
                        unique=f'{p.stem}-{scale}-{identifier}'
                        visual=visual.replace(f'id="{identifier}"',f'id="{unique}"').replace(f'url(#{identifier})',f'url(#{unique})')
                samples.append(f'<div><small>{scale}× · {w*scale:g}×{h*scale:g}</small><div class="sample" style="--w:{w*scale:g}px;--h:{h*scale:g}px">{visual}</div></div>')
            strip='<div class="strip">'+''.join(samples)+'</div>'
            article_bg=('#DCC59A' if 'western' in p.name else '#1A2A6C' if 'pixel' in p.name else '#8DC63F' if 'toy' in p.name else bg) if relative=='Player' else bg
            cards.append(f'<article style="background:{article_bg}"><h2><a href="{p.name}">{p.name}</a></h2>{strip}'+(f'<div class="light">{strip}</div>' if relative=='Icons/Neon' else '')+'</article>')
        style=f'body{{background:#181a20;color:#fff;font:14px system-ui;margin:24px}}a{{color:inherit}}h2{{font-size:13px}}article{{margin:12px 0;padding:16px;background:{bg};color:{"#2E1E10" if "Western" in relative else "white"};overflow:auto}}.strip{{display:flex;gap:28px;align-items:start}}small{{display:block;margin-bottom:12px}}.sample svg{{width:var(--w);height:var(--h)}}img{{image-rendering:pixelated;max-width:none}}.light{{background:white;color:black;margin-top:16px;padding:12px}}'
        if relative=='CarPlay': style+='article{color:black}'
        if relative in ('AppIcon','Store'): style+='img{image-rendering:auto}img[src="store-pixel.png"]{image-rendering:pixelated}'
        (folder/'index.html').write_text(f'<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>{html.escape(relative)} – Assets</title><style>{style}</style><body><a href="'+('../'*len(folder.relative_to(ROOT).parts))+'index.html">Alle Assets</a><h1>'+html.escape(relative)+'</h1>'+''.join(cards)+'</body></html>',encoding='utf-8')
    # Every intermediate directory receives its own navigable index as well.
    for folder in sorted([ROOT]+[p for p in ROOT.rglob('*') if p.is_dir()],reverse=True):
        children=[p for p in sorted(folder.iterdir()) if p.is_dir() and (p/'index.html').exists()]
        if children:
            links=''.join(f'<li><a href="{p.name}/index.html">{p.name}</a></li>' for p in children)
            (folder/'index.html').write_text('<!doctype html><html lang="de"><meta charset="utf-8"><title>Asset-Abnahme</title><style>body{background:#181a20;color:white;font:18px system-ui;margin:40px}a{color:#d4a4ff}li{margin:16px}</style><h1>Asset-Abnahme</h1><ul>'+links+'</ul></html>',encoding='utf-8')
    files=[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size} for p in sorted(ROOT.rglob('*')) if p.suffix in ('.svg','.png')]
    write('', 'manifest.json',json.dumps({'generator':'tools/assets/generate.py','files':files},indent=2)+'\n')


if __name__=='__main__':
    generate_icons()
    generate_maneuvers()
    generate_blips()
    generate_toy_blips()
    generate_player()
    generate_carplay()
    generate_badges()
    previews()
    print(f'Generated {len(ICONS)} icons/style, {len(MANEUVERS)} maneuvers/style; previews: {ROOT / "index.html"}')

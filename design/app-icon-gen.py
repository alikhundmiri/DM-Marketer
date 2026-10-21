import sys, json
# All coordinates in a 1024 space. Shared by the SVG icon and the SwiftUI mascot.
UPPER_OUT = "M192 540 C250 420 360 340 440 372 C480 388 500 410 512 410 C524 410 544 388 584 372 C664 340 774 420 832 540 C760 500 640 480 512 480 C384 480 264 500 192 540 Z"
LOWER_OUT = "M192 540 C234 700 364 770 512 770 C660 770 790 700 832 540 C800 770 660 860 512 860 C364 860 224 770 192 540 Z"
MOUTH = "M192 540 C264 500 384 480 512 480 C640 480 760 500 832 540 C790 700 660 770 512 770 C364 770 234 700 192 540 Z"
TONGUE = "M360 700 C380 590 644 590 664 700 C640 760 384 760 360 700 Z"
TEETH = "M270 470 H754 V580 Q754 600 734 600 H290 Q270 600 270 580 Z"
def svg(p):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{p['bg1']}"/><stop offset="1" stop-color="{p['bg2']}"/></linearGradient>
<clipPath id="m"><path d="{MOUTH}"/></clipPath>
</defs>
<rect width="1024" height="1024" fill="url(#bg)"/>
<g transform="translate(512 512) scale(1.12) translate(-512 -616)">
<g stroke="{p['ink']}" stroke-width="28" stroke-linejoin="round" stroke-linecap="round">
<path d="{MOUTH}" fill="{p['inside']}"/>
<g clip-path="url(#m)" stroke="none">
<path d="{TONGUE}" fill="{p['tongue']}"/>
<path d="{TEETH}" fill="{p['teeth']}"/>
<path d="M391 480 V600 M512 480 V600 M633 480 V600" stroke="{p['ink']}" stroke-width="7" opacity="0.35"/>
</g>
<path d="{MOUTH}" fill="none"/>
<path d="{LOWER_OUT}" fill="{p['lip']}"/>
<path d="{UPPER_OUT}" fill="{p['lip']}"/>
<path d="{MOUTH}" fill="none" stroke-width="0"/>
</g>
<g fill="{p['shine']}" stroke="none">
<ellipse cx="330" cy="440" rx="46" ry="16" transform="rotate(-28 330 440)"/>
<ellipse cx="590" cy="815" rx="80" ry="13" opacity="0.85" transform="rotate(-2 560 812)"/>
</g>
</g>
<g fill="none" stroke="{p['mark']}" stroke-width="30" stroke-linecap="round">
<g transform="translate(-6 -80)"><path d="M150 360 Q110 330 120 280"/><path d="M110 430 Q60 410 62 350"/></g>
<g transform="translate(6 -80)"><path d="M874 360 Q914 330 904 280"/><path d="M914 430 Q964 410 962 350"/></g>
</g>
</svg>'''
pal = {
 'light': dict(bg1='#C9B3FF', bg2='#8F6BFF', ink='#2A0A1E', lip='#FF2D4B', inside='#4A0F24', tongue='#FF7BA9', teeth='#FFFFFF', shine='#FFFFFF', mark='#FFFFFF'),
 'dark':  dict(bg1='#2B1A55', bg2='#14092E', ink='#0B0414', lip='#FF2D4B', inside='#4A0F24', tongue='#FF7BA9', teeth='#FFFFFF', shine='#FFFFFF', mark='#C9B3FF'),
 'tinted':dict(bg1='#000000', bg2='#000000', ink='#000000', lip='#B5B5B5', inside='#222222', tongue='#8A8A8A', teeth='#FFFFFF', shine='#FFFFFF', mark='#FFFFFF'),
}
for k,p in pal.items(): open(f'{k}.svg','w').write(svg(p))

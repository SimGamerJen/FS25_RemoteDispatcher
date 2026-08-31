from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W = H = 512
BG = (23, 21, 21)
PANEL = (47, 44, 44)
ROSE = (213, 160, 143)
ROSE_LIGHT = (242, 199, 184)
ROSE_DARK = (169, 117, 104)
CREAM = (247, 240, 236)
MUTED = (185, 173, 167)


def font(size):
    candidates = [
        Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'),
        Path('/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf'),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


image = Image.new('RGB', (W, H), BG)

glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for radius in range(230, 20, -6):
    alpha = int(35 * (1 - radius / 230) ** 1.2)
    gd.ellipse(
        (256 - radius, 235 - radius, 256 + radius, 235 + radius),
        fill=(*ROSE, alpha),
    )
glow = glow.filter(ImageFilter.GaussianBlur(10))
image = Image.alpha_composite(image.convert('RGBA'), glow).convert('RGB')
draw = ImageDraw.Draw(image)

# SGJ-style frame.
draw.rounded_rectangle((28, 28, 484, 484), radius=48, fill=(31, 28, 28), outline=ROSE_DARK, width=5)
draw.rounded_rectangle((46, 46, 466, 466), radius=38, outline=(82, 65, 60), width=2)

# Dispatch route and target.
route = [(115, 315), (150, 285), (190, 300), (228, 265), (275, 275), (318, 230), (372, 245)]
draw.line(route, fill=ROSE_DARK, width=18, joint='curve')
draw.line(route, fill=ROSE_LIGHT, width=12, joint='curve')
for x, y in (route[0], route[-1]):
    draw.ellipse((x - 16, y - 16, x + 16, y + 16), fill=(31, 28, 28), outline=ROSE_LIGHT, width=6)
draw.ellipse((366, 239, 378, 251), fill=ROSE_LIGHT)

# Simple vehicle silhouette.
draw.rounded_rectangle((80, 265, 145, 315), radius=8, fill=CREAM)
draw.rectangle((92, 247, 128, 271), fill=CREAM)
draw.rectangle((100, 251, 121, 266), fill=PANEL)
draw.ellipse((84, 301, 110, 327), fill=(31, 28, 28), outline=CREAM, width=5)
draw.ellipse((124, 302, 154, 332), fill=(31, 28, 28), outline=CREAM, width=5)

# Remote/radio waves.
for radius in (28, 44, 60):
    draw.arc((372 - radius, 245 - radius, 372 + radius, 245 + radius), start=205, end=335, fill=ROSE_LIGHT, width=6)

small = font(28)
monogram = font(128)
label = font(22)

def centred(text, y, typeface, colour):
    box = draw.textbbox((0, 0), text, font=typeface)
    width = box[2] - box[0]
    draw.text(((W - width) / 2, y), text, font=typeface, fill=colour)

centred('REMOTE DISPATCHER', 78, small, ROSE)
centred('RD', 102, monogram, ROSE_LIGHT)
centred('AUTODRIVE   •   COURSEPLAY', 410, label, MUTED)

# FS25/website-compatible BC1/DXT1 DDS, 512 x 512.
image.save('RemoteDispatcher.dds', format='DDS', pixel_format='DXT1')
print('Generated RemoteDispatcher.dds (512x512 DXT1)')

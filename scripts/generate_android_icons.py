#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw

def generate_icons():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    icon_path = os.path.join(base_dir, 'assets', 'icons', 'app_icon.png')
    res_dir = os.path.join(base_dir, 'android', 'app', 'src', 'main', 'res')

    print(f"Loading master icon from: {icon_path}")
    master_img = Image.open(icon_path).convert('RGBA')

    # Android densities: (density_name, launcher_size, foreground_size)
    densities = [
        ('mipmap-mdpi', 48, 108),
        ('mipmap-hdpi', 72, 162),
        ('mipmap-xhdpi', 96, 216),
        ('mipmap-xxhdpi', 144, 324),
        ('mipmap-xxxhdpi', 192, 432),
    ]

    for folder_name, launcher_size, fg_size in densities:
        out_folder = os.path.join(res_dir, folder_name)
        os.makedirs(out_folder, exist_ok=True)

        # 1. Standard square/squircle ic_launcher.png
        launcher_img = master_img.resize((launcher_size, launcher_size), Image.Resampling.LANCZOS)
        launcher_out = os.path.join(out_folder, 'ic_launcher.png')
        launcher_img.save(launcher_out, 'PNG')
        print(f"Generated {launcher_out} ({launcher_size}x{launcher_size})")

        # 2. Round ic_launcher_round.png
        round_mask = Image.new('L', (launcher_size, launcher_size), 0)
        draw = ImageDraw.Draw(round_mask)
        draw.ellipse((0, 0, launcher_size, launcher_size), fill=255)
        round_img = Image.new('RGBA', (launcher_size, launcher_size), (0, 0, 0, 0))
        round_img.paste(launcher_img, (0, 0), mask=round_mask)
        round_out = os.path.join(out_folder, 'ic_launcher_round.png')
        round_img.save(round_out, 'PNG')
        print(f"Generated {round_out} ({launcher_size}x{launcher_size})")

        # 3. Adaptive Foreground ic_launcher_foreground.png (Safe zone: ~66% scale in center)
        fg_canvas = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
        target_content_size = int(fg_size * 0.72)
        scaled_content = master_img.resize((target_content_size, target_content_size), Image.Resampling.LANCZOS)
        offset = (fg_size - target_content_size) // 2
        fg_canvas.paste(scaled_content, (offset, offset), mask=scaled_content)
        fg_out = os.path.join(out_folder, 'ic_launcher_foreground.png')
        fg_canvas.save(fg_out, 'PNG')
        print(f"Generated {fg_out} ({fg_size}x{fg_size})")

    # 4. Create mipmap-anydpi-v26 for Adaptive Icons
    v26_folder = os.path.join(res_dir, 'mipmap-anydpi-v26')
    os.makedirs(v26_folder, exist_ok=True)

    ic_launcher_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    with open(os.path.join(v26_folder, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write(ic_launcher_xml)

    with open(os.path.join(v26_folder, 'ic_launcher_round.xml'), 'w', encoding='utf-8') as f:
        f.write(ic_launcher_xml)

    # 5. Add color resource for adaptive icon background in values/colors.xml
    values_folder = os.path.join(res_dir, 'values')
    os.makedirs(values_folder, exist_ok=True)
    colors_xml = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0F172A</color>
</resources>
"""
    with open(os.path.join(values_folder, 'colors.xml'), 'w', encoding='utf-8') as f:
        f.write(colors_xml)

    print("✅ All Android launcher and adaptive icons generated successfully!")

if __name__ == '__main__':
    generate_icons()

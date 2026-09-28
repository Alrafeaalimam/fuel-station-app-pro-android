import math
from PIL import Image, ImageDraw, ImageFilter

def create_fuel_station_icon(size=1024):
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Scale helper
    def s(v):
        return int(v * (size / 1024.0))

    # 1. Outer rounded container (Squircle background)
    pad = s(50)
    rect = [pad, pad, size - pad, size - pad]
    radius = s(210)
    
    # Draw dark navy background with subtle border
    # Background gradient approximation via layered shapes
    bg_color = (15, 23, 42, 255)       # #0F172A (Deep Slate/Navy)
    border_color = (51, 65, 85, 255)   # #334155
    inner_glow = (30, 41, 59, 255)     # #1E293B
    
    # Outer border shadow/glow
    draw.rounded_rectangle(rect, radius=radius, fill=bg_color, outline=border_color, width=s(14))
    
    # Subtle inner background highlight
    inner_rect = [pad + s(14), pad + s(14), size - pad - s(14), size - pad - s(14)]
    draw.rounded_rectangle(inner_rect, radius=radius - s(10), outline=inner_glow, width=s(8))
    
    # Subtle center circular glow behind pump
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([s(200), s(200), s(824), s(824)], fill=(37, 99, 235, 45)) # Blue ambient glow
    glow = glow.filter(ImageFilter.GaussianBlur(s(80)))
    img.alpha_composite(glow)
    draw = ImageDraw.Draw(img)

    # 2. Modern Fuel Pump Dimensions
    # Pump is placed slightly left of center to allow room for the nozzle/hose on the right
    pump_left = s(240)
    pump_right = s(620)
    pump_top = s(250)
    pump_bottom = s(810)
    
    # Base pedestal
    base_left = s(200)
    base_right = s(660)
    base_top = pump_bottom
    base_bottom = s(870)
    draw.rounded_rectangle([base_left, base_top, base_right, base_bottom], radius=s(20), fill=(30, 41, 59, 255), outline=(71, 85, 105, 255), width=s(6))
    
    # Base highlight stripe (Navy/Cyan)
    draw.rounded_rectangle([base_left + s(20), base_top + s(8), base_right - s(20), base_top + s(18)], radius=s(5), fill=(56, 189, 248, 180))

    # Main Pump Body
    pump_color = (248, 250, 252, 255) # Clean modern off-white/aluminum body
    draw.rounded_rectangle([pump_left, pump_top, pump_right, pump_bottom], radius=s(35), fill=pump_color, outline=(203, 213, 225, 255), width=s(6))
    
    # Canopy / Top Cap of Pump
    cap_top = s(215)
    cap_bottom = s(275)
    cap_left = s(220)
    cap_right = s(640)
    # Vibrant Orange Canopy (#F97316)
    draw.rounded_rectangle([cap_left, cap_top, cap_right, cap_bottom], radius=s(20), fill=(249, 115, 22, 255), outline=(234, 88, 12, 255), width=s(6))
    
    # Canopy glossy highlight
    draw.rounded_rectangle([cap_left + s(15), cap_top + s(8), cap_right - s(15), cap_top + s(20)], radius=s(6), fill=(255, 237, 213, 140))

    # 3. Digital Meter Display / Screen
    disp_left = s(280)
    disp_right = s(580)
    disp_top = s(310)
    disp_bottom = s(550)
    disp_bg = (15, 23, 42, 255) # Deep Dark Navy screen
    draw.rounded_rectangle([disp_left, disp_top, disp_right, disp_bottom], radius=s(22), fill=disp_bg, outline=(37, 99, 235, 255), width=s(8))
    
    # Digital meter readout lines (top of screen)
    # Line 1: Liters indicator
    draw.rounded_rectangle([disp_left + s(25), disp_top + s(22), disp_left + s(140), disp_top + s(34)], radius=s(4), fill=(56, 189, 248, 220))
    draw.rounded_rectangle([disp_right - s(100), disp_top + s(22), disp_right - s(25), disp_top + s(34)], radius=s(4), fill=(52, 211, 153, 220))

    # 4. Stylized Energy Fuel Drop in the center of the display
    drop_cx = (disp_left + disp_right) // 2
    drop_cy = disp_top + s(135)
    drop_w = s(48)
    drop_h = s(75)

    # Draw droplet shape
    # The drop has a sharp tip at top, smooth teardrop at bottom
    drop_points = []
    # Tip
    tip_x, tip_y = drop_cx, drop_cy - drop_h
    # Circle center for bottom
    bottom_cy = drop_cy + s(10)
    bottom_r = drop_w
    
    # Generate smooth drop polygon
    num_pts = 40
    # Left curve from tip to bottom
    for i in range(num_pts // 2 + 1):
        angle = math.pi + (i / (num_pts // 2)) * (math.pi / 2) # pi to 1.5 pi
        # blend from tip to circle
        t = i / (num_pts // 2)
        bx = drop_cx + bottom_r * math.cos(angle)
        by = bottom_cy + bottom_r * math.sin(angle)
        x = (1 - t) * tip_x + t * bx
        y = (1 - t) * tip_y + t * by
        drop_points.append((x, y))
    
    # Bottom circle arc
    for i in range(num_pts + 1):
        angle = -math.pi/2 + (i / num_pts) * math.pi # -pi/2 to pi/2 (bottom half)
        px = drop_cx + bottom_r * math.cos(angle)
        py = bottom_cy + bottom_r * math.sin(angle)
        drop_points.append((px, py))
        
    # Right curve back to tip
    for i in range(num_pts // 2 + 1):
        t = i / (num_pts // 2)
        angle = 0 - t * (math.pi / 2)
        bx = drop_cx + bottom_r * math.cos(angle)
        by = bottom_cy + bottom_r * math.sin(angle)
        x = t * tip_x + (1 - t) * bx
        y = t * tip_y + (1 - t) * by
        drop_points.append((x, y))

    # Fill droplet with vivid orange / flame gradient
    draw.polygon(drop_points, fill=(249, 115, 22, 255))
    
    # Inner droplet highlight (reflection)
    hl_points = [(p[0] * 0.65 + drop_cx * 0.35 - s(6), p[1] * 0.65 + drop_cy * 0.35 - s(8)) for p in drop_points[:len(drop_points)//2]]
    if len(hl_points) > 2:
        draw.polygon(hl_points, fill=(255, 237, 213, 220))

    # 5. Lower Pump Grille / Product Selectors
    grille_top = s(580)
    grille_bottom = s(770)
    
    # Product selector badges: Benzin (Orange/Red) & Diesel (Teal/Green)
    # Badge 1: Gasoline (Super)
    b1_rect = [s(280), grille_top + s(15), s(420), grille_top + s(75)]
    draw.rounded_rectangle(b1_rect, radius=s(12), fill=(249, 115, 22, 230))
    # Small text/notch representation
    draw.rounded_rectangle([b1_rect[0] + s(20), b1_rect[1] + s(25), b1_rect[1] + s(110), b1_rect[1] + s(35)], radius=s(3), fill=(255, 255, 255, 240))
    
    # Badge 2: Diesel
    b2_rect = [s(440), grille_top + s(15), s(580), grille_top + s(75)]
    draw.rounded_rectangle(b2_rect, radius=s(12), fill=(16, 185, 129, 230))
    draw.rounded_rectangle([b2_rect[0] + s(20), b2_rect[1] + s(25), b2_rect[1] + s(110), b2_rect[1] + s(35)], radius=s(3), fill=(255, 255, 255, 240))

    # Horizontal ventilation / tech slats
    for y_offset in range(s(110), s(160), s(16)):
        draw.rounded_rectangle([s(290), grille_top + y_offset, s(570), grille_top + y_offset + s(8)], radius=s(4), fill=(226, 232, 240, 255))

    # 6. Fuel Hose & Nozzle Gun (Right Side)
    # Nozzle Holster on the pump
    holster_x = pump_right - s(12)
    holster_y = s(460)
    draw.rounded_rectangle([holster_x, holster_y, holster_x + s(35), holster_y + s(90)], radius=s(8), fill=(71, 85, 105, 255))

    # Thick fuel hose: curves from pump bottom right, drops down, loops up to nozzle
    # We draw the hose as a smooth bezier spline using points
    hose_pts = []
    # Start at pump lower right
    p0 = (pump_right - s(20), s(740))
    p1 = (s(760), s(790)) # Control point 1 (sagging down loop)
    p2 = (s(830), s(720)) # Control point 2
    p3 = (s(790), s(550)) # Control point 3
    p4 = (s(730), s(450)) # Arrive near nozzle handle
    
    # Sample cubic/bezier spline
    def bezier_point(t, pts):
        # de Casteljau
        temp = list(pts)
        while len(temp) > 1:
            temp = [((1 - t) * temp[i][0] + t * temp[i+1][0], (1 - t) * temp[i][1] + t * temp[i+1][1]) for i in range(len(temp) - 1)]
        return temp[0]

    all_hose_ctrls = [p0, p1, p2, p3, p4]
    hose_path = [bezier_point(i / 60.0, all_hose_ctrls) for i in range(61)]
    
    # Draw thick black rubber hose
    for i in range(len(hose_path) - 1):
        draw.line([hose_path[i], hose_path[i+1]], fill=(15, 23, 42, 255), width=s(26))
        # Inner highlight on hose for 3D look
        draw.line([hose_path[i], hose_path[i+1]], fill=(71, 85, 105, 180), width=s(8))

    # 7. Sleek Dispenser Nozzle Gun
    # Handle & Body of nozzle
    gun_x = s(690)
    gun_y = s(380)
    
    # Gun Main Body (Orange #F97316)
    gun_body = [
        (gun_x + s(35), gun_y + s(10)),
        (gun_x + s(95), gun_y + s(30)),
        (gun_x + s(80), gun_y + s(85)),
        (gun_x + s(25), gun_y + s(65)),
    ]
    draw.polygon(gun_body, fill=(249, 115, 22, 255))
    
    # Grip / Handle (Dark Navy / Black rubber grip)
    grip = [
        (gun_x + s(80), gun_y + s(70)),
        (gun_x + s(105), gun_y + s(140)),
        (gun_x + s(80), gun_y + s(150)),
        (gun_x + s(55), gun_y + s(80)),
    ]
    draw.polygon(grip, fill=(30, 41, 59, 255))
    
    # Trigger guard arc
    draw.arc([gun_x + s(30), gun_y + s(60), gun_x + s(85), gun_y + s(125)], start=40, end=200, fill=(71, 85, 105, 255), width=s(7))
    
    # Metallic Spout / Tube (Angled down into holster)
    spout_pts = [
        (gun_x + s(30), gun_y + s(25)),
        (gun_x - s(40), gun_y + s(60)),
        (gun_x - s(48), gun_y + s(115)), # spout tip
        (gun_x - s(38), gun_y + s(117)),
        (gun_x - s(30), gun_y + s(68)),
        (gun_x + s(35), gun_y + s(38)),
    ]
    draw.polygon(spout_pts, fill=(203, 213, 225, 255))
    
    # Metallic spout tip ring (Bronze/Brass accent)
    draw.ellipse([gun_x - s(52), gun_y + s(110), gun_x - s(34), gun_y + s(124)], fill=(245, 158, 11, 255))

    return img

if __name__ == '__main__':
    icon = create_fuel_station_icon(1024)
    icon.save('test_icon_1024.png')
    print('Generated test_icon_1024.png successfully!')

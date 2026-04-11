#!/usr/bin/env python3
"""
Generate VibeCode app icon - A Dynamic Island for Claude Code
Represents a wave/island shape with code elements
"""

from PIL import Image, ImageDraw, ImageFont
import math

def create_icon(size):
    # Create image with transparency
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Color scheme - vibrant gradient
    color_primary = (88, 86, 214)  # Purple
    color_secondary = (58, 134, 255)  # Blue
    color_accent = (52, 211, 153)  # Teal

    # Draw island/wave shape
    center_x, center_y = size // 2, size // 2
    radius = size * 0.4

    # Create gradient background circle
    for i in range(int(radius), 0, -1):
        alpha = int(255 * (i / radius))
        r = int(color_primary[0] + (color_secondary[0] - color_primary[0]) * (1 - i/radius))
        g = int(color_primary[1] + (color_secondary[1] - color_primary[1]) * (1 - i/radius))
        b = int(color_primary[2] + (color_secondary[2] - color_primary[2]) * (1 - i/radius))
        draw.ellipse(
            [center_x - i, center_y - i, center_x + i, center_y + i],
            fill=(r, g, b, alpha)
        )

    # Draw wave pattern
    wave_y = center_y + radius * 0.2
    points = []
    for x in range(0, size, 2):
        y = wave_y + math.sin(x * 0.05) * radius * 0.15
        points.append((x, y))

    # Draw code brackets
    bracket_size = radius * 0.6
    bracket_width = int(size * 0.08)

    # Left bracket
    draw.arc(
        [center_x - bracket_size, center_y - bracket_size,
         center_x - bracket_size/3, center_y + bracket_size],
        start=90, end=270, fill=color_accent, width=bracket_width
    )

    # Right bracket
    draw.arc(
        [center_x + bracket_size/3, center_y - bracket_size,
         center_x + bracket_size, center_y + bracket_size],
        start=270, end=90, fill=color_accent, width=bracket_width
    )

    # Add subtle glow effect
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        [center_x - radius*1.1, center_y - radius*1.1,
         center_x + radius*1.1, center_y + radius*1.1],
        fill=(255, 255, 255, 30)
    )
    img = Image.alpha_composite(glow, img)

    return img

# Generate all required sizes
sizes = [16, 32, 64, 128, 256, 512, 1024]
base_path = "/Users/lvpengbin/vibecode/VibeCode/VibeCode/Resources/Assets.xcassets/AppIcon.appiconset/"

for size in sizes:
    icon = create_icon(size)
    icon.save(f"{base_path}icon_{size}x{size}.png", "PNG")
    print(f"Generated {size}x{size} icon")

print("All icons generated successfully!")

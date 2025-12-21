#!/usr/bin/env python3
"""
Generate app icons for BF6 Stats Tracker
Creates icons in all required sizes for macOS
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size):
    """Create a single app icon at the specified size"""
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Colors matching BF6 theme
    bg_dark = (20, 20, 25)      # Dark military background
    bg_orange = (255, 149, 0)   # BF6 Orange
    bg_red = (255, 59, 48)      # BF6 Red
    accent_gold = (255, 204, 0) # Yellow/Gold
    white = (255, 255, 255, 255)

    # Draw dark background with subtle gradient
    margin = size * 0.08
    corner_radius = size * 0.22

    # Dark background
    for i in range(size):
        ratio = i / size
        darkness = int(20 + 15 * ratio)
        draw.rectangle([0, i, size, i + 1], fill=(darkness, darkness, darkness + 5))

    # Draw tactical hexagon border
    border_width = max(2, size // 48)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner_radius,
        outline=bg_orange,
        width=border_width
    )

    center_x = size // 2
    center_y = size // 2

    # Draw tactical crosshair/target reticle in background
    reticle_radius = size * 0.42
    reticle_width = max(2, size // 80)
    reticle_color = (bg_orange[0], bg_orange[1], bg_orange[2], 40)

    # Outer circle
    draw.ellipse(
        [center_x - reticle_radius, center_y - reticle_radius,
         center_x + reticle_radius, center_y + reticle_radius],
        outline=reticle_color,
        width=reticle_width
    )

    # Inner circle
    inner_radius = size * 0.15
    draw.ellipse(
        [center_x - inner_radius, center_y - inner_radius,
         center_x + inner_radius, center_y + inner_radius],
        outline=reticle_color,
        width=reticle_width
    )

    # Crosshair lines with gap in middle
    gap = size * 0.08
    line_length = size * 0.35
    # Horizontal
    draw.line([center_x - line_length, center_y, center_x - gap, center_y],
              fill=reticle_color, width=reticle_width)
    draw.line([center_x + gap, center_y, center_x + line_length, center_y],
              fill=reticle_color, width=reticle_width)
    # Vertical
    draw.line([center_x, center_y - line_length, center_x, center_y - gap],
              fill=reticle_color, width=reticle_width)
    draw.line([center_x, center_y + gap, center_x, center_y + line_length],
              fill=reticle_color, width=reticle_width)

    # Draw stylized "BF6" text or dog tag shape in center
    if size >= 128:
        # Draw military dog tag shape
        tag_width = size * 0.35
        tag_height = size * 0.5
        tag_x = center_x - tag_width / 2
        tag_y = center_y - tag_height / 2
        tag_radius = size * 0.08

        # Dog tag background with gradient
        for i in range(int(tag_height)):
            y = tag_y + i
            ratio = i / tag_height
            r = int(bg_orange[0] * (1 - ratio) + bg_red[0] * ratio)
            g = int(bg_orange[1] * (1 - ratio) + bg_red[1] * ratio)
            b = int(bg_orange[2] * (1 - ratio) + bg_red[2] * ratio)

            draw.rounded_rectangle(
                [tag_x, y, tag_x + tag_width, y + 1],
                radius=tag_radius,
                fill=(r, g, b)
            )

        # Dog tag hole at top
        hole_radius = size * 0.04
        hole_y = tag_y + size * 0.08
        draw.ellipse(
            [center_x - hole_radius, hole_y - hole_radius,
             center_x + hole_radius, hole_y + hole_radius],
            fill=bg_dark
        )

        # Draw "BF6" text on tag
        font_size = int(size * 0.18)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", font_size)
        except:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", font_size)
            except:
                font = ImageFont.load_default()

        text = "BF6"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        text_x = center_x - text_width / 2
        text_y = center_y - text_height / 2 + size * 0.02

        # Draw text with shadow for depth
        shadow_offset = max(1, size // 200)
        draw.text((text_x + shadow_offset, text_y + shadow_offset), text,
                 fill=(0, 0, 0, 200), font=font)
        draw.text((text_x, text_y), text, fill=white, font=font)

        # Draw "STATS" subtitle
        subtitle_font_size = int(size * 0.08)
        try:
            subtitle_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", subtitle_font_size)
        except:
            try:
                subtitle_font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", subtitle_font_size)
            except:
                subtitle_font = ImageFont.load_default()

        subtitle = "STATS"
        bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
        subtitle_width = bbox[2] - bbox[0]

        subtitle_x = center_x - subtitle_width / 2
        subtitle_y = text_y + text_height + size * 0.03

        draw.text((subtitle_x + shadow_offset, subtitle_y + shadow_offset), subtitle,
                 fill=(0, 0, 0, 200), font=subtitle_font)
        draw.text((subtitle_x, subtitle_y), subtitle, fill=(255, 255, 255, 200), font=subtitle_font)

    elif size >= 32:
        # For smaller sizes, draw simplified version
        # Draw simple shield/badge shape with "6"
        badge_size = size * 0.6
        badge_x = center_x - badge_size / 2
        badge_y = center_y - badge_size / 2

        # Shield points
        points = [
            (center_x, badge_y),  # Top
            (badge_x + badge_size, badge_y + badge_size * 0.3),  # Right
            (center_x, badge_y + badge_size),  # Bottom
            (badge_x, badge_y + badge_size * 0.3),  # Left
        ]

        # Draw shield with gradient effect
        draw.polygon(points, fill=bg_orange, outline=accent_gold)

        # Draw "6" in center
        font_size = int(size * 0.35)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", font_size)
        except:
            font = ImageFont.load_default()

        text = "6"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        text_x = center_x - text_width / 2
        text_y = center_y - text_height / 2

        draw.text((text_x, text_y), text, fill=white, font=font)

    return img

def main():
    """Generate all required icon sizes"""
    # Icon sizes for macOS (1x and 2x)
    sizes = [
        (16, "16x16"),
        (32, "16x16@2x"),
        (32, "32x32"),
        (64, "32x32@2x"),
        (128, "128x128"),
        (256, "128x128@2x"),
        (256, "256x256"),
        (512, "256x256@2x"),
        (512, "512x512"),
        (1024, "512x512@2x"),
    ]

    output_dir = "BF6StatsTracker/Assets.xcassets/AppIcon.appiconset"

    print("Generating BF6 Stats Tracker app icons...")

    for size, name in sizes:
        print(f"  Creating {name} ({size}x{size}px)...")
        icon = create_icon(size)
        icon.save(os.path.join(output_dir, f"{name}.png"))

    print("\nUpdating Contents.json...")

    # Update Contents.json with filenames
    contents = {
        "images": [
            {
                "filename": "16x16.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "16x16"
            },
            {
                "filename": "16x16@2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "16x16"
            },
            {
                "filename": "32x32.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "32x32"
            },
            {
                "filename": "32x32@2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "32x32"
            },
            {
                "filename": "128x128.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "128x128"
            },
            {
                "filename": "128x128@2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "128x128"
            },
            {
                "filename": "256x256.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "256x256"
            },
            {
                "filename": "256x256@2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "256x256"
            },
            {
                "filename": "512x512.png",
                "idiom": "mac",
                "scale": "1x",
                "size": "512x512"
            },
            {
                "filename": "512x512@2x.png",
                "idiom": "mac",
                "scale": "2x",
                "size": "512x512"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

    import json
    with open(os.path.join(output_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    print("\n✓ App icons generated successfully!")
    print(f"✓ Icons saved to {output_dir}")
    print("\nThe icon features:")
    print("  • Dark military-themed background with tactical border")
    print("  • Crosshair/target reticle design element")
    print("  • Military dog tag with BF6 STATS branding")
    print("  • Orange to red gradient on the dog tag")
    print("  • Battlefield-inspired design for a combat stats tracker")

if __name__ == "__main__":
    main()

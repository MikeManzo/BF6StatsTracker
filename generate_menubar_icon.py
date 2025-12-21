#!/usr/bin/env python3
"""
Generate menu bar icon for BF6 Stats Tracker
Menu bar icons should be monochrome template images
"""

from PIL import Image, ImageDraw
import os

def create_menubar_icon(size):
    """Create a menu bar icon at the specified size"""
    # Menu bar icons should be black on transparent background
    # macOS will handle the color inversion for dark mode
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    black = (0, 0, 0, 255)

    # Reduce margins for menu bar (icons are smaller)
    margin = size * 0.05
    center_x = size // 2
    center_y = size // 2

    # Draw simplified dog tag shape (menu bar icons should be simple)
    tag_width = size * 0.5
    tag_height = size * 0.7
    tag_x = center_x - tag_width / 2
    tag_y = center_y - tag_height / 2
    tag_radius = size * 0.12

    # Dog tag outline
    draw.rounded_rectangle(
        [tag_x, tag_y, tag_x + tag_width, tag_y + tag_height],
        radius=tag_radius,
        fill=black
    )

    # Dog tag hole at top
    hole_radius = size * 0.08
    hole_y = tag_y + size * 0.12
    draw.ellipse(
        [center_x - hole_radius, hole_y - hole_radius,
         center_x + hole_radius, hole_y + hole_radius],
        fill=(0, 0, 0, 0)  # Transparent hole
    )

    # Draw "6" in the center
    # For menu bar, we want a bold simple design
    from PIL import ImageFont

    font_size = int(size * 0.4)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", font_size)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", font_size)
        except:
            font = ImageFont.load_default()

    text = "6"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    text_x = center_x - text_width / 2
    text_y = center_y - text_height / 2 + size * 0.05

    # Cut out the "6" from the dog tag (create negative space)
    # Draw white "6" which will create transparency
    temp_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    temp_draw = ImageDraw.Draw(temp_img)
    temp_draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)

    # Composite: use the "6" as a mask to cut out from the black shape
    # Create final image with the "6" cut out
    final_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    final_draw = ImageDraw.Draw(final_img)

    # Draw tag background
    final_draw.rounded_rectangle(
        [tag_x, tag_y, tag_x + tag_width, tag_y + tag_height],
        radius=tag_radius,
        fill=black
    )

    # Draw hole
    final_draw.ellipse(
        [center_x - hole_radius, hole_y - hole_radius,
         center_x + hole_radius, hole_y + hole_radius],
        fill=(0, 0, 0, 0)
    )

    # Draw the "6" in white (will show as transparent cutout)
    final_draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)

    # Use the white areas to create transparency in the black shape
    pixels = final_img.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixels[x, y]
            if r == 255 and g == 255 and b == 255:
                # Make the "6" area transparent
                pixels[x, y] = (0, 0, 0, 0)

    return final_img

def main():
    """Generate menu bar icons"""
    # Menu bar icons are typically 16x16 and 32x32 (for retina)
    # But we'll generate a few sizes
    output_dir = "BF6StatsTracker/Assets.xcassets"

    # Create MenuBarIcon.imageset if it doesn't exist
    menubar_dir = os.path.join(output_dir, "MenuBarIcon.imageset")
    os.makedirs(menubar_dir, exist_ok=True)

    print("Generating BF6 Stats Tracker menu bar icons...")

    sizes_to_generate = [
        (16, "menubar@1x.png"),
        (32, "menubar@2x.png"),
        (48, "menubar@3x.png"),
    ]

    for size, filename in sizes_to_generate:
        print(f"  Creating {filename} ({size}x{size}px)...")
        icon = create_menubar_icon(size)
        icon.save(os.path.join(menubar_dir, filename))

    # Create Contents.json
    contents = {
        "images": [
            {
                "filename": "menubar@1x.png",
                "idiom": "universal",
                "scale": "1x"
            },
            {
                "filename": "menubar@2x.png",
                "idiom": "universal",
                "scale": "2x"
            },
            {
                "filename": "menubar@3x.png",
                "idiom": "universal",
                "scale": "3x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "template-rendering-intent": "template"
        }
    }

    import json
    with open(os.path.join(menubar_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    print(f"\n✓ Menu bar icons generated successfully!")
    print(f"✓ Icons saved to {menubar_dir}")
    print("\nThe menu bar icon features:")
    print("  • Simple monochrome dog tag design")
    print("  • '6' cut out from the center")
    print("  • Template rendering for automatic light/dark mode support")
    print("\nNext steps:")
    print("  1. Update BF6StatsTrackerApp.swift to use the new icon")
    print("     Change: Image(systemName: \"gamecontroller.fill\")")
    print("     To: Image(\"MenuBarIcon\")")

if __name__ == "__main__":
    main()

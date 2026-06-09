import os
from PIL import Image

def make_white_bg_version(transparent_png_path, output_png_path):
    img = Image.open(transparent_png_path).convert("RGBA")
    
    # Create solid white background image
    white_bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    
    # Paste transparent logo on top using alpha channel as mask
    white_bg.paste(img, (0, 0), img)
    
    # Save as PNG
    white_bg.convert("RGB").save(output_png_path, "PNG")
    print(f"Created white background version: {output_png_path}")

# Paths
assets_dir = r"c:\CapitanYA\capitan11.5.2026\assets\images"
thick_logo = os.path.join(assets_dir, "logo_elguiaya_thick.png")
white_logo = os.path.join(assets_dir, "logo_elguiaya_white.png")

# Generate the white background version
make_white_bg_version(thick_logo, white_logo)

# Overwrite official logo files with the transparent one
transparent_targets = ["logo_elguiaya.png", "logo_capitan.png", "logo_velero.png"]
for target in transparent_targets:
    target_path = os.path.join(assets_dir, target)
    img = Image.open(thick_logo)
    img.save(target_path, "PNG")
    print(f"Overwrote {target} with transparent thick logo.")

# Overwrite app icon with the white background logo (best for launcher icons)
app_icon_target = os.path.join(assets_dir, "app_icon.png")
white_img = Image.open(white_logo)
white_img.save(app_icon_target, "PNG")
print("Overwrote app_icon.png with white-background logo.")

import os
from PIL import Image, ImageFilter, ImageOps

def extract_logo(image_path, output_path, thickness_increase=0):
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    
    # Target green color from original image
    target_green = (29, 139, 78) # #1D8B4E
    
    # Create new image for output
    out_img = Image.new("RGBA", (width, height))
    
    pixels = img.load()
    out_pixels = out_img.load()
    
    center_x, center_y = 511.5, 511.5
    max_radius = 410.0 # Bounding box is at 118 to 905 (diameter 787, radius ~394)
    
    for y in range(height):
        for x in range(width):
            # Check if within circle area to avoid watermark/external noise
            dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            if dist > max_radius:
                out_pixels[x, y] = (0, 0, 0, 0)
                continue
                
            r, g, b, a = pixels[x, y]
            
            # Calculate alpha based on deviation from white
            # Since white is (255, 255, 255) and green is (29, 139, 78),
            # the green pixel is darker (lower values).
            # We can use the distance from white in RGB space as the base for alpha.
            dist_from_white = ((255 - r)**2 + (255 - g)**2 + (255 - b)**2) ** 0.5
            max_dist = ((255 - 29)**2 + (255 - 139)**2 + (255 - 78)**2) ** 0.5
            
            alpha = dist_from_white / max_dist
            alpha = min(1.0, max(0.0, alpha))
            
            # Enhance contrast of alpha to make it clean
            if alpha < 0.05:
                alpha = 0.0
            elif alpha > 0.9:
                alpha = 1.0
                
            alpha_val = int(alpha * 255)
            out_pixels[x, y] = (target_green[0], target_green[1], target_green[2], alpha_val)
            
    if thickness_increase > 0:
        # Apply a MaxFilter to dilate the alpha channel (makes the stroke thicker)
        # We separate the alpha channel, dilate it, and merge it back
        r_ch, g_ch, b_ch, a_ch = out_img.split()
        # MaxFilter with size 3 or 5
        dilated_a = a_ch.filter(ImageFilter.MaxFilter(thickness_increase))
        # Smooth it a bit to avoid pixelation
        dilated_a = dilated_a.filter(ImageFilter.GaussianBlur(0.8))
        out_img = Image.merge("RGBA", (r_ch, g_ch, b_ch, dilated_a))
        
    # Crop the image to the bounding box of the logo to remove empty space and center it
    # But wait, keeping it square with some padding is nice.
    # The bounding box is 118, 118, 905, 905.
    # Let's crop it to 100, 100, 924, 924 (824x824) to keep it centered and square.
    cropped_img = out_img.crop((100, 100, 924, 924))
    
    # Save the result
    cropped_img.save(output_path, "PNG")
    print(f"Saved logo to {output_path}")

# Run extraction
input_jpg = r"C:\Users\sandy\.gemini\antigravity-ide\brain\a779162d-ab92-4c84-abaa-61f99cabf731\media__1781007860392.jpg"
output_dir = r"c:\CapitanYA\capitan11.5.2026\assets\images"

# 1. Standard thickness
extract_logo(input_jpg, os.path.join(output_dir, "logo_elguiaya_clean.png"), thickness_increase=0)

# 2. Thicker stroke (dilation size 3)
extract_logo(input_jpg, os.path.join(output_dir, "logo_elguiaya_thick.png"), thickness_increase=3)

# 3. Extra thick stroke (dilation size 5)
extract_logo(input_jpg, os.path.join(output_dir, "logo_elguiaya_extra_thick.png"), thickness_increase=5)

#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont
import math

def create_app_icon():
    # Create a 1024x1024 image with a blue background
    size = 1024
    img = Image.new('RGB', (size, size), color='#007AFF')
    draw = ImageDraw.Draw(img)
    
    # Calculate safe area (80% of icon size)
    safe_area = int(size * 0.8)
    margin = (size - safe_area) // 2
    
    # Create a white circle for the pin background
    circle_center = size // 2
    circle_radius = safe_area // 3
    circle_bbox = [
        circle_center - circle_radius,
        circle_center - circle_radius,
        circle_center + circle_radius,
        circle_center + circle_radius
    ]
    
    # Draw the white circle
    draw.ellipse(circle_bbox, fill='white')
    
    # Create a location pin shape
    pin_width = circle_radius // 2
    pin_height = circle_radius * 1.5
    
    # Pin position (centered, slightly below circle)
    pin_x = circle_center
    pin_y = circle_center + circle_radius // 3
    
    # Draw pin shape (triangle with rounded bottom)
    pin_points = [
        (pin_x, pin_y - pin_height // 2),  # Top point
        (pin_x - pin_width // 2, pin_y + pin_height // 2),  # Bottom left
        (pin_x + pin_width // 2, pin_y + pin_height // 2)   # Bottom right
    ]
    draw.polygon(pin_points, fill='#007AFF')
    
    # Add a small circle at the top of the pin
    dot_radius = pin_width // 4
    dot_bbox = [
        pin_x - dot_radius,
        pin_y - pin_height // 2 - dot_radius,
        pin_x + dot_radius,
        pin_y - pin_height // 2 + dot_radius
    ]
    draw.ellipse(dot_bbox, fill='white')
    
    # Save the icon
    output_path = 'CrossStreets/Assets.xcassets/AppIcon.appiconset/app_icon_new.png'
    img.save(output_path, 'PNG')
    print(f"Created app icon: {output_path}")
    print(f"Size: {size}x{size} pixels")
    print("Safe area: 80% of icon space")

if __name__ == "__main__":
    create_app_icon() 
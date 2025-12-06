#!/usr/bin/env python3
"""
Responsive Video Wallpaper Generator using FFmpeg
Generates 3 responsive versions optimized for BoxFit.contain
Usage: python3 generate_responsive_videos.py input_video.mp4 output_folder/ [--padding-mode blur]
"""

import subprocess
import sys
import os
import argparse
from pathlib import Path

TARGETS = {
    'standard': (1080, 1920),
    'tall': (1080, 2340),
    'extra_tall': (1080, 2400)
}

def check_ffmpeg():
    """Check if FFmpeg is installed."""
    try:
        subprocess.run(['ffmpeg', '-version'], 
                      capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def get_video_info(input_path):
    """Get video dimensions and frame rate."""
    cmd = [
        'ffprobe', '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,r_frame_rate',
        '-of', 'csv=s=x:p=0',
        input_path
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, 
                               text=True, check=True)
        parts = result.stdout.strip().split('x')
        width = int(parts[0])
        height = int(parts[1])
        fps = parts[2].split('/')[0] if len(parts) > 2 else None
        return width, height, fps
    except Exception as e:
        print(f"Error getting video info: {e}")
        return None, None, None

def get_dominant_color(input_path):
    """Detect dominant color from video by extracting middle frame."""
    import tempfile
    
    try:
        # Get video duration
        cmd = [
            'ffprobe', '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            input_path
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        duration = float(result.stdout.strip())
        middle_time = duration / 2
        
        # Extract frame, scale to 1x1, get RGB
        with tempfile.NamedTemporaryFile(suffix='.rgb', delete=False) as temp_file:
            temp_path = temp_file.name
            
        cmd = [
            'ffmpeg', '-ss', str(middle_time),
            '-i', input_path,
            '-vf', 'scale=1:1',
            '-frames:v', '1',
            '-f', 'rawvideo',
            '-pix_fmt', 'rgb24',
            '-y',
            temp_path
        ]
        
        subprocess.run(cmd, capture_output=True, check=True, stderr=subprocess.DEVNULL)
        
        # Read RGB values (3 bytes)
        if os.path.exists(temp_path) and os.path.getsize(temp_path) >= 3:
            with open(temp_path, 'rb') as f:
                rgb = f.read(3)
                hex_color = f"{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"
            os.unlink(temp_path)
            return hex_color
        else:
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            return "000000"
    except Exception:
        return "000000"  # Fallback to black

def generate_video_version(input_path, output_path, target_width, 
                          target_height, padding_mode='blur', keep_audio=False):
    """Generate a responsive video version."""
    orig_width, orig_height, fps = get_video_info(input_path)
    
    if orig_width is None:
        print(f"  ✗ Failed to get video info")
        return False
    
    # Calculate scale
    scale = target_width / orig_width
    scaled_height = int(orig_height * scale)
    
    print(f"  Original: {orig_width}x{orig_height}")
    print(f"  Scaled: {target_width}x{scaled_height}")
    print(f"  Target: {target_width}x{target_height}")
    
    # Build FFmpeg command
    if scaled_height < target_height:
        # Extend canvas
        padding = target_height - scaled_height
        padding_top = padding // 2
        padding_bottom = padding - padding_top
        print(f"  → Extending canvas (adding {padding}px padding, mode: {padding_mode})")
        
        if padding_mode == 'blur':
            vf = (
                f"scale={target_width}:{scaled_height}:"
                f"force_original_aspect_ratio=decrease,"
                f"split[main][blurred];"
                f"[blurred]scale={target_width}:{target_height},boxblur=50[bg];"
                f"[bg][main]overlay=(W-w)/2:(H-h)/2"
            )
        elif padding_mode == 'solid':
            # Solid color padding using dominant video color
            dominant_color = get_dominant_color(input_path)
            print(f"  → Using dominant color: #{dominant_color}")
            vf = (
                f"scale={target_width}:{scaled_height}:"
                f"force_original_aspect_ratio=decrease,"
                f"pad={target_width}:{target_height}:"
                f"(ow-iw)/2:(oh-ih)/2:color=0x{dominant_color}"
            )
        elif padding_mode == 'mirror':
            # Mirror mode: crop top/bottom edges and flip them
            vf = (
                f"scale={target_width}:{scaled_height}:"
                f"force_original_aspect_ratio=decrease,"
                f"split[main][top][bottom];"
                f"[top]crop={target_width}:{padding_top}:0:0,vflip[top_mirror];"
                f"[bottom]crop={target_width}:{padding_bottom}:0:{scaled_height-padding_bottom},vflip[bottom_mirror];"
                f"[top_mirror][main][bottom_mirror]vstack=inputs=3"
            )
        else:  # black
            vf = (
                f"scale={target_width}:{scaled_height}:"
                f"force_original_aspect_ratio=decrease,"
                f"pad={target_width}:{target_height}:"
                f"(ow-iw)/2:(oh-ih)/2:color=black"
            )
            
    elif scaled_height > target_height:
        # Crop from center
        crop_y = (scaled_height - target_height) // 2
        print(f"  → Cropping (removing {scaled_height - target_height}px from center)")
        vf = (
            f"scale={target_width}:-1,"
            f"crop={target_width}:{target_height}:0:{crop_y}"
        )
    else:
        # Perfect fit
        print(f"  → Perfect fit - resizing only")
        vf = f"scale={target_width}:{target_height}"
    
    cmd = [
        'ffmpeg', '-i', input_path,
        '-vf', vf,
        '-c:v', 'libx264',
        '-preset', 'slow',
        '-crf', '18',
        '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart',
        '-y',  # Overwrite
        output_path
    ]
    
    # Add audio handling
    if keep_audio:
        cmd.insert(-1, '-c:a')
        cmd.insert(-1, 'copy')
    else:
        cmd.insert(-1, '-an')  # Strip audio
    
    try:
        subprocess.run(cmd, check=True, 
                     stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL)
        file_size = os.path.getsize(output_path) / (1024 * 1024)  # MB
        print(f"  ✓ Created: {output_path} ({file_size:.2f} MB)")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  ✗ Failed: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description='Generate responsive video wallpaper versions',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Single video
  python3 generate_responsive_videos.py input.mp4 output/ --padding-mode blur
  
  # Preserve audio
  python3 generate_responsive_videos.py input.mp4 output/ --keep-audio
  
  # Batch process all MP4 files in current directory
  for video in *.mp4; do 
    python3 generate_responsive_videos.py "$video" output/ --padding-mode blur
  done
        """
    )
    parser.add_argument('input', help='Input video file')
    parser.add_argument('output_folder', help='Output folder')
    parser.add_argument('--padding-mode', 
                       choices=['blur', 'solid', 'mirror', 'black'],
                       default='blur',
                       help='Padding mode for extended canvases (default: blur)')
    parser.add_argument('--keep-audio', 
                       action='store_true',
                       help='Preserve audio track (default: strip audio)')
    parser.add_argument('--base-name', 
                       help='Base name for output files (default: input filename)')
    
    args = parser.parse_args()
    
    if not check_ffmpeg():
        print("Error: FFmpeg is not installed.")
        print("Install with: brew install ffmpeg (macOS) or apt-get install ffmpeg (Linux)")
        sys.exit(1)
    
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found.")
        sys.exit(1)
    
    os.makedirs(args.output_folder, exist_ok=True)
    
    base_name = args.base_name or Path(args.input).stem
    
    print("=" * 50)
    print(f"Processing: {args.input}")
    print(f"Base name: {base_name}")
    print(f"Padding mode: {args.padding_mode}")
    print(f"Audio: {'Preserved' if args.keep_audio else 'Stripped'}")
    print("=" * 50)
    print()
    
    success = True
    for variant, (width, height) in TARGETS.items():
        output_path = os.path.join(
            args.output_folder, 
            f"{base_name}_{variant}.mp4"
        )
        print(f"Generating {variant} version ({width}x{height})...")
        if not generate_video_version(
            args.input, 
            output_path, 
            width, 
            height,
            args.padding_mode,
            args.keep_audio
        ):
            success = False
        print()
    
    print("=" * 50)
    if success:
        print("✓ Processing complete!")
        print(f"All versions saved to: {args.output_folder}")
    else:
        print("⚠ Some versions may have failed. Check errors above.")
    print("=" * 50)

if __name__ == '__main__':
    main()


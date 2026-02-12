#!/bin/bash
# Screenshot automation script v0.3
# Takes screenshots every 10 seconds and converts them to WEBP format
# Last updated: 2025-04-24

# Create necessary directories
mkdir -p "$HOME/Dropbox/CCTV (private)/Screenshots/WEBP"
mkdir -p "$HOME/Dropbox/CCTV (private)/Screenshots"

# Log file
LOG_FILE="$HOME/Dropbox/CCTV (private)/Screenshots/screenshot_log.txt"
touch "$LOG_FILE"

# Log start
echo "Screenshot service started at $(date)" >> "$LOG_FILE"

# Debug info
echo "Build: v0.3 ($(date +%Y-%m-%d\ %H:%M:%S))" >> "$LOG_FILE"

# Main loop
while true; do
  # Generate timestamp for filename
  CURRENT_DATE=$(date +%Y-%m-%d_%H-%M-%S)
  
  # Paths
  TEMP_PNG="/tmp/screenshot_${CURRENT_DATE}.png"
  WEBP_PATH="$HOME/Dropbox/CCTV (private)/Screenshots/WEBP/screenshot_${CURRENT_DATE}.webp"
  
  # Take screenshot
  screencapture -x "$TEMP_PNG"
  
  # Add debug info if ImageMagick is installed
  if command -v convert >/dev/null 2>&1; then
    convert "$TEMP_PNG" -gravity SouthEast -pointsize 20 -fill white -annotate +10+10 "Build: v0.3 ($(date +%Y-%m-%d\ %H:%M:%S))" "$TEMP_PNG" 2>/dev/null
  fi
  
  # Convert to WEBP format
  sips -s format webp "$TEMP_PNG" --out "$WEBP_PATH" >/dev/null 2>&1
  
  # Log success
  echo "Screenshot taken at $(date)" >> "$LOG_FILE"
  
  # Remove temporary PNG file
  rm "$TEMP_PNG"
  
  # Wait 10 seconds
  sleep 10
done

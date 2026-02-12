-- Screenshot automation script
-- Takes screenshots every 10 seconds and converts them to WEBP format
-- Last updated: 2025-04-24
-- Version: 0.3

on run
	try
		-- Create all necessary directories if they don't exist using absolute paths
		do shell script "mkdir -p $HOME/Dropbox/CCTV\\ \\(private\\)/Screenshots/WEBP"
		do shell script "mkdir -p $HOME/Dropbox/CCTV\\ \\(private\\)/Screenshots"
		
		-- Log file for debugging with absolute path
		set logPath to "$HOME/Dropbox/CCTV\\ \\(private\\)/Screenshots/screenshot_log.txt"
		
		-- Ensure log directory exists and log file is writable
		do shell script "touch " & quoted form of logPath
		
		-- Script location for reference with absolute path
		set scriptLocation to "$HOME/Dropbox/CCTV\\ \\(private\\)/Repos/v0.3\\ \\(2025\\ Danny\\)/screenshot_loop.scpt"
		do shell script "echo 'Screenshot service started at $(date)' >> " & quoted form of logPath
		
		-- Main loop
		repeat
			try
				-- Generate timestamp for filename
				set currentDate to do shell script "date +%Y-%m-%d_%H-%M-%S"
				
				-- Temporary PNG screenshot path
				set tempPngPath to "/tmp/screenshot_" & currentDate & ".png"
				
				-- Final WEBP path with absolute path
				set webpPath to "$HOME/Dropbox/CCTV\\ \\(private\\)/Screenshots/WEBP/screenshot_" & currentDate & ".webp"
				
				-- Take screenshot
				do shell script "screencapture -x " & quoted form of tempPngPath
				
				-- Check if ImageMagick is installed and add debug info to the screenshot (timestamp overlay)
				do shell script "if command -v convert >/dev/null 2>&1; then convert " & quoted form of tempPngPath & " -gravity SouthEast -pointsize 20 -fill white -annotate +10+10 'Build: v0.3 ($(date +%Y-%m-%d\\ %H:%M:%S))' " & quoted form of tempPngPath & " 2>/dev/null; fi"
				
				-- Convert to WEBP format
				do shell script "sips -s format webp " & quoted form of tempPngPath & " --out " & webpPath
				
				-- Remove temporary PNG file
				do shell script "rm " & quoted form of tempPngPath
				
				-- Log success
				do shell script "echo 'Screenshot taken at $(date)' >> " & quoted form of logPath
				
				-- Wait 10 seconds
				delay 10
			on error errMsg
				-- Log error and continue
				do shell script "echo 'Error at $(date): " & errMsg & "' >> " & quoted form of logPath
				delay 10 -- Still wait before trying again
			end try
		end repeat
	on error errMsg
		-- Log fatal error
		do shell script "echo 'FATAL ERROR at $(date): " & errMsg & "' >> " & quoted form of logPath
	end try
end run

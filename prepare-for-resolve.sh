#!/bin/bash
# Prepare footage for DaVinci Resolve on Linux
# Remuxes AAC audio to PCM — video stream is untouched (fast)
# Creates new _resolve.mov files, originals are never modified

CONVERTED=0
SKIPPED=0

for f in *.mp4 *.MP4 *.mov *.MOV *.mkv *.MKV; do
    # Skip if no files match
    [ -f "$f" ] || continue
    
    # Skip files already converted
    [[ "$f" == *"_resolve"* ]] && continue
    
    OUTPUT="${f%.*}_resolve.mov"
    
    echo "Converting: $f → $OUTPUT"
    ffmpeg -i "$f" -c:v copy -c:a pcm_s24le "$OUTPUT" -y -loglevel warning
    
    if [ $? -eq 0 ]; then
        echo "✓ Done: $OUTPUT"
        ((CONVERTED++))
    else
        echo "✗ Failed: $f"
        ((SKIPPED++))
    fi
done

echo ""
echo "Conversion complete: $CONVERTED converted, $SKIPPED failed"
echo "Import the *_resolve.mov files into DaVinci Resolve"

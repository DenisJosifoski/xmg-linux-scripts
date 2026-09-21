#!/usr/bin/env bash
# ============================================================
# Prepare footage for DaVinci Resolve on Linux
# Remuxes AAC audio to PCM — video stream is untouched (lossless & fast)
# Creates new _resolve.mov files, originals are never modified
# Supports Dolphin context menu (%F) and direct terminal execution
# ============================================================

set -u

notify() {
    local title="$1"
    local msg="$2"
    local urgency="${3:-normal}"
    local icon="${4:-video-x-generic}"
    if command -v notify-send &>/dev/null; then
        notify-send -a "DaVinci Resolve" -u "$urgency" -i "$icon" "$title" "$msg"
    fi
}

# Check for ffmpeg
if ! command -v ffmpeg &>/dev/null; then
    echo "❌ Error: ffmpeg is not installed."
    notify "Error" "ffmpeg is not installed. Run: sudo dnf install -y ffmpeg" "critical" "dialog-error"
    exit 1
fi

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
    targets=(".")
fi

# Supported extensions check
is_supported_video() {
    local f="$1"
    case "${f,,}" in
        *.mp4|*.mov|*.mkv|*.m4v|*.avi|*.webm|*.ts)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

declare -a files_to_process=()

for target in "${targets[@]}"; do
    if [ -d "$target" ]; then
        while IFS= read -r -d '' item; do
            filename=$(basename "$item")
            # Skip files that are already converted
            if [[ "$filename" == *"_resolve.mov"* ]] || [[ "$filename" == *"_pcm.mov"* ]]; then
                continue
            fi
            if is_supported_video "$item"; then
                files_to_process+=("$item")
            fi
        done < <(find "$target" -maxdepth 1 -type f -print0 | sort -z)
    elif [ -f "$target" ]; then
        filename=$(basename "$target")
        if [[ "$filename" == *"_resolve.mov"* ]] || [[ "$filename" == *"_pcm.mov"* ]]; then
            echo "Skipping already converted file: $filename"
            continue
        fi
        if is_supported_video "$target"; then
            files_to_process+=("$target")
        fi
    fi
done

total_count=${#files_to_process[@]}

if [ "$total_count" -eq 0 ]; then
    echo "No compatible video files found to convert."
    notify "Prepare for Resolve" "No compatible video files found to convert." "normal" "dialog-information"
    exit 0
fi

if [ "$total_count" -eq 1 ]; then
    notify "Prepare for Resolve" "Converting $(basename "${files_to_process[0]}") (AAC → PCM)..."
else
    notify "Prepare for Resolve" "Converting ${total_count} video(s) (AAC → PCM)..."
fi

echo "Found ${total_count} video file(s) to process."

success_count=0
fail_count=0

for file in "${files_to_process[@]}"; do
    dir=$(dirname "$file")
    filename=$(basename "$file")
    stem="${filename%.*}"
    output="${dir}/${stem}_resolve.mov"

    echo "Converting: $filename → ${stem}_resolve.mov"

    if ffmpeg -hide_banner -loglevel error -y -i "$file" \
        -map 0:v -map 0:a? \
        -c:v copy \
        -c:a pcm_s16le \
        "$output"; then
        echo "✓ Done: ${stem}_resolve.mov"
        ((success_count++))
    else
        echo "✗ Failed: $filename"
        ((fail_count++))
    fi
done

echo ""
echo "Conversion complete: $success_count converted, $fail_count failed"

if [ "$fail_count" -eq 0 ]; then
    notify "Prepare for Resolve" "Finished! Converted ${success_count} video(s) to PCM." "normal" "dialog-information"
else
    notify "Prepare for Resolve" "Completed with issues: ${success_count} succeeded, ${fail_count} failed." "critical" "dialog-warning"
fi

#!/usr/bin/env bash
# auto_brightness.sh — Reads ambient lux and sets brightness via kscreen-doctor (Optimized)

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
SENSOR_PATH="/sys/bus/iio/devices/iio:device0/in_illuminance_raw"
LUX_MAX=500             # Lux level for maximum brightness
BRIGHTNESS_MIN=10       # Minimum brightness percentage
BRIGHTNESS_MAX=100      # Maximum brightness percentage
BRIGHTNESS_THRESHOLD=5  # Minimum change required to trigger update
INTERVAL=5              # Polling interval in seconds

# ── State & Cache Variables ──────────────────────────────────────────────────
LAST_SET_BRIGHTNESS=-1
CACHED_OUTPUTS=()

# ── Logic ────────────────────────────────────────────────────────────────────

# Brief buffer for system components to settle on boot
sleep 5

log() {
  echo "$(date '+%H:%M:%S') - $*" >&2
}

warn() {
  log "WARN: $*"
}

error() {
  log "ERROR: $*"
}

check_sensor() {
  if [[ ! -r "$SENSOR_PATH" ]]; then
    error "Sensor not found or not readable at $SENSOR_PATH"
    exit 1
  fi
}

kscreen_qt_platform() {
  if [[ -n "${QT_QPA_PLATFORM:-}" ]]; then
    printf '%s' "$QT_QPA_PLATFORM"
  elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'wayland'
  elif [[ -n "${DISPLAY:-}" ]]; then
    printf 'xcb'
  else
    printf 'offscreen'
  fi
}

run_kscreen_doctor() {
  env QT_QPA_PLATFORM="$(kscreen_qt_platform)" kscreen-doctor "$@"
}

init_display_cache() {
  local output_lines
  if ! output_lines=$(run_kscreen_doctor -o 2>/dev/null); then
    return 1
  fi

  local outputs=()
  mapfile -t outputs < <(printf '%s\n' "$output_lines" | awk '/Output: /{print $3}')

  if [[ ${#outputs[@]} -eq 0 || -z "${outputs[0]:-}" ]]; then
    return 1
  fi

  CACHED_OUTPUTS=("${outputs[@]}")
  return 0
}

update_brightness() {
  # Ensure display environment is cached before moving forward
  if [[ ${#CACHED_OUTPUTS[@]} -eq 0 ]]; then
    if ! init_display_cache; then
      # Display server isn't ready yet, quietly back off until next interval
      return 0
    fi
  fi

  local samples=5
  local sum=0
  local reading=0
  local raw_lux
  local target_brightness

  for ((i=0; i<samples; i++)); do
    if ! reading=$(cat "$SENSOR_PATH" 2>/dev/null); then
      return 1
    fi
    [[ "$reading" =~ ^[0-9]+$ ]] || return 1
    sum=$((sum + reading))
    sleep 0.05
  done

  raw_lux=$((sum / samples))

  target_brightness=$(awk -v lux="$raw_lux" -v mx="$LUX_MAX" -v b_min="$BRIGHTNESS_MIN" -v b_max="$BRIGHTNESS_MAX" 'BEGIN {
    v = (lux < 0) ? 0 : (lux > mx) ? mx : lux
    ratio = log(v + 1) / log(mx + 1)
    b = ratio * (b_max - b_min) + b_min
    printf "%d", int(b + 0.5)
  }')

  # If the ambient light hasn't significantly changed, exit
  if [[ "$LAST_SET_BRIGHTNESS" -ne -1 ]]; then
    local delta=$(( target_brightness - LAST_SET_BRIGHTNESS ))
    local abs_delta=${delta#-}

    if [[ "$abs_delta" -lt "$BRIGHTNESS_THRESHOLD" ]]; then
      return 0
    fi
  fi

  local success=false
  for name in "${CACHED_OUTPUTS[@]}"; do
    if [[ -z "$name" ]]; then 
      continue
    fi
    
    if run_kscreen_doctor output."$name".brightness."$target_brightness" > /dev/null 2>&1; then
      echo "$(date '+%H:%M:%S') - $name: → ${target_brightness}% (Lux avg: ${raw_lux})"
      success=true
    else
      warn "Failed to set brightness for $name. Clearing cache to re-detect on next loop."
      CACHED_OUTPUTS=() # Wipe cache so it re-detects displays if a monitor was unplugged
    fi
  done

  if [[ "$success" = true ]]; then
    LAST_SET_BRIGHTNESS="$target_brightness"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
check_sensor
# If started very early during boot the display environment may not be ready.
# If `kscreen_qt_platform` returns "offscreen" here, wait a short while and
# exit so that systemd can restart this service when the display server is
# available.
display_platform="$(kscreen_qt_platform)"
if [[ "$display_platform" = "offscreen" ]]; then
  sleep 5
  error "Display server not ready (QT_QPA_PLATFORM=offscreen). Exiting."
  exit 1
fi
trap "exit" SIGINT SIGTERM

while true; do
  update_brightness || true
  sleep "$INTERVAL"
done
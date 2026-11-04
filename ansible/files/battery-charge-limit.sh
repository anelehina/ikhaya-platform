#!/bin/sh
# Sets the battery charge limit, if the hardware supports it.
# The setting only appears once the laptop's driver has attached to the
# battery, which can be a moment after this runs at boot. So wait for it
# instead of giving up at once. Exits 0 on hardware without the setting,
# so an unsupported machine isn't reported as failed.
set -eu

limit=80
file=/sys/class/power_supply/BAT0/charge_control_end_threshold
waited=0

while [ ! -e "$file" ]; do
  if [ "$waited" -ge 60 ]; then
    echo "battery-charge-limit: not supported here, nothing to do"
    exit 0
  fi
  sleep 1
  waited=$((waited + 1))
done

echo "$limit" > "$file"
now=$(cat "$file")
if [ "$now" != "$limit" ]; then
  echo "battery-charge-limit: FAILED, limit reads $now" >&2
  exit 1
fi
echo "battery-charge-limit: set to $now after waiting ${waited}s"

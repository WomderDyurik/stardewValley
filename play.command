#!/bin/zsh
set -eu
project_dir="${0:A:h}"
for godot_bin in "/Applications/Godot.app/Contents/MacOS/Godot" "${HOME}/Applications/Godot.app/Contents/MacOS/Godot" "/private/tmp/planta2-tools/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$godot_bin" ]]; then
    exec "$godot_bin" --path "$project_dir"
  fi
done
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$project_dir"
fi
print "Установите Godot 4 (Standard) с https://godotengine.org/download/macos/ и откройте project.godot."
read -r "reply?Нажмите Enter, чтобы закрыть окно. "

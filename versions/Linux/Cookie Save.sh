#!/bin/sh
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
html="$dir/Cookie Save.html"
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$html"
else
  printf '%s\n' "Open this file in Chrome: $html"
fi

#!/bin/sh
# Remove the old release directories below the given path.
dir="$1"
if [ -d "$dir" ]; then
  for old in "$dir"/release-*; do
    rm -rf "$old"
  done

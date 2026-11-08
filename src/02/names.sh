#!/usr/bin/env bash

make_stem() {
  local letters=$1 min_length=$2 extra=$3
  local repeats=$((min_length - ${#letters}))
  local prefix="" i
  (( repeats < 0 )) && repeats=0
  repeats=$((repeats + extra))

  for ((i = 0; i < repeats; i++)); do
    prefix+=${letters:0:1}
  done
  printf '%s%s' "$prefix" "$letters"
}

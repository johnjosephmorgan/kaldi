#!/usr/bin/env bash

overlap=20

for r in out_diarized/work/*; do
  for s in $r/audio_threshold/*; do
    for w in $s/*; do
      local/make_silent_buffer_file.pl \
        $w \
        $overlap
    done
  done
done

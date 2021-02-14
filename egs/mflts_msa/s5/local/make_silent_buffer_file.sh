#!/usr/bin/env bash
overlap=20
for r in out_diarized/work/*; do
  for w in $r/*; do
    local/make_silent_buffer_file.pl \
      $w \
      out_diarized/tmp/samples.txt \
      $overlap
  done
done

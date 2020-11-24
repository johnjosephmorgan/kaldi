#!/bin/bash
for x in test train; do
    echo "$0: Working on $x."
  cut -d " " -f 1 data/$x/text > fn$$
  cut -d " " -f 2- data/train/text > text$$
  local/gale/buckwalter2unicode.py -i text$$ -o text_bw$$
  paste -d " " fn$$ text_bw$$ > data/$x/text
  rm text$$ text_bw$$ fn$$
done


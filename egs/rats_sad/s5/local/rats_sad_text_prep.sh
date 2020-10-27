#!/usr/bin/env bash

# Copyright 2020 ARL (Author: John Morgan)

if [ $# -ne 1 ]; then
  echo "Usage: $0 <rats_sad_dir>
  echo "$0 <rats_sad_dir>"
  echo "<rats_sad_dir>: Source data location"
  echo "For example:"
  echo "$0 /mnt/corpora/LDC2015S02/RATS_SAD/data"
echo "Output is written to data/local/annotations/{train,dev-1,dev-2}."
  exit 1;
fi

set -eux
dir=$1

mkdir -p data/local/annotations

for fld in train dev-1 dev-2; do
  find $dir/$fld/sad -type f -name "*.tab" | xargs cat > data/local/annotations/$fld.txt
done

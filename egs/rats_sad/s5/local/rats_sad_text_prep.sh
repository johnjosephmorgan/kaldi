#!/usr/bin/env bash

# Copyright 2020 ARL (Author: John Morgan)

if [ $# -ne 1 ]; then
  echo "Usage: $0 <rats_sad_dir> <output_dir>"
  echo "$0 <rats_sad_dir>"
  echo "<rats_sad_dir>: Source data location"
  echo "For example:"
  echo "$0 /mnt/corpora/LDC2015S02/RATS_SAD/data data/local/downloads"
  exit 1;
fi

set -eux
dir=$1
dev_1_dir=$dir/dev-1/sad
dev_2_dir=$dir/dev-2/sad
train_dir=$dir/train/sad

mkdir -p data/local/annotations

find $train_dir -type f -name "*.tab" | xargs cat > data/local/annotations/train.txt
find $dev_1_dir -type f -name "*.tab" | xargs cat > data/local/annotations/dev.txt
find $dev_2_dir -type f -name "*.tab" | xargs cat > data/local/annotations/eval.txt

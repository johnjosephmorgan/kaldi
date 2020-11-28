#!/usr/bin/env bash
. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set -u

read_appen_train_2005_audio_dir=$1
read_appen_train_2006_audio_dir=$2
ma_train_audio_dir=$3

tmpdir=data/local/tmp
transtac_tmpdir=$tmpdir/transtac
tmp_read_appen_train_2005_dir=$transtac_tmpdir/train/read/appen/2005
tmp_read_appen_train_2006_dir=$transtac_tmpdir/train/read/appen/2006
tmp_train_ma_dir=$transtac_tmpdir/train/read/ma/2006

if [ $stage -le 0 ]; then
  echo "$0: Getting a list of the  TRANSTAC read 2005 training .wav files."
  mkdir -p $tmp_read_appen_train_2005_dir/lists
  for i in $(seq 21); do
    echo "$0: Processing part $i of 21."
    find "$read_appen_train_2005_audio_dir/AllAudio${i}/Audio" -type f -name "*.wav" >> \
      $tmp_read_appen_train_2005_dir/wav_list.txt
  done
fi

if [ $stage -le 1 ]; then
  echo "$0: Getting a list of the  TRANSTAC Read 2006 training .wav files."
  mkdir -p $tmp_read_appen_train_2006_dir/lists
  find "$read_appen_train_2006_audio_dir" -type f -name "*.wav" > \
    $tmp_read_appen_train_2006_dir/wav_list.txt
fi

if [ $stage -le 4 ]; then
  echo "$0: Getting a list of the  TRANSTAC Marine Acoustics training .wav files."
  mkdir -p $tmp_train_ma_dir/lists
  find "$ma_train_audio_dir" -type f -name "*.wav" > $tmp_train_ma_dir/wav_list.txt
fi

exit0

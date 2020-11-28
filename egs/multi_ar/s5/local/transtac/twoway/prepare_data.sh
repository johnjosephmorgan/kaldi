#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

twoway_appen_2006_train_audio_dir=$1
twoway_appen_2006_train_txt_dir=$2
twoway_appen_2007_train_audio_dir=$3
twoway_appen_2007_train_txt_dir=$4
detroit_train_audio_dir=$5
detroit_train_txt_dir=$6
dli_train_audio_dir=$7
dli_train_txt_dir=$8
nist_train_audio_dir=$9
nist_train_txt_dir=$10
pendleton_train_audio_dir=$11
pendleton_train_txt_dir=$12
san_diego_train_audio_dir=13
san_diego_train_txt_dir=14

tmpdir=data/local/tmp
transtac_tmpdir=$tmpdir/transtac
tmp_twoway_appen_train_2006_dir=$transtac_tmpdir/train/twoway/appen/2006
tmp_twoway_appen_train_2007_dir=$transtac_tmpdir/train/twoway/appen/2007
tmp_twoway_detroit_train_2006_dir=$transtac_tmpdir/train/twoway/detroit/2006
tmp_twoway_dli_train_2006_dir=$transtac_tmpdir/train/twoway/dli/2006
tmp_twoway_nist_train_2007_dir=$transtac_tmpdir/train/twoway/nist/2007
tmp_twoway_pendleton_train_2005_dir=$transtac_tmpdir/train/twoway/pendleton/2005
tmp_twoway_san_diego_train_2006_dir=$transtac_tmpdir/train/twoway/san_diego/2006

if [ $stage -le 0 ]; then
  echo "$0: Getting a list of the  TRANSTAC 2way  2006 training .wav files."
  mkdir -p $tmp_twoway_appen_train_2006_dir/lists
  find "$twoway_appen_2006_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_appen_train_2006_dir/wav_files.txt
fi

if [ $stage -le 1 ]; then
  echo "$0: Getting a list of the TRANSTAC 2way 2006 training transcript files."
  find "$twoway_appen_2006_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_appen_train_2006_dir/tdf_files.txt
fi

if [ $stage -le 2 ]; then
  echo "$0: Getting a list of the  TRANSTAC 2way appen 2007 training .wav files."
  mkdir -p $tmp_twoway_appen_train_2007_dir/lists
  find "$twoway_appen_2007_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_appen_train_2007_dir/wav_files.txt
fi

if [ $stage -le 3 ]; then
  echo "$0: Getting a list of the TRANSTAC 2way 2007 training transcript files."
  find "$twoway_appen_2007_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_appen_train_2007_dir/tdf_files.txt
fi

if [ $stage -le 4 ]; then
  echo "$0: Getting a list of the  DETROIT 2way 2006 training .wav files."
  mkdir -p $tmp_twoway_detroit_train_2006_dir/lists
  find "$detroit_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_detroit_train_2006_dir/wav_files.txt
fi

if [ $stage -le 5 ]; then
  echo "$0: Getting a llist of the TRANSTAC DETROIT 2006 2way training transcript files."
  find "$detroit_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_detroit_train_2006_dir/tdf_files.txt
fi

if [ $stage -le 6 ]; then
  echo "$0: Getting a list of the  TRANSTAC DLI 2006 training .wav files."
  mkdir -p $tmp_twoway_dli_train_2006_dir/lists
  find "$dli_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_dli_train_2006_dir/wav_files.txt
fi

if [ $stage -le 7 ]; then
  echo "$0: Getting a list of the TRANSTAC Iraqi Arabic DLI 2006 training transcript files."
  find "$dli_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_dli_train_2006_dir/tdf_files.txt
fi

if [ $stage -le 8 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi ARABIC NIST 2way 2007 training .wav files."
  mkdir -p $tmp_twoway_nist_train_2007_dir/lists
  find "$nist_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_nist_train_2007_dir/wav_files.txt
fi

if [ $stage -le 9 ]; then
  echo "$0: Getting a list of the TRANSTAC Iraqi Arabic NIST 2way 2007 training transcript files."
  find "$nist_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_nist_train_2007_dir/tdf_files.txt
fi

if [ $stage -le 10 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi Arabic Camp Pendleton 2way 2005 training .wav files."
  mkdir -p $tmp_twoway_pendleton_train_2005_dir/lists
  find "$pendleton_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_pendleton_train_2005_dir/wav_files.txt
fi

if [ $stage -le 11 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi Arabic Camp Pendleton 2way transcript .txt files."
  find "$pendleton_train_txt_dir" -type f -name "*.txt" > \
    $tmp_twoway_pendleton_train_2005_dir/tdf_files.txt
fi

if [ $stage -le 12 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi Arabic San  Diego 2006 2way training .wav files."
  mkdir -p $tmp_twoway_san_diego_train_2006_dir/lists
  find "$san_diego_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_san_diego_train_2006_dir/wav_files.txt
fi

if [ $stage -le 13 ]; then
  echo "$0: Getting a list of the TRANSTAC Iraqi Arabic San Diego 2006 2way training transcript files."
  find "$san_diego_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_san_diego_train_2006_dir/tdf_files.txt
fi

exit 0

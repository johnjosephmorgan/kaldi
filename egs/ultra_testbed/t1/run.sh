#!/usr/bin/env bash

# This recipe runs a decoder test on recordings in the following directory:
$datadir=$PWD/Libyan_msa_arl
speakers=(adel anwar bubaker hisham mukhtar redha srj yousef)
. ./path.sh
stage=0
. utils/parse_options.sh


if [ "$#" != "1" ]; then
  echo "USAGE: $0 <DIRECTORY>"
  echo "<DIRECTORY should contain models and  other resources."
  echo "For example:"
  echo "$0 exp/multi_tamsa_librispeech_tamsa"
exit 1
fi

src=$1

# Check that resources exist
for f in HCLG.fst final.mdl tree words.txt; do
  echo "Checking $f." 
  [ ! -f $src/$f ] && echo "$f is missing." && exit 1;
done

if [ $stage -le 0 ]; then
  for s in ${speakers[@]}; do
  echo "Making kaldi directory for $s."
  mkdir -vp data/$s
  find Libyan_msa_arl -type f -name "*${s}*.wav" | sort > \
    data/$s/recordings_wav.txt

  local/test_recordings_make_lists.pl \
    Libyan_msa_arl/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan \
    || exit 1;
  utils/utt2spk_to_spk2utt.pl data/$s/utt2spk | sort > \
      data/$s/spk2utt || exit 1;
  done
fi
exit
if [ $stage -le 1 ]; then
  for s in adel anwar bubaker hisham mukhtar redha  srj yousef; do
    echo "Extract features for $s."
    steps/make_mfcc.sh data/$s/recordings
  done
fi

if [ $stage -le 2 ]; then
  mkdir -vp data/test
  for s in adel anwar bubaker hisham mukhtar redha  srj yousef; do
    echo "Concatenate $s spk2utt, text, utt2spk and wav.scp in test directory."
    for f in spk2utt utt2spk text wav.scp; do
      cat data/$s/recordings/$f >> data/test/$f
    done
  done
fi

if [ $stage -le 3 ]; then
  for s in adel anwar bubaker hisham mukhtar redha  srj yousef; do
    echo "Decoding $s."
    mkdir -p exp/$src/decode_online/$s/log
    run.pl exp/$src/decode_online/$s/log/decode.log \
      online2-wav-nnet3-latgen-faster \
        --acoustic-scale=1.0 \
        --beam=15.0 \
        --config=conf/online.conf \
        --do-endpointing=false \
        --extra-left-context-initial=0 \
        --frame-subsampling-factor=3 \
        --frames-per-chunk=20 \
        --lattice-beam=4.0 \
        --max-active=7000 \
        --min-active=200 \
        --online=true \
        --word-symbol-table=exp/$src/words.txt \
        exp/$src/final.mdl \
        exp/$src/HCLG.fst \
        ark:data/$s/recordings/spk2utt \
        "ark,s,cs:wav-copy scp,p:data/$s/recordings/wav.scp ark:- |" \
        "ark:|lattice-scale --acoustic-scale=1.0 ark:- ark,t:- > exp/$src/decode_online/$s/lat.txt"
  done
fi

if [ $stage -le 4 ]; then
  for s in adel anwar bubaker hisham mukhtar redha  srj yousef; do
    echo "Concatenating lattice for $s."
    cat exp/$src/decode_online/$s/lat.txt >> exp/$src/decode_online/lat.1
  done
  if [ -f exp/$src/decode_online/lat.1.gz ]; then
    rm exp/$src/decode_online/lat.1.gz
  fi
  gzip exp/$src/decode_online/lat.1
fi

if [ $stage -le 5 ]; then
  ./steps/scoring/score_kaldi_wer.sh --cmd run.pl data/test exp/$src \
    exp/$src/decode_online
fi
exit 0


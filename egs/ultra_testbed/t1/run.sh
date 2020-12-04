#!/usr/bin/env bash

src=$1

. ./path.sh

mkdir -p data/test

for s in adel anwar bubaker hisham mukhtar redha  srj yousef; do
  mkdir -p data/$s
  find Libyan_msa_arl -type f -name "*${s}*.wav" | sort > \
    data/$s/recordings_wav.txt

  local/test_recordings_make_lists.pl \
      Libyan_msa_arl/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan

  steps/make_mfcc.sh data/$s/recordings

  utils/utt2spk_to_spk2utt.pl data/$s/recordings/utt2spk | sort > \
    data/$s/recordings/spk2utt

  for f in spk2utt utt2spk text wav.scp; do
    cat data/$s/recordings/$f >> data/test/$f
  done

  mkdir -p exp/$src/decode_online/$s

  online2-wav-nnet3-latgen-faster \
    --do-endpointing=false \
    --frames-per-chunk=20 \
    --extra-left-context-initial=0 \
    --online=true \
    --frame-subsampling-factor=3 \
    --config=conf/online.conf \
    --min-active=200 \
    --max-active=7000 \
    --beam=15.0 \
    --lattice-beam=6.0 \
    --acoustic-scale=1.0 \
    --word-symbol-table=exp/$src/words.txt \
    exp/$src/final.mdl \
    exp/$src/HCLG.fst \
    ark:data/$s/recordings/spk2utt \
    "ark,s,cs:wav-copy scp,p:data/$s/recordings/wav.scp ark:- |" \
    "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark,t:- > exp/$src/decode_online/$s/lat.txt"

  cat exp/$src/decode_online/$s/lat.txt >> exp/$src/decode_online/lat.1
done

gzip exp/$src/decode_online/lat.1

./steps/scoring/score_kaldi_wer.sh --cmd run.pl data/test exp/$src \
  exp/$src/decode_online
exit 0


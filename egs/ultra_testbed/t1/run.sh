#!/usr/bin/env bash

# This recipe runs a decoder test on recordings in the following directory:

# Start setting configuration variables and parameters
datadir=$PWD/Libyan_msa_arl
speakers=(adel anwar bubaker hisham mukhtar redha srj yousef)
acoustic_scale=0.1
beam=1.0
do_endpointing=false
extra_left_context_initial=0
frame_subsampling_factor=3
frames_per_chunk=50
lattice_beam=1.0
max_active=2147483647
min_active=200
online=true
# Finished setting variables and parameters
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
for f in HCLG.fst final.mdl words.txt; do
  echo "Checking $f." 
  [ ! -f $src/$f ] && echo "$f is missing." && exit 1;
done

if [ $stage -le 0 ]; then
  for s in ${speakers[@]}; do
  echo "Making kaldi directory for $s."
  mkdir -vp data/$s
  find $datadir -type f -name "*${s}*.wav" | sort > \
    data/$s/recordings_wav.txt

  local/test_recordings_make_lists.pl \
    $datadir/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan \
    || exit 1;
  utils/utt2spk_to_spk2utt.pl data/$s/utt2spk | sort > \
      data/$s/spk2utt || exit 1;
  done
fi

# Extract Mel Frequency Cepstral Coefficients from input recordings
if [ $stage -le 1 ]; then
  for s in ${speakers[@]}; do
  echo "Extract features for $s."
    steps/make_mfcc.sh data/$s
  done
fi

# Combin directories into 1 test directory. This is probably unnecessary.
if [ $stage -le 2 ]; then
  utils/combine_data.sh data/test data/adel data/anwar data/bubaker data/hisham \
    data/mukhtar data/redha data/srj data/yousef
fi

# Run the kaldi decoder
if [ $stage -le 3 ]; then
  for s in ${speakers[@]}; do
    echo "Decoding $s."
    mkdir -p $src/decode_online/$s/log
    run.pl $src/decode_online/$s/log/decode.log \
      online2-wav-nnet3-latgen-faster \
        --acoustic-scale=$acoustic_scale \
        --beam=$beam \
        --config=$src/conf/online.conf \
        --do-endpointing=$do_endpointing \
        --extra-left-context-initial=$extra_left_context_initial \
        --frame-subsampling-factor=$frame_subsampling_factor \
        --frames-per-chunk=$frames_per_chunk \
	--ivector-extraction-config=$src/conf/ivector_extractor.conf \
        --lattice-beam=$lattice_beam \
        --max-active=$max_active \
        --min-active=$min_active \
        --online=$online \
        --word-symbol-table=$src/words.txt \
        $src/final.mdl \
        $src/HCLG.fst \
        ark:data/$s/spk2utt \
        "ark,s,cs:wav-copy scp,p:data/$s/wav.scp ark:- |" \
        "ark:|lattice-scale --acoustic-scale=1.0 ark:- ark,t:- > $src/decode_online/$s/lat.txt"
  done
fi

# Concatenate output lattices
if [ $stage -le 4 ]; then
  for s in ${speakers[@]}; do
    echo "Concatenating lattice for $s."
    cat $src/decode_online/$s/lat.txt >> $src/decode_online/lat.1
  done
  # Remove old zip lat file
  if [ -f $src/decode_online/lat.1.gz ]; then
    rm $src/decode_online/lat.1.gz
  fi
  # zip new lat file
  gzip $src/decode_online/lat.1
fi

# Run scoring
if [ $stage -le 5 ]; then
  ./steps/scoring/score_kaldi_wer.sh --cmd run.pl data/test $src \
    $src/decode_online
fi
exit 0


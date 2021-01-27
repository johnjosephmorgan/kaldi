#!/usr/bin/env bash

# This recipe runs a decoder test on recordings in the following directory:

# Start setting configuration variables and parameters
datadir=$PWD/Libyan_msa_arl
speakers=(adel anwar bubaker hisham mukhtar redha srj yousef)
acoustic_scale=0.1 #  Scaling factor for acoustic log-likelihoods (float, default = 0.1)
add_pitch=false  #  Append pitch features to raw MFCC/PLP/filterbank features [but not for iVector extraction] (bool, default = false)
beam=16.0 # Decoding beam.  Larger->slower, more accurate. (float, default = 16)
beam_delta=0.5 # Increment used in decoding-- this parameter is obscure and relates to a speedup in the way the max-active constraint is applied.  Larger is more accurate. (float, default = 0.5)
do_endpointing=false
extra_left_context_initial=0
frame_subsampling_factor=3
frames_per_chunk=20
lattice_beam=1.0
max_active=7000
min_active=200
online=true
lat_acoustic_scale=1.0 #acoustic-scale            : Scaling factor for acoustic likelihoods (float, default = 1)
acoustic2lm_scale=0.0 # Add this times original acoustic costs to LM costs (float, default = 0)
inv_acoustic_scale=1.0 # An alternative way of setting the acoustic scale: you can set its inverse. (float, default =1)
lm_scale=1.0 # Scaling factor for graph/lm costs (float, default = 1)
lm2acoustic_scale=0.0 #        : Add this times original LM costs to acoustic costs (float, default = 0)
write_compact=true # If true, write in normal (compact) form. (bool, default = true)
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
        --add-pitch=$add_pitch \
        --beam=$beam \
        --beam-delta=$beam_delta \
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
        "ark:|lattice-scale \
          --acoustic-scale=$lat_acoustic_scale \
          --acoustic2lm-scale=$acoustic2lm_scale          \
          --inv-acoustic-scale=$inv_acoustic_scale \
          --lm-scale=$lm_scale \
          --lm2acoustic-scale=$lm2acoustic_scale \
          --write-compact=$write_compact              \
        ark:- ark,t:- > $src/decode_online/$s/lat.txt"
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



  --chunk-length              : Length of chunk size in seconds, that we process.  Set to <= 0 to use all input in one chunk. (float, default = 0.18)
  --cmvn-config               : Configuration file for online cmvn features (e.g. conf/online_cmvn.conf). Controls features on nnet3 input (not ivector features). If not set, the OnlineCmvn is disabled. (string, default = "")
  --computation.debug         : If true, turn on debug for the neural net computation (very verbose!) Will be turned on regardless if --verbose >= 5 (bool, default = false)
  --debug-computation         : If true, turn on debug for the actual computation (very verbose!) (bool, default = false)
  --delta                     : Tolerance used in determinization (float, default = 0.000976562)
  --determinize-lattice       : If true, determinize the lattice (lattice-determinization, keeping only best pdf-sequence for each word-sequence). (bool, default = true)
  --do-endpointing            : If true, apply endpoint detection (bool, default = false)
  --endpoint.rule1.max-relative-cost : This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
  --endpoint.rule1.min-trailing-silence : This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 5)
  --endpoint.rule1.min-utterance-length : This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
  --endpoint.rule1.must-contain-nonsilence : If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = false)
  --endpoint.rule2.max-relative-cost : This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = 2)
  --endpoint.rule2.min-trailing-silence : This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 0.5)
  --endpoint.rule2.min-utterance-length : This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
  --endpoint.rule2.must-contain-nonsilence : If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
  --endpoint.rule3.max-relative-cost : This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = 8)
  --endpoint.rule3.min-trailing-silence : This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 1)
  --endpoint.rule3.min-utterance-length : This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
  --endpoint.rule3.must-contain-nonsilence : If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
  --endpoint.rule4.max-relative-cost : This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
  --endpoint.rule4.min-trailing-silence : This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 2)
  --endpoint.rule4.min-utterance-length : This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
  --endpoint.rule4.must-contain-nonsilence : If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
  --endpoint.rule5.max-relative-cost : This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
  --endpoint.rule5.min-trailing-silence : This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 0)
  --endpoint.rule5.min-utterance-length : This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 20)
  --endpoint.rule5.must-contain-nonsilence : If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = false)
  --endpoint.silence-phones   : List of phones that are considered to be silence phones by the endpointing code. (string, default = "")
  --extra-left-context-initial : Extra left context to use at the first frame of an utterance (note: this will just consist of repeats of the first frame, and should not usually be necessary. (int, default = 0)
  --fbank-config              : Configuration file for filterbank features (e.g. conf/fbank.conf) (string, default = "")
  --feature-type              : Base feature type [mfcc, plp, fbank] (string, default = "mfcc")
  --frame-subsampling-factor  : Required if the frame-rate of the output (e.g. in 'chain' models) is less than the frame-rate of the original alignment. (int, default = 1)
  --frames-per-chunk          : Number of frames in each chunk that is separately evaluated by the neural net.  Measured before any subsampling, if the --frame-subsampling-factor options is used (i.e. counts input frames.  This is only advisory (may be rounded up if needed. (int, default = 20)
  --global-cmvn-stats         : filename with global stats for OnlineCmvn for features on nnet3 input (not ivector features) (string, default = "")
  --hash-ratio                : Setting used in decoder to control hash behavior (float, default = 2)
  --ivector-extraction-config : Configuration file for online iVector extraction, see class OnlineIvectorExtractionConfig in the code (string, default = "")
  --ivector-silence-weighting.max-state-duration : (RE weighting in iVector estimation for online decoding) Maximum allowed duration of a single transition-id; runs with durations longer than this will be weighted down to the silence-weight. (float, default = -1)
  --ivector-silence-weighting.silence-phones : (RE weighting in iVector estimation for online decoding) List of integer ids of silence phones, separated by colons (or commas).  Data that (according to the traceback of the decoder) corresponds to these phones will be downweighted by --silence-weight. (string, default = "")
  --ivector-silence-weighting.silence-weight : (RE weighting in iVector estimation for online decoding) Weighting factor for frames that the decoder trace-back identifies as silence; only relevant if the --silence-phones option is set. (float, default = 1)
  --lattice-beam              : Lattice generation beam.  Larger->slower, and deeper lattices (float, default = 10)
  --max-active                : Decoder max active states.  Larger->slower; more accurate (int, default = 2147483647)
  --max-mem                   : Maximum approximate memory usage in determinization (real usage might be many times this). (int, default = 50000000)
  --mfcc-config               : Configuration file for MFCC features (e.g. conf/mfcc.conf) (string, default = "")
  --min-active                : Decoder minimum #active states. (int, default = 200)
  --minimize                  : If true, push and minimize after determinization. (bool, default = false)
  --num-threads-startup       : Number of threads used when initializing iVector extractor. (int, default = 8)
  --online                    : You can set this to false to disable online iVector estimation and have all the data for each utterance used, even at utterance start.  This is useful where you just want the best results and don't care about online operation.  Setting this to false has the same effect as setting --use-most-recent-ivector=true and --greedy-ivector-extractor=true in the file given to --ivector-extraction-config, and --chunk-length=-1. (bool, default = true)
  --online-pitch-config       : Configuration file for online pitch features, if --add-pitch=true (e.g. conf/online_pitch.conf) (string, default = "")
  --optimization.allocate-from-other : Instead of deleting a matrix of a given size and then allocating a matrix of the same size, allow re-use of that memory (bool, default = true)
  --optimization.allow-left-merge : Set to false to disable left-merging of variables in remove-assignments (obscure option) (bool, default = true)
  --optimization.allow-right-merge : Set to false to disable right-merging of variables in remove-assignments (obscure option) (bool, default = true)
  --optimization.backprop-in-place : Set to false to disable optimization that allows in-place backprop (bool, default = true)
  --optimization.consolidate-model-update : Set to false to disable optimization that consolidates the model-update phase of backprop (e.g. for recurrent architectures (bool, default = true)
  --optimization.convert-addition : Set to false to disable the optimization that converts Add commands into Copy commands wherever possible. (bool, default = true)
  --optimization.extend-matrices : This optimization can reduce memory requirements for TDNNs when applied together with --convert-addition=true (bool, default = true)
  --optimization.initialize-undefined : Set to false to disable optimization that avoids redundant zeroing (bool, default = true)
  --optimization.max-deriv-time : You can set this to the maximum t value that you want derivatives to be computed at when updating the model.  This is an optimization that saves time in the backprop phase for recurrent frameworks (int, default = 2147483647)
  --optimization.max-deriv-time-relative : An alternative mechanism for setting the --max-deriv-time, suitable for situations where the length of the egs is variable.  If set, it is equivalent to setting the --max-deriv-time to this value plus the largest 't' value in any 'output' node of the computation request. (int, default = 2147483647)
  --optimization.memory-compression-level : This is only relevant to training, not decoding.  Set this to 0,1,2; higher levels are more aggressive at reducing memory by compressing quantities needed for backprop, potentially at the expense of speed and the accuracy of derivatives.  0 means no compression at all; 1 means compression that shouldn't affect results at all. (int, default = 1)
  --optimization.min-deriv-time : You can set this to the minimum t value that you want derivatives to be computed at when updating the model.  This is an optimization that saves time in the backprop phase for recurrent frameworks (int, default = -2147483648)
  --optimization.move-sizing-commands : Set to false to disable optimization that moves matrix allocation and deallocation commands to conserve memory. (bool, default = true)
  --optimization.optimize     : Set this to false to turn off all optimizations (bool, default = true)
  --optimization.optimize-row-ops : Set to false to disable certain optimizations that act on operations of type *Row*. (bool, default = true)
  --optimization.propagate-in-place : Set to false to disable optimization that allows in-place propagation (bool, default = true)
  --optimization.remove-assignments : Set to false to disable optimization that removes redundant assignments (bool, default = true)
  --optimization.snip-row-ops : Set this to false to disable an optimization that reduces the size of certain per-row operations (bool, default = true)
  --optimization.split-row-ops : Set to false to disable an optimization that may replace some operations of type kCopyRowsMulti or kAddRowsMulti with up to two simpler operations. (bool, default = true)
  --phone-determinize         : If true, do an initial pass of determinization on both phones and words (see also --word-determinize) (bool, default = true)
  --plp-config                : Configuration file for PLP features (e.g. conf/plp.conf) (string, default = "")
  --prune-interval            : Interval (in frames) at which to prune tokens (int, default = 25)
  --word-determinize          : If true, do a second pass of determinization on words only (see also --phone-determinize) (bool, default = true)


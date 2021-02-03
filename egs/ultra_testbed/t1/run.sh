#!/usr/bin/env bash

# This recipe runs a decoder test on recordings in the following directory:

# Start setting configuration variables and parameters
datadir=$PWD/Libyan_msa_arl
speakers=(adel anwar bubaker hisham mukhtar redha srj yousef)
acoustic_scale=1.0 #  Scaling factor for acoustic log-likelihoods (float, default = 0.1)
add_pitch=false  #  Append pitch features to raw MFCC/PLP/filterbank features [but not for iVector extraction] (bool, default = false)
beam=16.0 # Decoding beam.  Larger->slower, more accurate. (float, default = 16)
beam_delta=0.5 # Increment used in decoding-- this parameter is obscure and relates to a speedup in the way the max-active constraint is applied.  Larger is more accurate. (float, default = 0.5)
chunk_length=0.18 # Length of chunk size in seconds, that we process.  Set to <= 0 to use all input in one chunk. (float, default = 0.18)
computation_debug=false # If true, turn on debug for the neural net computation (very verbose!) Will be turned on regardless if --verbose >= 5 (bool, default = false)
cmvn_config= # Configuration file for online cmvn features (e.g. conf/online_cmvn.conf). Controls features on nnet3 input (not ivector features). If not set, the OnlineCmvn is disabled. (string, default = "")
debug_computation=true # If true, turn on debug for the actual computation (very verbose!) (bool, default = false)
delta=0.000976562 # Tolerance used in determinization (float, default = 0.000976562)
determinize_lattice=true # If true, determinize the lattice (lattice-determinization, keeping only best pdf-sequence for each word-sequence). (bool, default = true)
do_endpointing=false # If true, apply endpoint detection (bool, default = false)
egs_extra_left_context=5
egs_extra_right_context=5
endpoint_rule1_max_relative_cost=inf # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
endpoint_rule1_min_trailing_silence=5 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 5)
endpoint_rule1_min_utterance_length=1.0 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule1_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = false)
endpoint_rule2_max_relative_cost=2 # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = 2)
endpoint_rule2_min_trailing_silence=0.5 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 0.5)
endpoint_rule2_min_utterance_length=2 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule2_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
endpoint_rule3_max_relative_cost=8 # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = 8)
endpoint_rule3_min_trailing_silence=1 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 1)
endpoint_rule3_min_utterance_length=2 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule3_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
endpoint_rule4_max_relative_cost=inf # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
endpoint_rule4_min_trailing_silence=2 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 2)
endpoint_rule4_min_utterance_length=0 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule4_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
endpoint_rule5_max_relative_cost=inf # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
endpoint_rule5_min_trailing_silence=5 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 0)
endpoint_rule5_min_utterance_length=20 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 20)
endpoint_rule5_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = false)
endpoint_silence_phones="1:2:3:4:5:6:7:8:9:10" # List of phones that are considered to be silence phones by the endpointing code. (string, default = "")
extra_left_context_initial=0
fbank_config="" # Configuration file for filterbank features (e.g. conf/fbank.conf) (string, default = "")
feature_type=mfcc # Base feature type [mfcc, plp, fbank] (string, default = "mfcc")
frame_subsampling_factor=3 # Required if the frame-rate of the output (e.g. in 'chain' models) is less than the frame-rate of the original alignment. (int, default = 1)
frames_per_chunk=20 # Number of frames in each chunk that is separately evaluated by the neural net.  Measured before any subsampling, if the --frame-subsampling-factor options is used (i.e. counts input frames.  This is only advisory (may be rounded up if needed. (int, default = 20)
global_cmvn_stats="" # filename with global stats for OnlineCmvn for features on nnet3 input (not ivector features) (string, default = "")
hash_ratio=2 # Setting used in decoder to control hash behavior (float, default = 2)
ivector_extraction_config= # Configuration file for online iVector extraction, see class OnlineIvectorExtractionConfig in the code (string, default = "")
ivector_silence_weighting_silence_phones="" # (RE weighting in iVector estimation for online decoding) List of integer ids of silence phones, separated by colons (or commas). Data that (according to the traceback of the decoder) corresponds to these phones will be downweighted by --silence-weight. (string, default = "")
ivector_silence_weighting_silence_weight=1 # (RE weighting in iVector estimation for online decoding) Weighting factor for frames that the decoder trace-back identifies as silence; only relevant if the --silence-phones option is set. (float, default = 1)--ivector-silence-weighting.silence-weight : (RE weighting in iVector estimation for online decoding) Weighting factor for frames that the decoder trace-back identifies as silence; only relevant if the --silence-phones option is set. (float, default = 1)
lattice_beam=10.0 # Lattice generation beam. Larger->slower, and deeper lattices (float, default <= 10)
max_active=2147483647 # Decoder max active states. Larger->slower; more accurate (int, default = 2147483647)
max_mem=500000000 # Maximum approximate memory usage in determinization (real usage might be many times this). (int, default = 50000000)
mfcc_config= # Configuration file for MFCC features (e.g. conf/mfcc.conf) (string, default = "")
min_active=200 # Decoder minimum #active states. (int, default = 200)
minimize=false # If true, push and minimize after determinization. (bool, default = false)
num_threads_startup=8 # Number of threads used when initializing iVector extractor. (int, default = 8)
online=true # You can set this to false to disable online iVector estimation and have all the data for each utterance used, even at utterance start. This is useful where you just want the best results and don't care about online operation. Setting this to false has the same effect as setting --use-most-recent-ivector=true and --greedy-ivector-extractor=true in the file given to --ivector-extraction-config, and --chunk-length=-1. (bool, default = true)
online_pitch_config="" # Configuration file for online pitch features, if --add-pitch=true (e.g. conf/online_pitch.conf) (string, default = "")
optimization_allocate_from_other=true # Instead of deleting a matrix of a given size and then allocating a matrix of the same size, allow re_use of that memory (bool, default = true)
optimization_allow_left_merge=true # Set to false to disable left_merging of variables in remove_assignments (obscure option) (bool, default = true)
optimization_allow_right_merge=true # Set to false to disable right_merging of variables in remove_assignments (obscure option) (bool, default = true)
optimization_backprop_in_place=true # Set to false to disable optimization that allows in_place backprop (bool, default = true)
optimization_consolidate_model_update=true # Set to false to disable optimization that consolidates the model_update phase of backprop (e.g. for recurrent architectures (bool, default = true)
optimization_convert_addition=true # Set to false to disable the optimization that converts Add commands into Copy commands wherever possible. (bool, default = true)
optimization_extend_matrices=true # This optimization can reduce memory requirements for TDNNs when applied together with __convert_addition=true (bool, default = true)
optimization_initialize_undefined=true # Set to false to disable optimization that avoids redundant zeroing (bool, default = true)
optimization_max_deriv_time=2147483647 # You can set this to the maximum t value that you want derivatives to be computed at when updating the model. This is an optimization that saves time in the backprop phase for recurrent frameworks (int, default = 2147483647)
optimization_max_deriv_time_relative=2147483647 # An alternative mechanism for setting the __max_deriv_time, suitable for situations where the length of the egs is variable. If set, it is equivalent to setting the __max_deriv_time to this value plus the largest 't' value in any 'output' node of the computation request. (int, default = 2147483647)
optimization_memory_compression_level=1 # This is only relevant to training, not decoding. Set this to 0,1,2; higher levels are more aggressive at reducing memory by compressing quantities needed for backprop, potentially at the expense of speed and the accuracy of derivatives. 0 means no compression at all; 1 means compression that shouldn't affect results at all. (int, default = 1)
optimization_min_deriv_time=-2147483648 # You can set this to the minimum t value that you want derivatives to be computed at when updating the model. This is an optimization that saves time in the backprop phase for recurrent frameworks (int, default = _2147483648)
optimization_move_sizing_commands=true # Set to false to disable optimization that moves matrix allocation and deallocation commands to conserve memory. (bool, default = true)
optimization_optimize=false # Set=true this to false to turn off all optimizations (bool, default = true)
optimization_optimize_row_ops=true # Set to false to disable certain optimizations that act on operations of type *Row*. (bool, default = true)
optimization_propagate_in_place=true # Set to false to disable optimization that allows in_place propagation (bool, default = true)
optimization_remove_assignments=true # Set to false to disable optimization that removes redundant assignments (bool, default = true)
optimization_snip_row_ops=true # Set this to false to disable an optimization that reduces the size of certain per_row operations (bool, default = true)
optimization_split_row_ops=true # Set to false to disable an optimization that may replace some operations of type kCopyRowsMulti or kAddRowsMulti with up to two simpler operations. (bool, default = true)
phone_determinize=true # If true, do an initial pass of determinization on both phones and words (see also --word-determinize) (bool, default = true)
plp_config="" # Configuration file for PLP features (e.g. conf/plp.conf) (string, default = "")
prune_interval=25 # Interval=25 (in frames) at which to prune tokens (int, default = 25)
word_determinize=true # If true, do a second pass of determinization on words only (see also --phone-determinize) (bool, default = true)
lat_acoustic_scale=1.0 #acoustic-scale            : Scaling factor for acoustic likelihoods (float, default = 1)
acoustic2lm_scale=0.0 # Add this times original acoustic costs to LM costs (float, default = 0)
inv_acoustic_scale=1.0 # An alternative way of setting the acoustic scale: you can set its inverse. (float, default =1)
lm_scale=0.1 # Scaling factor for graph/lm costs (float, default = 1)
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

# Set location of local config files
ivector_extraction_config=$src/conf/ivector_extractor.conf
mfcc_config=$src/conf/mfcc.conf

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
  if [ -d $src/decode_online ]; then
    echo "Directory $src/decode_online already exists."
    echo "rm -Rf $src/decode_online"
    exit 1
  fi
  for s in ${speakers[@]}; do
    echo "Decoding $s."
    mkdir -p $src/decode_online/$s/log
    run.pl $src/decode_online/$s/log/decode.log \
      online2-wav-nnet3-latgen-faster \
        --acoustic-scale=$acoustic_scale \
        --add-pitch=$add_pitch \
        --beam=$beam \
        --beam-delta=$beam_delta \
	--chunk-length=$chunk_length \
        --computation.debug=$computation_debug \
        --config=$src/conf/online.conf \
	--debug-computation=$debug_computation \
	--delta=$delta \
	--determinize-lattice=$determinize_lattice \
        --do-endpointing=$do_endpointing \
        --endpoint.rule1.max-relative-cost=$endpoint_rule1_max_relative_cost \
        --endpoint.rule1.min-trailing-silence=$endpoint_rule1_min_trailing_silence \
        --endpoint.rule1.min-utterance-length=$endpoint_rule1_min_utterance_length \
        --endpoint.rule1.must-contain-nonsilence=$endpoint_rule1_must_contain_nonsilence \
        --endpoint.rule2.max-relative-cost=$endpoint_rule2_max_relative_cost \
        --endpoint.rule2.min-trailing-silence=$endpoint_rule2_min_trailing_silence \
        --endpoint.rule2.min-utterance-length=$endpoint_rule2_min_utterance_length \
        --endpoint.rule2.must-contain-nonsilence=$endpoint_rule2_must_contain_nonsilence \
        --endpoint.rule3.max-relative-cost=$endpoint_rule3_max_relative_cost \
        --endpoint.rule3.min-trailing-silence=$endpoint_rule3_min_trailing_silence \
        --endpoint.rule3.min-utterance-length=$endpoint_rule3_min_utterance_length \
        --endpoint.rule3.must-contain-nonsilence=$endpoint_rule3_must_contain_nonsilence \
        --endpoint.rule4.max-relative-cost=$endpoint_rule4_max_relative_cost \
        --endpoint.rule4.min-trailing-silence=$endpoint_rule4_min_trailing_silence \
        --endpoint.rule4.min-utterance-length=$endpoint_rule4_min_utterance_length \
        --endpoint.rule4.must-contain-nonsilence=$endpoint_rule4_must_contain_nonsilence \
        --endpoint.rule5.max-relative-cost=$endpoint_rule5_max_relative_cost \
        --endpoint.rule5.min-trailing-silence=$endpoint_rule5_min_trailing_silence \
        --endpoint.rule5.min-utterance-length=$endpoint_rule5_min_utterance_length \
        --endpoint.rule5.must-contain-nonsilence=$endpoint_rule5_must_contain_nonsilence \
        --endpoint.silence-phones=$endpoint_silence_phones \
        --extra-left-context-initial=$extra_left_context_initial \
        --fbank-config=$fbank_config \
        --feature-type=$feature_type \
        --frame-subsampling-factor=$frame_subsampling_factor \
        --frames-per-chunk=$frames_per_chunk \
        --global-cmvn-stats=$global_cmvn_stats \
        --hash-ratio=$hash_ratio \
        --ivector-extraction-config=$ivector_extraction_config \
        --ivector-silence-weighting.silence-phones=$ivector_silence_weighting_silence_phones \
        --ivector-silence-weighting.silence-weight=$ivector_silence_weighting_silence_weight \
        --lattice-beam=$lattice_beam \
        --max-active=$max_active \
        --max-mem=$max_mem \
        --mfcc-config=$mfcc_config \
        --min-active=$min_active \
        --minimize=$minimize \
        --num-threads-startup=$num_threads_startup \
        --online=$online \
        --word-determinize=$word_determinize \
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

# Note: we add frame_subsampling_factor/2 so that we can support the frame
# shifting that's done during training, so if frame-subsampling-factor=3, we
# train on the same egs with the input shifted by -1,0,1 frames.  This is done
# via the --frame-shift option to nnet3-chain-copy-egs in the script.
model_left_context=50
model_right_context=0
egs_left_context=$[model_left_context+(frame_subsampling_factor/2)+egs_extra_left_context]
egs_right_context=$[model_right_context+(frame_subsampling_factor/2)+egs_extra_right_context]

if [ $stage -le 6 ]; then
  for s in ${speakers[@]}; do
    steps/online/nnet2/extract_ivectors_online.sh \
      --cmd run.pl \
      --nj 1 \
      data/$s \
      $src/ivector_extractor \
      $src/decode_offline/ivectors_${s}

    steps/nnet3/decode.sh \
      --acwt 1.0 \
      --cmd run.pl  \
      --extra-left-context $egs_left_context \
      --extra-left-context-initial 0 \
      --extra-right-context $egs_right_context \
      --extra-right-context-final 0 \
      --frames-per-chunk $frames_per_chunk \
      --nj 1 \
      --num-threads 4 \
      --online-ivector-dir $src/decode_offline/ivectors_${s} \
      --post-decode-acwt 10.0 \
      $src \
      data/$s \
      $src/decode_offline/$s || exit 1
  done
fi
exit 0

        --optimization.propagate-in-place=
        --optimization.remove-assignments=
        --optimization.snip-row-ops=
        --optimization.split-row-ops=
        --phone-determinize=
        --plp-config=
        --prune-interval=

        --optimization.allocate-from-other=$optimization_allocate_from_other \
        --optimization.allow-left-merge=$optimization_allow_left_merge \
        --optimization.allow-right-merge=$optimization_allow_right_merge \
        --optimization.backprop-in-place=$optimization_backprop_in_place \
        --optimization.consolidate-model-update=$optimization_consolidate_model_update \
        --optimization.convert-addition=$optimization_convert_addition \
        --optimization-extend-matrices=$optimization_extend_matrices \
        --optimization.initialize-undefined=$optimization_initialize_undefined \
        --optimization.max-deriv-time=$optimization_max_deriv_time \
        --optimization.max-deriv-time-relative=$optimization_max_deriv_time_relative \
        --optimization.memory-compression-level=$optimization_memory_compression_level \
        --optimization.min-deriv-time=$optimization_min_deriv_time \
        --optimization.move-sizing-commands=$optimization_move_sizing_commands \
        --optimization.optimize=$optimization_optimize \
        --optimization.optimize-row-ops=$optimization_optimize_row_ops \

nnet3-latgen-faster-parallel \
  --num-threads=4 \
  --online-ivectors=scp:exp/multi_tamsa_librispeech_tamsa/decode_offline/ivectors_adel/ivector_online.scp \
  --online-ivector-period=10 \
  --frames-per-chunk=20 \
  --extra-left-context=76 \
  --extra-right-context=26 \
  --extra-left-context-initial=0 \
  --extra-right-context-final=0 \
  --minimize=false \
  --max-active=7000 \
  --min-active=200 \
  --beam=15.0 \
  --lattice-beam=8.0 \
  --acoustic-scale=1.0 \
  --allow-partial=true \
  --word-symbol-table=exp/multi_tamsa_librispeech_tamsa/words.txt \
  exp/multi_tamsa_librispeech_tamsa/decode_offline/final.mdl \
  exp/multi_tamsa_librispeech_tamsa/HCLG.fst \
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:data/adel/split1/1/utt2spk scp:data/adel/split1/1/cmvn.scp scp:data/adel/split1/1/feats.scp ark:- |" "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >exp/multi_tamsa_librispeech_tamsa/decode_offline/adel/lat.1.gz"

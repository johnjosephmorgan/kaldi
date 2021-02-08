#!/bin/bash
# Diarization Demo
# Input: A recording with speech from several speakers.
# Output: A segmentation of the recording and a clustering of the segments by speaker.
# Perform language id after SAD

# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh
stage=0
. utils/parse_options.sh

# Write the command line for the record
echo "$0 $@"

if [ "$#" != "1" ]; then
  echo "USAGE $0 <SRC_FLAC_FILE>"
  echo "For example:"
  echo "$0 src/data/flac/DH_0001.flac"
  echo "$0 src/data/flac/DH_0019.flac"
  echo "$0 src/data/sif/flac/NISTMSA_G52_sM18iM04fM19_050810_sif.flac"
  exit 1
fi

# begin setting configuration variables
input_extension=flac
mfcc_hires_config=conf/mfcc_hires.conf
sad_sampling_rate=16k
compress=true
src=
# SAD options
extra_left_context=0
extra_left_context_initial=-1
extra_right_context=0
extra_right_context_final=-1
frame_subsampling_factor=3
frames_per_chunk=150
norm_means=false
norm_vars=false
sad_nnet_dir=exp/segmentation_1a/tdnn_stats_sad_1a
frame_shift=0.01
max_speech_duration=3.1
min_silence_duration=0.38
min_speech_duration=0.6
sil_scale=1.0
acoustic_scale=0.1
acwt=0.3
beam=16
max_active=2147483647
min_active=20
max_segment_length=2.0
merge_consecutive_max_dur=2
min_segment_dur=0.5   # Minimum duration (in seconds) required for a segment to be included
segment_padding=0.1
# X-vector options
xvector_nnet=exp/xvector_nnet_1a
cmn_window=300
min_chunk_size=20
chunk_size=400
diarization_sampling_rate=16k
pca_dim=-1
# Cluster options
cluster_dial=0.59
cluster_threshold=0.00155
first_pass_max_utterances=100
read_costs=false
# Scoring options
target_energy=0.035
# Arabic ASR settings
frames_per_chunk_decoding=150
arabic_asr_chain_dir=exp/chain_mer80/tdnn_lstm_1a_sp_bi
arabic_asr_nnet_dir=exp/nnet3_mer80
arabic_asr_graph_dir=exp/chain_mer80/graph
# English ASR decoding
frames_per_chunk_decoding=150
english_asr_chain_dir=exp/chain/blstm_7b
english_asr_nnet_dir=exp/nnet3
english_asr_graph_dir=exp/tdnn_7b_chain_online/graph_pp
#
frame_shift_factor=0.01
hard_max_segment_length=30.0
remove_noise_only_segments=false
silence_proportion=0.2
window=1.5
# lid options
lid_nnet_dir=exp/lid_xvector_nnet_1a
apply_log=true
model_rebalanced=exp/lid_xvector_nnet_1a/xvectors_train/logistic_regression_rebalanced
languages=langs.txt
# end of setting configuration variables

# Get input arguments from command line
src=$1

# Make the working directory
base=$(basename $src .$input_extension)
# Remove the file extension to get the directory name
working_dir=${base}
mkdir -p $working_dir/speechactivity

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Write parameter files for Kaldi SAD."
  # wav.scp
  echo "$base sox -t $input_extension $src -t wav -r $sad_sampling_rate -b 16 - channels 1 |"> $working_dir/speechactivity/wav.scp
  # the utt2spk file is simple since we process 1 recording 
  echo "$base $base" > $working_dir/speechactivity/utt2spk
  # spk2utt
  echo "$base $base" > $working_dir/speechactivity/spk2utt
fi

if [ $stage -le 1 ]; then
  echo "$0 Stage 1: Waveform Preprocessing"
  echo "Extract MFCC feature vectors for SAD."
  run.pl  $working_dir/speechactivity/log/make_mfcc_hires.log \
    compute-mfcc-feats \
      --write-utt2dur=ark,t:$working_dir/speechactivity/utt2dur \
      --config=$mfcc_hires_config \
      scp,p:$working_dir/speechactivity/wav.scp ark:- '|' copy-feats \
      --write-num-frames=ark,t:$working_dir/speechactivity/utt2num_frames --compress=$compress \
      ark:- ark,t,scp:$(pwd)/$working_dir/speechactivity/raw_mfcc.txt,$(pwd)/$working_dir/speechactivity/raw_mfcc.scp || exit 1;
  cp $working_dir/speechactivity/raw_mfcc.scp $working_dir/speechactivity/feats.scp
fi

if [ $stage -le 2 ]; then
  echo "$0 stage 2: Segmentation: Propagate features through the raw SAD neural network model."
  run.pl  $working_dir/speechactivity/log/propagate_features_thru_nnet.log \
    nnet3-compute --use-gpu=no \
      --extra-left-context=$extra_left_context \
      --extra-left-context-initial=$extra_left_context_initial \
      --extra-right-context=$extra_right_context \
      --extra-right-context-final=$extra_right_context_final \
      --frame-subsampling-factor=$frame_subsampling_factor \
      --frames-per-chunk=$frames_per_chunk \
      $sad_nnet_dir/final.raw \
      "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:$working_dir/speechactivity/utt2spk scp:$working_dir/speechactivity/raw_mfcc.scp scp:$working_dir/speechactivity/raw_mfcc.scp ark:- |" \
      "ark:| copy-matrix --apply-exp ark:- ark,t,scp:$working_dir/speechactivity/sad_xvectors.txt,$working_dir/speechactivity/sad_xvectors.scp" || exit 1;
fi

if [ $stage -le 3 ]; then
  echo "$0 Stage 3: Write a file containing the targets that will be used to make the HCLG.fst."
  mkdir -p $working_dir/speechactivity/graph_output
  cat <<EOF > $working_dir/speechactivity/graph_output/words.txt
<eps> 0
silence 1
speech 2
EOF
fi

frame_shift=0.03
if [ $stage -le 4 ]; then
  echo "$0 Stage 4: Make the HCLG.fst for SAD."
  run.pl $working_dir/speechactivity/graph_output/log/make_graph.log \
    local/prepare_sad_graph.py \
      --frame-shift=$frame_shift \
      --max-speech-duration=$max_speech_duration \
      --min-silence-duration=$min_silence_duration \
      --min-speech-duration=$min_speech_duration \
      - '|' fstcompile \
      --isymbols=$working_dir/speechactivity/graph_output/words.txt \
      --osymbols=$working_dir/speechactivity/graph_output/words.txt '>' $working_dir/speechactivity/graph_output/HCLG.fst
fi

if [ $stage -le 5 ]; then
  echo "$0 Stage 5: Get the matrix of probability transforms."
  steps/segmentation/internal/get_transform_probs_mat.py --priors=$sad_nnet_dir/post_output.vec --sil-scale=$sil_scale > $working_dir/speechactivity/transform_probs.mat
fi

if [ $stage -le 6 ]; then
  echo "$0 Stage 6: Run viterbi alignment."
  run.pl $working_dir/speechactivity/log/get_viterbi_alignments.log \
    decode-faster \
      --acoustic-scale=$acoustic_scale \
      --beam=$beam \
      --binary=false \
      --max-active=$max_active \
      --min-active=$min_active \
      $working_dir/speechactivity/graph_output/HCLG.fst \
      "ark:cat $working_dir/speechactivity/sad_xvectors.scp | copy-feats scp:- ark:- | transform-feats $working_dir/speechactivity/transform_probs.mat ark:- ark:- | copy-matrix --apply-log ark:- ark:- |" \
      ark:/dev/null \
      "ark,t:$working_dir/speechactivity/ali.1"

  gzip $working_dir/speechactivity/ali.1

echo "1" > $working_dir/speechactivity/num_jobs
fi

if [ $stage -le 7 ]; then
  echo "$0 Stage 7: Get the segments from the alignments."
  steps/segmentation/post_process_sad_to_segments.sh     --segment-padding 0.2 \
    --min-segment-dur $min_segment_dur     \
    --merge-consecutive-max-dur $merge_consecutive_max_dur     --cmd run.pl \
    --frame-shift $(perl -e "print 3 * 0.01")     $working_dir/speechactivity \
    $working_dir/speechactivity $working_dir/speechactivity 

  mv $working_dir/speechactivity/segments $working_dir/speechactivity/segs
fi

if [ $stage -le 8 ]; then
  echo "$0 Stage 8: Get subsegments."
  utils/data/subsegment_data_dir.sh $working_dir/speechactivity \
    $working_dir/speechactivity/segments.1 $working_dir/speechactivity/subsegments
fi

if [ $stage -le 9 ]; then
  echo "$0 Stage 9: Make .wav files from segmentation."
  local/speechactivity2wav.pl $src
fi

if [ $stage -le 10 ]; then
  echo "$0 Stage 10: Speaker Representation"
  echo "Make a new segmented directory."
  utils/data/subsegment_data_dir.sh $working_dir/speechactivity $working_dir/speechactivity/subsegments/segments $working_dir/segmented/init

  echo "Overwrite wav.scp with sox command for 16k sampling rate."
  echo "$base sox -t $input_extension $src -t wav -r $diarization_sampling_rate -b 16 - channels 1 |"> $working_dir/segmented/init/wav.scp
fi

if [ $stage -le 11 ]; then
  echo "$0 Stage 11: Extract segments and extract MFCCs for diarization xvector extraction."
  extract-segments \
    scp,p:$working_dir/segmented/init/wav.scp $working_dir/segmented/init/segments ark:- | \
    compute-mfcc-feats \
      --write-utt2dur=ark,t:$working_dir/segmented/init/utt2dur \
      --verbose=0 \
      --config=conf/mfcc_hires.conf \
      ark:- ark:- | \
    copy-feats \
      --compress=$compress \
      --write-num-frames=ark,t:$working_dir/segmented/init/utt2num_frames \
      ark:- ark,scp:$(pwd)/$working_dir/segmented/init/raw_mfcc.ark,$(pwd)/$working_dir/segmented/init/raw_mfcc.scp || exit 1;
fi

feats="ark,s,cs:apply-cmvn-sliding --norm-vars=$norm_vars --center=true --cmn-window=$cmn_window scp:$working_dir/segmented/subsegmented/feats.scp ark:- |"
nnet="nnet3-copy --nnet-config=$xvector_nnet/extract.config $xvector_nnet/final.raw - |"

if [ $stage -le 12 ]; then
  echo "$0 Stage 12: Applying neural network to feature vectors, extracting xvectors  and storing them under $working_dir/segmented/subsegemented."
  mkdir -p $working_dir/segmented/subsegmented/log
  cp $working_dir/segmented/init/raw_mfcc.scp $working_dir/segmented/subsegmented/feats.scp
  run.pl  $working_dir/segmented/subsegmented/log/extract_xvectors.log \
    nnet3-xvector-compute --use-gpu=no \
      --chunk-size=$chunk_size \
      --min-chunk-size=$min_chunk_size \
      "$nnet" \
      "$feats" \
      ark,t,scp:$working_dir/segmented/subsegmented/xvector.txt,$working_dir/segmented/subsegmented/xvector.scp || exit 1;
fi

if [ $stage -le 13 ]; then
  echo "$0 Stage 13: Computing mean of xvectors."
  run.pl $working_dir/segmented/subsegmented/log/mean.log \
    ivector-mean scp:./$working_dir/segmented/subsegmented/xvector.scp $working_dir/segmented/subsegmented/mean.vec || exit 1;
fi

if [ $stage -le 14 ]; then
  echo "$0 Stage 14: Computing whitening transform."
  run.pl $working_dir/segmented/subsegmented/log/transform.log \
    est-pca --read-vectors=true --normalize-mean=false \
      --normalize-variance=true --dim=$pca_dim \
      scp:$working_dir/segmented/subsegmented/xvector.scp $working_dir/segmented/subsegmented/transform.mat || exit 1;
fi

if [ $stage -le 15 ]; then
  echo "$0 Stage 15: Scoring xvectors with plda."
  run.pl $working_dir/segmented/subsegmented/log/score_plda.log \
    ivector-plda-scoring-dense \
      --target-energy=$target_energy \
      $xvector_nnet/plda \
      ark:./$working_dir/segmented/init/spk2utt \
      "ark:ivector-subtract-global-mean $xvector_nnet/mean.vec scp:$working_dir/segmented/subsegmented/xvector.scp ark:- | transform-vec $xvector_nnet/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
      ark,t,scp:$working_dir/segmented/subsegmented/scores.txt,${working_dir}/segmented/subsegmented/scores.scp
fi

if [ $stage -le 16 ]; then
  echo "$0 Stage 16:  Clustering with threshold."
  run.pl $working_dir/clusters/log/agglomerative_threshold.log \
    agglomerative-cluster \
      --threshold=$cluster_threshold \
      --read-costs=$read_costs \
      --first-pass-max-utterances=$first_pass_max_utterances \
      --verbose=2 \
      "scp:utils/filter_scp.pl $working_dir/segmented/init/spk2utt $working_dir/segmented/subsegmented/scores.scp |" ark,t:$working_dir/segmented/init/spk2utt ark,t:$working_dir/clusters/labels_threshold
fi

if [ $stage -le 17 ]; then
  echo "$0 Stage 17: Writing rttm file."
  diarization/make_rttm.py \
    --rttm-channel 1 \
    $working_dir/segmented/init/segments \
    $working_dir/clusters/labels_threshold \
    $working_dir/clusters/rttm || exit 1;
fi

if [ $stage -le 18 ]; then
  echo "$0 Stage 19: Writing .wav files from thresholded clustering."
  ./local/labels2wav_3.pl $src
fi
exit
if [ $stage -le 19 ]; then
  echo "$0 Stage 18: creating segments file from rttm and utt2spk, reco2file_and_channel "
  mkdir -p $working_dir/decode
  cp $working_dir/segmented/init/{wav.scp,utt2spk} $working_dir/decode
  cp $working_dir/speechactivity/reco2num_spk $working_dir/decode
  local/convert_rttm_to_utt2spk_and_segments.py \
    --append-reco-id-to-spkr=true \
    $working_dir/clusters/rttm \
    <(awk '{print $2" "$2" "$3}' $working_dir/clusters/rttm | sort -u) \
    ${working_dir}/decode/utt2spk $working_dir/decode/segments
  utils/utt2spk_to_spk2utt.pl $working_dir/decode/utt2spk > $working_dir/decode/spk2utt
  utils/fix_data_dir.sh $working_dir/decode || exit 1;
fi
exit
if [ $stage -le 20 ]; then
  echo "$0 Stage 20: Start doing LID."
  mkdir -p $working_dir/lid
  for d in $working_dir/audio_threshold/*; do
    db=$(basename $d)
    mkdir -p $working_dir/lid/$db
    sox $d/* $working_dir/lid/$db/$db.wav
    for w in $(printf '%s\n' "$d/*"); do
      b=$(basename $w .wav)
      mkdir -p $working_dir/lid/$db/$b
      echo " Write parameter files for Kaldi LID $db directory."
      # wav.scp
      echo "$b sox -t wav $w -t wav -r $sad_sampling_rate -b 16 - channels 1 |"> $working_dir/lid/$db/$b/wav.scp
      # the utt2spk file is simple since we process 1 recording 
      echo "$b $b" > $working_dir/lid/$db/$b/utt2spk
      # spk2utt
      echo "$b $b" > $working_dir/lid/$db/$b/spk2utt
      echo "Extract MFCC feature vectors for LID."
      run.pl  $working_dir/lid/$db/$b/log/make_mfcc_hires.log \
        compute-mfcc-feats \
          --write-utt2dur=ark,t:$working_dir/lid/$db/$b/utt2dur \
          --config=$mfcc_hires_config \
        scp,p:$working_dir/lid/$db/$b/wav.scp ark:- '|' copy-feats \
          --write-num-frames=ark,t:$working_dir/lid/$db/$b/utt2num_frames --compress=$compress \
          ark:- ark,t,scp:$(pwd)/$working_dir/lid/$db/$b/raw_mfcc.txt,$(pwd)/$working_dir/lid/$db/$b/raw_mfcc.scp || exit 1;
      cp $working_dir/lid/$db/$b/raw_mfcc.scp $working_dir/lid/$db/$b/feats.scp
      sid/compute_vad_decision.sh --nj 1 --cmd run.pl $working_dir/lid/$db/$b
      sid/nnet3/xvector/extract_xvectors.sh \
        --cmd "run.pl --mem 4G" --nj 1 \
        $lid_nnet_dir \
        $working_dir/lid/$db/$b \
        $working_dir/lid/$db/$b || exit 1;
      test_xvectors="ark:ivector-normalize-length \
      scp:$working_dir/lid/$db/$b/xvector.scp ark:- |";

      logistic-regression-eval \
        --apply-log=$apply_log \
        $model_rebalanced \
        "$test_xvectors" \
        ark,t:$working_dir/lid/$db/$b/posteriors

      cat $working_dir/lid/$db/$b/posteriors | \
        awk '{max=$3; argmax=3; for(f=3;f<NF;f++) { if ($f>max) 
          { max=$f; argmax=f; }}  
          print $1, (argmax - 3); }' | \
        utils/int2sym.pl -f 2 $languages \
          >$working_dir/lid/$db/$b/output
    done
  done
fi
exit

echo "$0 Stage 21: Prepare speaker 1 for Arabic ASR."
mkdir -p $working_dir/1
find $working_dir/audio/1 -type f -name "*.wav" > $working_dir/1/wav.txt
local/make_lists.pl $working_dir/1/wav.txt 1
utils/utt2spk_to_spk2utt.pl $working_dir/1/utt2spk > $working_dir/1/spk2utt
utils/fix_data_dir.sh $working_dir/1 || exit 1;

echo "$0 Stage 22: Do Arabic ASR on 1."
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
  --word-symbol-table=${arabic_asr_graph_dir}/words.txt \
  ${arabic_asr_chain_dir}/final.mdl \
  $arabic_asr_graph_dir/HCLG.fst \
  ark:${working_dir}/1/spk2utt \
  "ark,s,cs:wav-copy scp,p:${working_dir}/1/wav.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark,t:- > $working_dir/1/lat.txt" \
  2> $working_dir/1/out.log
cat $working_dir/1/out.log | grep -v LOG | grep -v "--" | cut -d " " -f 2- > $working_dir/1/out.txt

echo "$0 Stage 23: Prepare speaker 2 for Arabic ASR."
mkdir -p $working_dir/2
find $working_dir/audio/2 -type f -name "*.wav" > $working_dir/2/wav.txt
local/make_lists.pl $working_dir/2/wav.txt 2
utils/utt2spk_to_spk2utt.pl $working_dir/2/utt2spk > $working_dir/2/spk2utt
utils/fix_data_dir.sh $working_dir/2 || exit 1;

echo "$0 Stage 24: Do Arabic ASR on 2."
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
  --word-symbol-table=${arabic_asr_graph_dir}/words.txt \
  ${arabic_asr_chain_dir}/final.mdl \
  $arabic_asr_graph_dir/HCLG.fst \
  ark:${working_dir}/2/spk2utt \
  "ark,s,cs:wav-copy scp,p:${working_dir}/2/wav.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark,t:- > $working_dir/2/lat.txt" \
  2> $working_dir/2/out.log
cat $working_dir/2/out.log | grep -v LOG | cut -d " " -f 2- > $working_dir/2/out.txt

echo "$0 Stage 25: Prepare speaker 3 for English ASR."
#utils/mkgraph.sh \
#  --self-loop-scale 1.0 \
#  data/lang_pp_test \
#  $english_asr_chain_dir \
#  $english_asr_chain_dir/graph_pp

mkdir -p $working_dir/3
find $working_dir/audio/3 -type f -name "*.wav" > $working_dir/3/wav.txt
local/make_lists.pl $working_dir/3/wav.txt 3
utils/utt2spk_to_spk2utt.pl $working_dir/3/utt2spk > $working_dir/3/spk2utt
utils/fix_data_dir.sh $working_dir/3 || exit 1;

echo "$0 Stage 26: Do English ASR on 3."
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
  --word-symbol-table=${english_asr_graph_dir}/words.txt \
  ${english_asr_chain_dir}/final.mdl \
  $english_asr_graph_dir/HCLG.fst \
  ark:${working_dir}/3/spk2utt \
  "ark,s,cs:wav-copy scp,p:${working_dir}/3/wav.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark,t:- > $working_dir/3/lat.txt" \
  2> $working_dir/3/out.log
cat $working_dir/3/out.log | grep -v LOG | grep -v "--" | cut -d " " -f 2- > $working_dir/3/out.txt
<

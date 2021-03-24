#!/usr/bin/env bash

# segment   and  cluster  the segments by speaker.

if [ $# -ne 2 ]; then
  echo "USAGE: $0 <FLAC_DIR> <WORK_DIR>"
exit 1;
fi
datadir=$1
workdir=$2
# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh
. utils/parse_options.sh
stage=0

# begin setting configuration variables
input_extension=flac
mfcc_hires_config=conf/mfcc_hires.conf
sad_sampling_rate=16k
compress=true
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

# loop over source flac files
for src in $datadir/*; do
  # Make the working directory
  base=$(basename $src .$input_extension)
  # Remove the file extension to get the directory name
  working_dir=$workdir/recordings/${base}
  mkdir -p $working_dir/speechactivity

  #echo "$0 Stage 0: Write parameter files for Kaldi SAD."
  # wav.scp
  echo "$base sox -t $input_extension $src -t wav -r $sad_sampling_rate -b 16 - channels 1 |"> $working_dir/speechactivity/wav.scp
  # the utt2spk file is simple since we process 1 recording 
  echo "$base $base" > $working_dir/speechactivity/utt2spk
  # spk2utt
  echo "$base $base" > $working_dir/speechactivity/spk2utt

  #echo "$0 Stage 1: Waveform Preprocessing"
  #echo "Extract MFCC feature vectors for SAD."
  run.pl  $working_dir/speechactivity/log/make_mfcc_hires.log \
    compute-mfcc-feats \
      --write-utt2dur=ark,t:$working_dir/speechactivity/utt2dur \
      --config=$mfcc_hires_config \
      scp,p:$working_dir/speechactivity/wav.scp ark:- '|' copy-feats \
      --write-num-frames=ark,t:$working_dir/speechactivity/utt2num_frames --compress=$compress \
      ark:- ark,t,scp:$(pwd)/$working_dir/speechactivity/raw_mfcc.txt,$(pwd)/$working_dir/speechactivity/raw_mfcc.scp || exit 1;
  cp $working_dir/speechactivity/raw_mfcc.scp $working_dir/speechactivity/feats.scp


  #echo "$0 stage 2: Segmentation: Propagate features through the raw SAD neural network model."
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


  #echo "$0 Stage 3: Write a file containing the targets that will be used to make the HCLG.fst."
  mkdir -p $working_dir/speechactivity/graph_output
  cat <<EOF > $working_dir/speechactivity/graph_output/words.txt
<eps> 0
silence 1
speech 2
EOF


frame_shift=0.03

  #echo "$0 Stage 4: Make the HCLG.fst for SAD."
  run.pl $working_dir/speechactivity/graph_output/log/make_graph.log \
    local/prepare_sad_graph.py \
      --frame-shift=$frame_shift \
      --max-speech-duration=$max_speech_duration \
      --min-silence-duration=$min_silence_duration \
      --min-speech-duration=$min_speech_duration \
      - '|' fstcompile \
      --isymbols=$working_dir/speechactivity/graph_output/words.txt \
      --osymbols=$working_dir/speechactivity/graph_output/words.txt '>' $working_dir/speechactivity/graph_output/HCLG.fst



  #echo "$0 Stage 5: Get the matrix of probability transforms."
  steps/segmentation/internal/get_transform_probs_mat.py --priors=$sad_nnet_dir/post_output.vec --sil-scale=$sil_scale > $working_dir/speechactivity/transform_probs.mat



  #echo "$0 Stage 6: Run viterbi alignment."
  [ ! -f $working_dir/speechactivity/ali.1 ] || rm $working_dir/speechactivity/ali.1;
  [ ! -f $working_dir/speechactivity/ali.1.gz ] || rm $working_dir/speechactivity/ali.1.gz;
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

  #echo "$0 Stage 7: Get the segments from the alignments."
  steps/segmentation/post_process_sad_to_segments.sh     --segment-padding 0.2 \
    --min-segment-dur $min_segment_dur     \
    --merge-consecutive-max-dur $merge_consecutive_max_dur     --cmd run.pl \
    --frame-shift $(perl -e "print 3 * 0.01")     $working_dir/speechactivity \
    $working_dir/speechactivity $working_dir/speechactivity > /dev/null 2> /dev/null

  mv $working_dir/speechactivity/segments $working_dir/speechactivity/segs



  #echo "$0 Stage 8: Get subsegments."
  utils/data/subsegment_data_dir.sh $working_dir/speechactivity \
    $working_dir/speechactivity/segments.1 $working_dir/speechactivity/subsegments > /dev/null 2> /dev/null



  #echo "$0 Stage 9: Make .wav files from segmentation."
  local/speechactivity2wav.pl $src $working_dir



  #echo "$0 Stage 10: Speaker Representation"
  #echo "Make a new segmented directory."
  utils/data/subsegment_data_dir.sh \
    $working_dir/speechactivity \
    $working_dir/speechactivity/subsegments/segments \
    $working_dir/segmented/init > /dev/null 2> /dev/null

  #echo "Overwrite wav.scp with sox command for 16k sampling rate."
  echo "$base sox -t $input_extension $src -t wav -r $diarization_sampling_rate -b 16 - channels 1 |"> $working_dir/segmented/init/wav.scp



  #echo "$0 Stage 11: Extract segments and extract MFCCs for diarization xvector extraction."
  run.pl $working_dir/segmented/init/log/extract_segments.log \
  extract-segments \
    scp,p:$working_dir/segmented/init/wav.scp \
    $working_dir/segmented/init/segments \
    ark:$working_dir/segmented/init/extracted_segments.ark 

  run.pl $working_dir/segmented/init/log/compute_mfcc_feats.log \
    compute-mfcc-feats \
      --write-utt2dur=ark,t:$working_dir/segmented/init/utt2dur \
      --config=conf/mfcc_hires.conf \
      ark:$working_dir/segmented/init/extracted_segments.ark \
      ark:$working_dir/segmented/init/features.ark 

  run.pl $working_dir/segmented/init/log/copy_feats.log \
    copy-feats \
      --compress=$compress \
      --write-num-frames=ark,t:$working_dir/segmented/init/utt2num_frames \
      ark:$working_dir/segmented/init/features.ark \
      ark,scp:$(pwd)/$working_dir/segmented/init/raw_mfcc.ark,$(pwd)/$working_dir/segmented/init/raw_mfcc.scp 

#  extract-segments \
#    scp,p:$working_dir/segmented/init/wav.scp $working_dir/segmented/init/segments ark:- | \
#    compute-mfcc-feats \
#      --write-utt2dur=ark,t:$working_dir/segmented/init/utt2dur \
#      --config=conf/mfcc_hires.conf \
#      ark:- ark:- | \
#    copy-feats \
#      --compress=$compress \
#      --write-num-frames=ark,t:$working_dir/segmented/init/utt2num_frames \
#      ark:- ark,scp:$(pwd)/$working_dir/segmented/init/raw_mfcc.ark,$(pwd)/$working_dir/segmented/init/raw_mfcc.scp 


  feats="ark,s,cs:apply-cmvn-sliding --norm-vars=$norm_vars --center=true --cmn-window=$cmn_window scp:$working_dir/segmented/subsegmented/feats.scp ark:- |"
  nnet="nnet3-copy --nnet-config=$xvector_nnet/extract.config $xvector_nnet/final.raw - |"


  #echo "$0 Stage 12: Applying neural network to feature vectors, extracting xvectors  and storing them under $working_dir/segmented/subsegemented."
  mkdir -p $working_dir/segmented/subsegmented/log
  cp $working_dir/segmented/init/raw_mfcc.scp $working_dir/segmented/subsegmented/feats.scp
  run.pl  $working_dir/segmented/subsegmented/log/extract_xvectors.log \
    nnet3-xvector-compute --use-gpu=no \
      --chunk-size=$chunk_size \
      --min-chunk-size=$min_chunk_size \
      "$nnet" \
      "$feats" \
      ark,t,scp:$working_dir/segmented/subsegmented/xvector.txt,$working_dir/segmented/subsegmented/xvector.scp || exit 1;



  #echo "$0 Stage 13: Computing mean of xvectors."
  run.pl $working_dir/segmented/subsegmented/log/mean.log \
    ivector-mean scp:./$working_dir/segmented/subsegmented/xvector.scp $working_dir/segmented/subsegmented/mean.vec || exit 1;



  #echo "$0 Stage 14: Computing whitening transform."
  run.pl $working_dir/segmented/subsegmented/log/transform.log \
    est-pca --read-vectors=true --normalize-mean=false \
      --normalize-variance=true --dim=$pca_dim \
      scp:$working_dir/segmented/subsegmented/xvector.scp $working_dir/segmented/subsegmented/transform.mat || exit 1;



  #echo "$0 Stage 15: Scoring xvectors with plda."
  run.pl $working_dir/segmented/subsegmented/log/score_plda.log \
    ivector-plda-scoring-dense \
      --target-energy=$target_energy \
      $xvector_nnet/plda \
      ark:./$working_dir/segmented/init/spk2utt \
      "ark:ivector-subtract-global-mean $xvector_nnet/mean.vec scp:$working_dir/segmented/subsegmented/xvector.scp ark:- | transform-vec $xvector_nnet/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
      ark,t,scp:$working_dir/segmented/subsegmented/scores.txt,${working_dir}/segmented/subsegmented/scores.scp



  #echo "$0 Stage 16:  Clustering with threshold."
  run.pl $working_dir/clusters/log/agglomerative_threshold.log \
    agglomerative-cluster \
      --threshold=$cluster_threshold \
      --read-costs=$read_costs \
      --first-pass-max-utterances=$first_pass_max_utterances \
      --verbose=2 \
      "scp:utils/filter_scp.pl $working_dir/segmented/init/spk2utt $working_dir/segmented/subsegmented/scores.scp |" ark,t:$working_dir/segmented/init/spk2utt ark,t:$working_dir/labels_threshold



  #echo "$0 Stage 17: Writing rttm file."
  diarization/make_rttm.py \
    --rttm-channel 1 \
    $working_dir/segmented/init/segments \
    $working_dir/labels_threshold \
    $working_dir/clusters/rttm || exit 1;
  # cleaen up
  rm -Rf $working_dir/{segmented,speechactivity,clusters}
done

#!/bin/bash

# Input: A recording 
# Output: A segmentation of the recording 

# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh

# Write the command line for the record
echo "$0 $@"

if [ $# -ne 1 ]; then
  echo "USAGE $0 <SRC_FLAC_FILE>"
  echo "For example:"
  echo "$0 ./10002_20705_alv_A.flac"
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
sad_nnet_dir=exp/sad_1a/tdnn_stats_sad_1a
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
# end of setting configuration variables

# Get input arguments from command line
src=$1

# Make the working directory
base=$(basename $src .$input_extension)
# Remove the file extension to get the directory name
working_dir=${base}
mkdir -p $working_dir/speechactivity

echo "$0 Stage 0: Write parameter files for Kaldi SAD."
# wav.scp
echo "$base sox -t $input_extension $src -t wav -r $sad_sampling_rate -b 16 - channels 1 |"> $working_dir/speechactivity/wav.scp
# the utt2spk file is simple since we process 1 recording 
echo "$base $base" > $working_dir/speechactivity/utt2spk
# spk2utt
echo "$base $base" > $working_dir/speechactivity/spk2utt

echo "$0 Stage 1: Waveform Preprocessing"
echo "Extract MFCC feature vectors for SAD."
run.pl  $working_dir/speechactivity/log/make_mfcc_hires.log \
  compute-mfcc-feats \
    --write-utt2dur=ark,t:$working_dir/speechactivity/utt2dur \
    --config=$mfcc_hires_config \
    scp,p:$working_dir/speechactivity/wav.scp ark:- '|' copy-feats \
    --write-num-frames=ark,t:$working_dir/speechactivity/utt2num_frames --compress=$compress \
    ark:- ark,t,scp:$(pwd)/$working_dir/speechactivity/raw_mfcc.txt,$(pwd)/$working_dir/speechactivity/raw_mfcc.scp || exit 1;

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
    "ark:| copy-matrix --apply-exp ark:- ark,t,scp:$working_dir/speechactivity/output.txt,$working_dir/speechactivity/output.scp" || exit 1;

cp $working_dir/speechactivity/raw_mfcc.scp $working_dir/speechactivity/feats.scp

echo "$0 Stage 3: Write a file containing the targets that will be used to make the HCLG.fst."
mkdir -p $working_dir/speechactivity/graph_output
cat <<EOF > $working_dir/speechactivity/graph_output/words.txt
<eps> 0
silence 1
speech 2
EOF

frame_shift=0.03
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

echo "$0 Stage 5: Get the matrix of probability transforms."
steps/segmentation/internal/get_transform_probs_mat.py --priors=$sad_nnet_dir/post_output.vec --sil-scale=$sil_scale > $working_dir/speechactivity/transform_probs.mat

echo "$0 Stage 6: Run viterbi alignment."
run.pl $working_dir/speechactivity/log/get_viterbi_alignments.log \
  decode-faster \
  --acoustic-scale=$acoustic_scale \
  --beam=$beam \
  --binary=false \
  --max-active=$max_active \
  --min-active=$min_active \
  $working_dir/speechactivity/graph_output/HCLG.fst \
  "ark:cat $working_dir/speechactivity/output.scp | copy-feats scp:- ark:- | transform-feats $working_dir/speechactivity/transform_probs.mat ark:- ark:- | copy-matrix --apply-log ark:- ark:- |" \
  ark:/dev/null \
  "ark,t:$working_dir/speechactivity/ali.1"

gzip $working_dir/speechactivity/ali.1

echo "1" > $working_dir/speechactivity/num_jobs
echo "$0 Stage 7: Get the segments from the alignments."
steps/segmentation/post_process_sad_to_segments.sh     --segment-padding 0.2 \
  --min-segment-dur $min_segment_dur     \
  --merge-consecutive-max-dur $merge_consecutive_max_dur     --cmd run.pl \
  --frame-shift $(perl -e "print 3 * 0.01")     $working_dir/speechactivity \
  $working_dir/speechactivity $working_dir/speechactivity 

mv $working_dir/speechactivity/segments $working_dir/speechactivity/segs
echo "$0 Stage 8: Get subsegments."
utils/data/subsegment_data_dir.sh $working_dir/speechactivity \
  $working_dir/speechactivity/segments.1 $working_dir/speechactivity/subsegments

echo "$0 Stage 9: Make .wav files from segmentation."
local/speechactivity2wav.pl $src

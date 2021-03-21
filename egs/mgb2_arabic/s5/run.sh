#!/usr/bin/env bash

stage=-1

. ./cmd.sh
. ./path.sh
if [ -f ./path.sh ]; then . ./path.sh; fi
. utils/parse_options.sh

set -e -o pipefail -u
#FILTER OUT SEGMENTS BASED ON MER (Match Error Rate)

mer=80  
db_dir=DB
# Location of lexicon
lexicon=lexicon.txt

nj=100  # split training into how many jobs?
nDecodeJobs=80

if [ $stage -le 0 ]; then
  #DATA PREPARATION
  echo "Preparing training data"
  train_dir=data/train_mer$mer
dev_dir=data/dev
  for x in $train_dir $dev_dir; do
    mkdir -p $x
    if [ -f ${x}/wav.scp ]; then
      mkdir -p ${x}/.backup
      mv $x/{wav.scp,feats.scp,utt2spk,spk2utt,segments,text} ${x}/.backup
    fi
  done
  # Write the list of audio files
  find $db_dir/train/wav -type f -name "*.wav" | \
    awk -F/ '{print $NF}' | perl -pe 's/\.wav//g' > \
    data/train_mer80/wav_list
fi

if [ $stage -le 1 ]; then
  # This stage only is working by running it on the command line.
  xmldir=$db_dir/train/xml/utf8
  mkdir text/utf8
  for f in DB/train/xml/utf8/*; do
    base=$(basename $f .xml)
      local/process_xml.py \
        $f \
        text/utf8/$base.txt
  done
fi

if [ $stage -le 2 ]; then
  for f in text/utf8/*; do
    base=$(basename $f .txt)
    cat $f | local/add_to_datadir.py $base data/train_mer80
    echo $base DB/train/wav/$base.wav >> data/train_mer80/wav.scp
  done
fi

if [ $stage -le 3 ]; then
  for x in text segments; do
    cp DB/dev/${x}.all data/dev/${x}
  done

  find $db_dir/dev/wav -type f -name "*.wav" | \
    awk -F/ '{print $NF}' | perl -pe 's/\.wav//g' > \
    data/dev/wav_list

  for x in $(cat data/dev/wav_list); do 
    echo $x DB/dev/wav/$x.wav >> data/dev/wav.scp
  done
fi

if [ $stage -le 4 ]; then
  #Creating a file reco2file_and_channel which is used by convert_ctm.pl in local/score.sh script
  awk '{print $1" "$1" 1"}' data/dev/wav.scp > data/dev/reco2file_and_channel
# Creating utt2spk for dev from segments
  if [ ! -f data/dev/utt2spk ]; then
    cut -d ' ' -f1 data/dev/segments > data/dev/utt_id
    cut -d '_' -f1-2 data/dev/utt_id | paste -d ' ' data/dev/utt_id - > data/dev/utt2spk
  fi
fi

if [ $stage -le 5 ]; then
  for list in overlap non_overlap; do
    rm -rf data/dev_${list} || true
    cp -r data/dev data/dev_${list}
    for x in segments text utt2spk; do
      utils/filter_scp.pl DB/dev/${list}_speech data/dev/$x > data/dev_${list}/$x
    done
  done
fi

if [ $stage -le 6 ]; then
  for dir in data/train_mer80 data/dev data/dev_overlap data/dev_non_overlap; do
    utils/fix_data_dir.sh $dir
    utils/validate_data_dir.sh --no-feats $dir
  done
fi

if [ $stage -le 7 ]; then
  #Creating the train program lists
  head -500 data/train_mer80/wav_list > data/train_mer80/wav_list.short
  mkdir -p data/train_mer80_subset500
  utils/filter_scp.pl data/train_mer80/wav_list.short data/train_mer80/wav.scp > \
    data/train_mer80_subset500/wav.scp
  cp data/train_mer80/{utt2spk,segments,spk2utt} data/train_mer80_subset500
  utils/fix_data_dir.sh data/train_mer80_subset500
fi

echo "Training and Test data preparation succeeded"

if [ $stage -le 8 ]; then
  #LEXICON PREPARATION: The lexicon is also provided
  echo "Preparing dictionary"
  local/prepare_dict.sh $lexicon
fi

# Using the training data transcript for building the language model
LM_TEXT=DB/train/lm_text/lm_text_clean_utf8

if [ $stage -le 9 ]; then
  #LM TRAINING: Using the training set transcript text for language modelling
  echo "Training n-gram language model"
  local/mgb_train_lms.sh $mer
  local/mgb_train_lms_extra.sh $LM_TEXT $mer

  # Uncomment if you want to use pocolm for language modeling 
  #local/mgb_train_lms_extra_pocolm.sh $LM_TEXT $mer
fi

if [ $stage -le 10 ]; then
  #L Compilation
  echo "Preparing lang dir"
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
fi

if [ $stage -le 11 ]; then
  #G compilation
  local/mgb_format_data.sh --lang-test data/lang_test \
    --arpa-lm data/local/lm_mer80/3gram-mincount/lm_unpruned.gz
  utils/build_const_arpa_lm.sh data/local/lm_large_mer80/4gram-mincount/lm_unpruned.gz \
    data/lang_test data/lang_test_fg
fi

# Uncomment if you want to use pocolm for language modeling 
#if [ $stage -le 12 ]; then
#  local/mgb_format_data.sh --lang-test data/lang_poco_test \
#    --arpa-lm data/local/pocolm/data/arpa/4gram_small.arpa.gz
#  utils/build_const_arpa_lm.sh data/local/pocolm/data/arpa/4gram_big.arpa.gz \
#    data/lang_poco_test data/lang_poco_test_fg
#fi

if [ $stage -le 13 ]; then
  #Calculating mfcc features
  mfccdir=mfcc
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $mfccdir ]; then
    utils/create_split_dir.pl \
      /export/b0{3,4,5,6}/$USER/kaldi-data/egs/mgb2_arabic-$(date +'%m_%d_%H_%M')/s5/$mfccdir/storage $mfccdir/storage
  fi

  echo "Computing features"
  for x in train_mer$mer train_mer${mer}_subset500 dev_non_overlap dev_overlap ; do
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/$x \
      exp/mer$mer/make_mfcc/$x/log $mfccdir
    steps/compute_cmvn_stats.sh data/$x \
      exp/mer$mer/make_mfcc/$x/log $mfccdir
    utils/fix_data_dir.sh data/$x
  done
fi

if [ $stage -le 14 ]; then
  #Taking 10k segments for faster training
  utils/subset_data_dir.sh data/train_mer${mer}_subset500 10000 data/train_mer${mer}_subset500_10k 
fi

if [ $stage -le 15 ]; then
  #Monophone training
  steps/train_mono.sh --nj 80 --cmd "$train_cmd" \
    data/train_mer${mer}_subset500_10k data/lang exp/mer$mer/mono 
fi

if [ $stage -le 16 ]; then
  #Monophone alignment
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train_mer${mer}_subset500 data/lang exp/mer$mer/mono exp/mer$mer/mono_ali 

  #tri1 [First triphone pass]
  steps/train_deltas.sh --cmd "$train_cmd" \
    2500 30000 data/train_mer${mer}_subset500 data/lang exp/mer$mer/mono_ali exp/mer$mer/tri1 

  #tri1 decoding
  utils/mkgraph.sh data/lang_test exp/mer$mer/tri1 exp/mer$mer/tri1/graph

  for dev in dev_overlap dev_non_overlap; do
    steps/decode.sh --nj $nDecodeJobs --cmd "$decode_cmd" --config conf/decode.config \
      exp/mer$mer/tri1/graph data/$dev exp/mer$mer/tri1/decode_$dev &
  done
fi

if [ $stage -le 17 ]; then
  #tri1 alignment
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train_mer${mer}_subset500 data/lang exp/mer$mer/tri1 exp/mer$mer/tri1_ali 

  #tri2 [a larger model than tri1]
  steps/train_deltas.sh --cmd "$train_cmd" \
    3000 40000 data/train_mer${mer}_subset500 data/lang exp/mer$mer/tri1_ali exp/mer$mer/tri2

  #tri2 decoding
  utils/mkgraph.sh data/lang_test exp/mer$mer/tri2 exp/mer$mer/tri2/graph

  for dev in dev_overlap dev_non_overlap; do
   steps/decode.sh --nj $nDecodeJobs --cmd "$decode_cmd" --config conf/decode.config \
   exp/mer$mer/tri2/graph data/$dev exp/mer$mer/tri2/decode_$dev &
  done
fi

if [ $stage -le 18 ]; then
  #tri2 alignment
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train_mer${mer}_subset500 data/lang exp/mer$mer/tri2 exp/mer$mer/tri2_ali

  # tri3 training [LDA+MLLT]
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    4000 50000 data/train_mer${mer}_subset500 data/lang exp/mer$mer/tri1_ali exp/mer$mer/tri3

  #tri3 decoding
  utils/mkgraph.sh data/lang_test exp/mer$mer/tri3 exp/mer$mer/tri3/graph

  for dev in dev_overlap dev_non_overlap; do
   steps/decode.sh --nj $nDecodeJobs --cmd "$decode_cmd" --config conf/decode.config \
   exp/mer$mer/tri3/graph data/$dev exp/mer$mer/tri3/decode_$dev & 
  done
fi

if [ $stage -le 19 ]; then
  #tri3 alignment
  steps/align_si.sh --nj $nj --cmd "$train_cmd" --use-graphs true data/train_mer${mer}_subset500 data/lang exp/mer$mer/tri3 exp/mer$mer/tri3_ali

  #now we start building model with speaker adaptation SAT [fmllr]
  steps/train_sat.sh  --cmd "$train_cmd" \
    5000 100000 data/train_mer${mer}_subset500 data/lang exp/mer$mer/tri3_ali exp/mer$mer/tri4

  #sat decoding
  utils/mkgraph.sh data/lang_test exp/mer$mer/tri4 exp/mer$mer/tri4/graph

  for dev in dev_overlap dev_non_overlap; do
    steps/decode_fmllr.sh --nj $nDecodeJobs --cmd "$decode_cmd" --config conf/decode.config \
      exp/mer$mer/tri4/graph data/$dev exp/mer$mer/tri4/decode_$dev &
  done
fi

if [ $stage -le 20 ]; then
  #sat alignment
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train_mer$mer data/lang exp/mer$mer/tri4 exp/mer$mer/tri4_ali

  steps/train_sat.sh --cmd "$train_cmd" \
    10000 150000 data/train_mer$mer data/lang \
    exp/mer$mer/tri4_ali \
    exp/mer$mer/tri5

  utils/mkgraph.sh data/lang_test exp/mer$mer/tri5{,/graph}

  for dev in dev_overlap dev_non_overlap; do
    steps/decode_fmllr.sh --nj $nDecodeJobs --cmd "$decode_cmd" --config conf/decode.config \
      exp/mer$mer/tri5/graph data/$dev exp/mer$mer/tri5/decode_$dev
    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" --config conf/decode.config \
      data/lang_test data/lang_test_fg data/$dev \
      exp/mer$mer/tri5/decode_${dev}{,_fg}
  done
fi

exit 0 

# nnet1 dnn                                                                                                                                
local/nnet/run_dnn.sh $mer


time=$(date +"%Y-%m-%d-%H-%M-%S")
results=baseline.$time
#SCORING IS DONE USING SCLITE
for x in exp/*/*/decode*; do [ -d $x ] && grep Sum $x/score_*/*.sys | utils/best_wer.sh; done | sort -n -k2 > tmp$$

echo "non_overlap_speech_WER:" > $results
grep decode_dev_non_overlap tmp$$ >> $results
echo "" >> $results
echo "" >> $results
echo "overlap_speech_WER:" >> $results
grep decode_dev_overlap tmp$$ >> $results
echo "" >> $results
rm -fr tmp$$


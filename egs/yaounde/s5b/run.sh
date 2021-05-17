#!/bin/bash

# African Accented French
# Use transcripts to train LM

. ./cmd.sh
. ./path.sh

stage=0

. ./utils/parse_options.sh

# Set the locations of the GlobalPhone corpus and language models
gp_corpus=/mnt/corpora/Globalphone

#  locations of the sri canada read corpora
sricadatadir=/mnt/corpora/sri_canada

# bc stands for British Columbia
bcdir=$sricadatadir/bc_dc_aug2016/audio/clean1/read
# qc stands for Quebec City?
qcdir=$sricadatadir/qc_dc_aug2016/audio/clean1/read

tmpdir=data/local/tmp

# sri canada read transcripts
bclist=$sricadatadir/afc-bc_read.sentid.orig
qclist=$sricadatadir/afc-qc_read.sentid.orig

# location of gabon read data
gabonreaddatadir=/mnt/corpora/central_accord/train

# location of central accord test data
catestdatadir=/mnt/corpora/central_accord/test

# location of niger data
nigerdatadir=/mnt/corpora/niger_west_african_fr

# location of yaounde data
yaoundedatadir=/mnt/corpora/Yaounde

# location of gabon conversational data
gabonconvdatadir=/mnt/corpora/central_accord/train
gabonconvtmpdir=data/local/tmp/gabonconv

if [ $stage -le 0 ]; then
  echo "$0: global phone data prep"
  mkdir -p data/local/tmp/gp
  echo "$0: Getting list of globalphone .wav files."
  find $gp_corpus/French/adc/wav -type f -name "*.wav" > \
    data/local/tmp/gp/wav_list.txt
fi

if [ $stage -le 1 ]; then
  echo "$0: Making gp training lists."
  local/gp/make_lists.pl $gp_corpus/French/adc/wav || exit 1;
  utils/fix_data_dir.sh data/local/tmp/gp/lists
fi

if [ $stage -le 2 ]; then
  echo "$0: Making acoustic model sri canada training  lists."
  sricatmpdir=$tmpdir/srica
  mkdir -p $sricatmpdir/lists
  for x in bc qc; do
    mkdir -p $sricatmpdir/$x

    echo "$0: Getting a list of the sri canada .wav files."
    find $sricadatadir/${x}_dc_aug2016/audio/clean1/read -type f -name "*.wav" \
      | grep $x > $sricatmpdir/$x/wav_list.txt
  done
fi

if [ $stage -le 3 ]; then
  echo "$0: Making sri canada lists."
  local/srica/bc_make_lists.pl $sricadatadir || exit 1;
  utils/fix_data_dir.sh $sricatmpdir/bc/lists

  local/srica/qc_make_lists.pl $sricadatadir || exit 1;
  utils/fix_data_dir.sh $sricatmpdir/qc/lists
fi

if [ $stage -le 4 ]; then
  echo "$0: Getting sri canada training lists."
  for x in bc qc; do
    for y in wav.scp utt2spk text; do
      cat $sricatmpdir/$x/lists/$y >> $sricatmpdir/lists/$y
    done
  done
fi

if [ $stage -le 5 ]; then
  echo "$0: gabon read prep."
  gabonreadtmpdir=data/local/tmp/gabonread
  mkdir -p $gabonreadtmpdir
  echo "$0: Getting a list of the gabon read .wav files."
  find $gabonreaddatadir -type f -name "*.wav" | grep read > \
    $gabonreadtmpdir/wav_list.txt

  echo "$0: Making gabon read lists."
  local/gabon_read/make_lists.pl $gabonreaddatadir || exit 1;
  utils/fix_data_dir.sh $gabonreadtmpdir/lists
fi

if [ $stage -le 6 ]; then
  echo "$0: Niger prep."
  nigertmpdir=data/local/tmp/niger
  mkdir -p $nigertmpdir
  echo "$0: Getting a list of the niger .wav files."
  find $nigerdatadir -type f -name "*.wav" > $nigertmpdir/wav_list.txt
  echo "$0: Making niger lists."
  local/niger/make_lists.pl $nigerdatadir || exit 1;
  utils/fix_data_dir.sh $nigertmpdir/lists
fi

if [ $stage -le 7 ]; then
  echo "$0: ca16 test prep"
  catesttmpdir=data/local/tmp/centralaccord
  mkdir -p $catesttmpdir
  echo "$0: Getting a list of the ca16 .wav files."
  find $catestdatadir -type f -name "*.wav" > $catesttmpdir/wav_list.txt
  echo "$0: Making ca16 lists."
  local/central_accord/make_lists.pl $catestdatadir || exit 1;
  utils/fix_data_dir.sh $catesttmpdir/lists
  mkdir -p data/ca16
  for x in spk2utt text utt2spk wav.scp; do
    cp $catesttmpdir/lists/$x data/ca16/
  done
fi

if [ $stage -le 8 ]; then
  echo "$0: yaounde  prep"
  yaoundetmpdir=data/local/tmp/yaounde
  mkdir -p $yaoundetmpdir
  echo "$0: Getting a list of the yaounde .wav files."
  find $yaoundedatadir -type f -name "*.wav" | grep 16000 > \
    $yaoundetmpdir/wav_list.txt

  echo "$0: Making yaounde lists."
  local/yaounde/make_lists.pl yaoundedatadir || exit 1;
  utils/fix_data_dir.sh $yaoundetmpdir/lists
fi

if [ $stage -le 9 ]; then
  mkdir -p $gabonconvtmpdir
  find $gabonconvdatadir -type f -name "*.wav" | grep  conv > \
    $gabonconvtmpdir/wav_list.txt

  local/gabon_conv/make_lists.pl gabonconvdatadir || exit 1;
  utils/utt2spk_to_spk2utt.pl $gabonconvtmpdir/lists/
  utils/fix_data_dir.sh $gabonconvtmpdir/lists
fi

if [ $stage -le 10 ]; then
  echo "$0: Consolidating training data lists."
  mkdir -p data/train
  for c in gabonread gp niger yaounde gabonconv; do
    for x in wav.scp text utt2spk; do
      cat data/local/tmp/$c/lists/$x >> data/train/$x
    done
  done

  utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
  utils/fix_data_dir.sh data/train
fi

if [ $stage -le 11 ]; then
  mkdir -p data/local/tmp/dict
  export LC_ALL=C
  local/prepare_dict.sh || exit 1;
fi

if [ $stage -le 12 ]; then
  echo "$0: Preparing lang directory."
  utils/prepare_lang.sh \
    --position-dependent-phones true data/local/dict "<UNK>" data/local/lang_tmp \
    data/lang || exit 1;
fi

if [ $stage -le 13 ]; then
  echo "$0: Preparing the lm."
  mkdir -p $tmpdir/lm
  mkdir -p data/local/lm
  cut -f 2- data/train/text > $tmpdir/lm/text
  local/prepare_lm.sh  $tmpdir/lm/text || exit 1;
fi

if [ $stage -le 14 ]; then
  utils/format_lm.sh data/lang data/local/lm/trigram.arpa.gz \
    data/local/dict/lexicon.txt data/lang_test || exit 1;
fi

if [ $stage -le 15 ]; then
  echo "$0: Extracting acoustic features."
  for fld in train ca16; do
    steps/make_mfcc.sh \
      --cmd run.pl --nj 56 data/$fld exp/make_mfcc/$fld mfcc || exit 1;

    utils/fix_data_dir.sh \
      data/$fld || exit 1;

    steps/compute_cmvn_stats.sh data/$fld exp/make_mfcc/$fld mfcc || exit 1;

    utils/fix_data_dir.sh data/$fld || exit 1;
  done
fi

if [ $stage -le 16 ]; then
  echo "$0: Starting  monophone training in exp/mono on" `date`
  steps/train_mono.sh \
    --nj 56 --cmd run.pl data/train data/lang exp/mono || exit 1;
fi

if [ $stage -le 17 ]; then
  (
    utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph

    steps/decode.sh \
      --nj 5 --cmd "$decode_cmd" exp/mono/graph data/ca16 exp/mono/decode_ca16
    ) &
fi

if [ $stage -le 18 ]; then
  echo "$0: Align with monophones."
  steps/align_si.sh --nj 56 --cmd run.pl data/train data/lang exp/mono \
    exp/mono_ali || exit 1;
fi

if [ $stage -le 19 ]; then
  echo "$0: Starting  triphone training in exp/tri1 on" `date`
  steps/train_deltas.sh --cluster-thresh 100 --cmd run.pl 3100 50000 \
    data/train data/lang exp/mono_ali exp/tri1 || exit 1;
fi

wait

if [    $stage -le 20 ]; then
  (
    utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph

    steps/decode.sh \
      --nj 5 --cmd "$decode_cmd" exp/tri1/graph data/ca16 exp/tri1/decode_ca16
  ) &
fi

if [ $stage -le 21 ]; then
  echo "$0: Aligning with triphones."
  steps/align_si.sh --nj 56 --cmd run.pl data/train data/lang exp/tri1 \
    exp/tri1_ali || exit 1;
fi

if [ $stage -le 22 ]; then
  echo "$0: Starting (lda_mllt) triphone training in exp/tri2b on" `date`
  steps/train_lda_mllt.sh --splice-opts "--left-context=3 --right-context=3" \
    3100 50000 data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
fi

wait

if [ $stage -le 23 ]; then
  echo "$0: Decoding with tri2b."
  (
    utils/mkgraph.sh data/lang_test exp/tri2b exp/tri2b/graph

    steps/decode.sh \
      --nj 5 --cmd "$decode_cmd" exp/tri2b/graph data/ca16 exp/tri2b/decode_ca16
  ) &
fi

if [ $stage -le 24 ]; then
  echo "$0: Aligning with lda and mllt adapted triphones."
  steps/align_si.sh --use-graphs true --nj 56 --cmd run.pl data/train \
    data/lang exp/tri2b exp/tri2b_ali || exit 1;
fi

if [ $stage -le 25 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b on" `date`
  steps/train_sat.sh --cmd run.pl 3100 50000 data/train data/lang exp/tri2b_ali \
    exp/tri3b || exit 1;
fi

wait

if [ $stage -le 26 ]; then
  echo "$0: Decoding with tri3b."
  (
    utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph

    steps/decode_fmllr.sh \
      --nj 5 --cmd "$decode_cmd" exp/tri3b/graph data/ca16 exp/tri3b/decode_ca16
  ) &
fi

if [ $stage -le 27 ]; then
  echo "$0: Starting exp/tri3b_ali on" `date`
  steps/align_fmllr.sh --nj 56 --cmd run.pl data/train data/lang exp/tri3b \
    exp/tri3b_ali || exit 1;
fi

if [ $stage -le 28 ]; then
  echo "$0: Training and testing chain models."
  local/chain/run_tdnn.sh || exit 1;
fi

# Local Variables:
# indent-tabs-mode: nil
# tab-width: 2
# End:

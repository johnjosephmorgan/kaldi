#!/bin/bash 

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

read_appen_train_2005_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ I/Iraqi\ Arabic-Audio/APPEN_BBN_2005
read_appen_train_2006_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-Audio/APPEN_1.5WAY_SEPT2006/Training\ Set
ma_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ I/Iraqi\ Arabic-Audio/MARINE_ACOUSTICS
twoway_appen_2006_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-Audio/APPEN_2WAY_SEPT2006/TRAINING
twoway_appen_2006_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/APPEN_2WAY_SEPT2006
twoway_appen_2007_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-Audio/APPEN_ADDITIONAL_2WAY_2007/TRAINING
twoway_appen_2007_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/APPEN_ADDITIONAL_2WAY_2007/Appen_additional_2-way_IA_Transcription_Training_20070530
detroit_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-Audio/DETROIT_2WAY_2006/TRAINING
detroit_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/DETROIT_2WAY_2006/Detroit_2-way_IA_Transcription_Training_20070302
dli_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-Audio/DLI_SEPT2006/TRAINING
dli_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/DLI_SEPT2006/Transcription
nist_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ III/Iraqi\ Arabic\ -\ Audio/Bilingual
nist_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ III/Iraqi\ Arabic\ -\ TX-TL/NISTSD_2WAY_BILINGUAL_2007-8
pendleton_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ I/Iraqi\ Arabic-Audio/Pendelton\ Audio
pendleton_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ I/Iraqi\ Arabic-TX-TL/PENDLETON_2005
san_diego_train_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-Audio/SAN_DIEGO_2WAY_2006/TRAINING
san_diego_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/SAN_DIEGO_2WAY_2006/SanDiego_2-way_IA_Transcription_TrainingSet_20070430
eval_audio_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ III/Iraqi\ Arabic\ -\ TX-TL/JUNE_EVAL_2008
eval_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ III/Iraqi\ Arabic\ -\ TX-TL/JUNE_EVAL_2008/TRANSTAC_JUNE_EVAL_2008_TRANSCRIPTION
tmpdir=data/local/tmp
gale_tmp_dir=$tmpdir/gale
transtac_tmpdir=$tmpdir/transtac
tmp_read_appen_train_2005_dir=$transtac_tmpdir/train/read/appen/2005
tmp_read_appen_train_2006_dir=$transtac_tmpdir/train/read/appen/2006
tmp_train_ma_dir=$transtac_tmpdir/train/read/ma/2006
tmp_twoway_appen_train_2006_dir=$transtac_tmpdir/train/twoway/appen/2006
tmp_twoway_appen_train_2007_dir=$transtac_tmpdir/train/twoway/appen/2007
tmp_twoway_detroit_train_2006_dir=$transtac_tmpdir/train/twoway/detroit/2006
tmp_twoway_dli_train_2006_dir=$transtac_tmpdir/train/twoway/dli/2006
tmp_twoway_nist_train_2007_dir=$transtac_tmpdir/train/twoway/nist/2007
tmp_twoway_pendleton_train_2005_dir=$transtac_tmpdir/train/twoway/pendleton/2005
tmp_twoway_san_diego_train_2006_dir=$transtac_tmpdir/train/twoway/san_diego/2006
tmp_eval_dir=$transtac_tmpdir/eval
tmp_dict_dir=data/local/tmp/dict
lex="/mnt/corpora/Tunisian_MSA/lexicon.txt"
g2p_input_text_files="data/dev/text data/train/text"
dir1=/mnt/corpora/LDC2013S02/
dir2=/mnt/corpora/LDC2013S07/
dir3=/mnt/corpora/LDC2014S07/
text1=/mnt/corpora/LDC2013T17/
text2=/mnt/corpora/LDC2013T04/
text3=/mnt/corpora/LDC2014T17/

if [ $stage -le 0 ]; then
  echo "$0: Preparing GALE data."
  local/gale/prepare_data.sh --dir1 $dir1 --dir2 $dir2 --dir3 $dir3 \
    --text1 $text1 --text2 $text2 --text3 $text3 || exit 1;
fi

if [ $stage -le 1 ]; then
    local/gale/train_gmms4alignment.sh || exit 1;
fi

if [ $stage -le 2 ]; then
  echo "$0: Getting a list of the  TRANSTAC read 2005 training .wav files."
  mkdir -p $tmp_read_appen_train_2005_dir/lists
  for i in $(seq 21); do
    echo "$0: Processing part $i of 21."
    find "$read_appen_train_2005_audio_dir/AllAudio${i}/Audio" -type f -name "*.wav" >> \
      $tmp_read_appen_train_2005_dir/wav_list.txt
  done
fi

if [ $stage -le 3 ]; then
  echo "$0: Getting a list of the  TRANSTAC Read 2006 training .wav files."
  mkdir -p $tmp_read_appen_train_2006_dir/lists
  find "$read_appen_train_2006_audio_dir" -type f -name "*.wav" > \
    $tmp_read_appen_train_2006_dir/wav_list.txt
fi

if [ $stage -le 4 ]; then
  echo "$0: Getting a list of the  TRANSTAC Marine Acoustics training .wav files."
  mkdir -p $tmp_train_ma_dir/lists
  find "$ma_train_audio_dir" -type f -name "*.wav" > $tmp_train_ma_dir/wav_list.txt
fi

if [ $stage -le 5 ]; then
  echo "$0: Getting a list of the  TRANSTAC 2way  2006 training .wav files."
  mkdir -p $tmp_twoway_appen_train_2006_dir/lists
  find "$twoway_appen_2006_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_appen_train_2006_dir/wav_files.txt
fi

if [ $stage -le 6 ]; then
  echo "$0: Getting a list of the TRANSTAC 2way 2006 training transcript files."
  find "$twoway_appen_2006_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_appen_train_2006_dir/tdf_files.txt
fi

if [ $stage -le 7 ]; then
  echo "$0: Getting a list of the  TRANSTAC 2way appen 2007 training .wav files."
  mkdir -p $tmp_twoway_appen_train_2007_dir/lists
  find "$twoway_appen_2007_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_appen_train_2007_dir/wav_files.txt
fi

if [ $stage -le 8 ]; then
  echo "$0: Getting a list of the TRANSTAC 2way 2007 training transcript files."
  find "$twoway_appen_2007_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_appen_train_2007_dir/tdf_files.txt
fi

if [ $stage -le 9 ]; then
  echo "$0: Getting a list of the  DETROIT 2way 2006 training .wav files."
  mkdir -p $tmp_twoway_detroit_train_2006_dir/lists
  find "$detroit_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_detroit_train_2006_dir/wav_files.txt
fi

if [ $stage -le 10 ]; then
  echo "$0: Getting a llist of the TRANSTAC DETROIT 2006 2way training transcript files."
  find "$detroit_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_detroit_train_2006_dir/tdf_files.txt
fi

if [ $stage -le 11 ]; then
  echo "$0: Getting a list of the  TRANSTAC DLI 2006 training .wav files."
  mkdir -p $tmp_twoway_dli_train_2006_dir/lists
  find "$dli_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_dli_train_2006_dir/wav_files.txt
fi

if [ $stage -le 12 ]; then
  echo "$0: Getting a list of the TRANSTAC Iraqi Arabic DLI 2006 training transcript files."
  find "$dli_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_dli_train_2006_dir/tdf_files.txt
fi

if [ $stage -le 13 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi ARABIC NIST 2007 training .wav files."
  mkdir -p $tmp_twoway_nist_train_2007_dir/lists
  find "$nist_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_nist_train_2007_dir/wav_files.txt
fi

if [ $stage -le 14 ]; then
  echo "$0: Getting a list of the TRANSTAC Iraqi Arabic NIST 2007 training transcript files."
  find "$nist_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_nist_train_2007_dir/tdf_files.txt
fi

if [ $stage -le 15 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi Arabic Camp Pendleton 2005 training .wav files."
  mkdir -p $tmp_twoway_pendleton_train_2005_dir/lists
  find "$pendleton_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_pendleton_train_2005_dir/wav_files.txt
fi

if [ $stage -le 16 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi Arabic Camp Pendleton transcript .txt files."
  find "$pendleton_train_txt_dir" -type f -name "*.txt" > \
    $tmp_twoway_pendleton_train_2005_dir/tdf_files.txt
fi

if [ $stage -le 17 ]; then
  echo "$0: Getting a list of the  TRANSTAC Iraqi Arabic San  Diego 2006 2way training .wav files."
  mkdir -p $tmp_twoway_san_diego_train_2006_dir/lists
  find "$san_diego_train_audio_dir" -type f -name "*.wav" > \
    $tmp_twoway_san_diego_train_2006_dir/wav_files.txt
fi

if [ $stage -le 18 ]; then
  echo "$0: Getting a list of the TRANSTAC Iraqi Arabic San Diego 2006 2way training transcript files."
  find "$san_diego_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_san_diego_train_2006_dir/tdf_files.txt
fi

if [ $stage -le 19 ]; then
  echo "$0: Getting  a list of the TRANSTAC Iraqi Arabic Eval .wav files."
  mkdir -p $tmp_eval_dir
  find "$eval_audio_dir" -type f -name "*.wav" > $tmp_eval_dir/wav_files.txt
  echo "$0: Getting  TRANSTAC eval transcript files."
  find "$eval_txt_dir" -type f -name "*.txt" > $tmp_eval_dir/txt_files.txt
fi

if [ $stage -le 20 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic APPEN read 2005 training data."
  local/transtac/read/appen/2005/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh data/local/tmp/transtac/train/read/appen/2005/lists
  echo "$0: extracting acoustic features for Transtac Appen 2005."
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 data/local/tmp/transtac/train/read/appen/2005/lists
  steps/compute_cmvn_stats.sh data/local/tmp/transtac/train/read/appen/2005/lists 
  utils/fix_data_dir.sh data/local/tmp/transtac/train/read/appen/2005/lists
  ln -s data/local/tmp/transtac/train/read/appen/2005/lists data/transtac_read_appen_2005/train
  echo "$0: Train monophones on transtac_read_appen_2005."
  steps/train_mono.sh  --cmd "$train_cmd" --nj 56 data/transtac_read_appen_2005/train \
    data/lang exp/transtac_read_appen_2005/mono || exit 1;
  echo "$0: aligning with transtac_read_appen_2005 monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_read_appen_2005/train data/lang \
		     exp/transtac_read_appen_2005/mono exp/transtac_read_appen_2005/mono_ali || exit 1;
  echo "$0: Starting  transtac_read_appen_2005 triphone training in exp/gale/tri1."
  steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25 \
    5500 90000 \
    data/transtac_read_appen_2005/train data/lang exp/transtac_read_appen_2005/mono_ali exp/transtac_read_appen_2005/tri1 || exit 1;
  echo "$0: Aligning with /transtac_read_appen_2005 triphones tri1."
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_read_appen_2005/train data/lang \
    exp/transtac_read_appen_2005/tri1 exp/transtac_read_appen_2005/tri1_ali || exit 1;s
  echo "$0: Starting transtac_read_appen_2005 lda_mllt triphone training in exp/gale/tri2b."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5500 90000 \
    data/transtac_read_appen_2005/train data/lang exp/transtac_read_appen_2005/tri1_ali exp/transtac_read_appen_2005/tri2b || exit 1;
  echo "$0: aligning with transtac_read_appen_2005 lda and mllt adapted triphones $tri2b."
  steps/align_si.sh  --nj 56 \
    --cmd "$train_cmd" \
    --use-graphs true data/transtac_read_appen_2005/train data/lang exp/transtac_read_appen_2005/tri2b \
    exp/transtac_read_appen_2005/tri2b_ali || exit 1;
  echo "$0: Starting transtac_read_appen_2005 SAT triphone training in exp/gale/tri3b."
  steps/train_sat.sh --cmd "$train_cmd" \
    5500 90000 \
    data/transtac_read_appen_2005/train data/lang exp/transtac_read_appen_2005/tri2b_ali exp/transtac_read_appen_2005/tri3b || exit 1;
fi

if [ $stage -le 21 ]; then
  echo "$0: Preparing the TRANSTAC read APPEN 2006 training data."
  local/transtac/read/appen/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $tmp_read_appen_train_2006_dir/lists
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $tmp_read_appen_train_2006_dir/lists
  steps/compute_cmvn_stats.sh $tmp_read_appen_train_2006_dir/lists
  utils/fix_data_dir.sh $tmp_read_appen_train_2006_dir/lists
  ln -s data/local/tmp/transtac/train/read/appen/2006/lists data/transtac_read_appen_2006/train
  echo "$0: Train monophones on transtac_read_appen_2006."
  steps/train_mono.sh  --cmd "$train_cmd" --nj 56 data/transtac_read_appen_2006/train \
    data/lang exp/transtac_read_appen_2006/mono || exit 1;
  echo "$0: aligning with transtac_read_appen_2006 monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_read_appen_2006/train data/lang \
    exp/transtac_read_appen_2006/mono exp/transtac_read_appen_2006/mono_ali || exit 1;
  echo "$0: Starting  transtac_read_appen_2006 triphone training in exp/gale/tri1."
  steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25 \
    5500 90000 \
    data/transtac_read_appen_2006/train data/lang exp/transtac_read_appen_2006/mono_ali exp/transtac_read_appen_2006/tri1 || exit 1;
  echo "$0: Aligning with /transtac_read_appen_2006 triphones tri1."
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_read_appen_2006/train data/lang \
    exp/transtac_read_appen_2006/tri1 exp/transtac_read_appen_2006/tri1_ali || exit 1;s
  echo "$0: Starting transtac_read_appen_2006 lda_mllt triphone training in exp/transtac_read_appen_2006/tri2b."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5500 90000 \
    data/transtac_read_appen_2006/train data/lang exp/transtac_read_appen_2006/tri1_ali exp/transtac_read_appen_2006/tri2b || exit 1;
  echo "$0: aligning with transtac_read_appen_2006 lda and mllt adapted triphones $tri2b."
  steps/align_si.sh  --nj 56 \
    --cmd "$train_cmd" \
    --use-graphs true data/transtac_read_appen_2006/train data/lang exp/transtac_read_appen_2006/tri2b \
    exp/transtac_read_appen_2006/tri2b_ali || exit 1;
  echo "$0: Starting transtac_read_appen_2006 SAT triphone training in exp/transtac_read_appen_2006/tri3b."
  steps/train_sat.sh --cmd "$train_cmd" \
    5500 90000 \
    data/transtac_read_appen_2006/train data/lang exp/transtac_read_appen_2006/tri2b_ali exp/transtac_read_appen_2006/tri3b || exit 1;
fi

if [ $stage -le 22 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic Marine Acoustics 2006 training data."
  local/transtac/read/ma/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $tmp_train_ma_dir/lists
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $tmp_train_ma_dir/lists
  steps/compute_cmvn_stats.sh $tmp_train_ma_dir/lists
  utils/fix_data_dir.sh $tmp_train_ma_dir/lists
fi

if [ $stage -le 23 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way APPEN 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/appen/2006/lists
  local/transtac/twoway/appen/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/appen/2006/lists || exit 1;
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $transtac_tmpdir/train/twoway/appen/2006/lists
  steps/compute_cmvn_stats.sh $transtac_tmpdir/train/twoway/appen/2006/lists
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/appen/2006/lists || exit 1;
fi

if [ $stage -le 24 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way APPEN 2007 training data."
  mkdir -p $transtac_tmpdir/train/twoway/appen/2007/lists
  local/transtac/twoway/appen/2007/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/appen/2007/lists || exit 1;
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $transtac_tmpdir/train/twoway/appen/2007/lists
  steps/compute_cmvn_stats.sh $transtac_tmpdir/train/twoway/appen/2007/lists
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/appen/2007/lists || exit 1;
fi

if [ $stage -le 25 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way DETROIT 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/detroit/2006/lists
  local/transtac/twoway/detroit/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/detroit/2006/lists || exit 1;
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $transtac_tmpdir/train/twoway/detroit/2006/lists
  steps/compute_cmvn_stats.sh $transtac_tmpdir/train/twoway/detroit/2006/lists
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/detroit/2006/lists || exit 1;
fi

if [ $stage -le 26 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way DLI 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/dli/2006/lists
  local/transtac/twoway/dli/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/dli/2006/lists || exit 1;
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $transtac_tmpdir/train/twoway/dli/2006/lists
  steps/compute_cmvn_stats.sh $transtac_tmpdir/train/twoway/dli/2006/lists
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/dli/2006/lists || exit 1;
fi

if [ $stage -le 27 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way NIST 2007 training data."
  mkdir -p $transtac_tmpdir/train/twoway/nist/2007/lists
  local/transtac/twoway/nist/2007/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/nist/2007/lists || exit 1;
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $transtac_tmpdir/train/twoway/nist/2007/lists
  steps/compute_cmvn_stats.sh $transtac_tmpdir/train/twoway/nist/2007/lists
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/nist/2007/lists || exit 1;
fi

if [ $stage -le 28 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way Pendleton 2005 training data."
  mkdir -p $transtac_tmpdir/train/twoway/pendleton/2005/lists
  local/transtac/twoway/pendleton/2005/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/pendleton/2005/lists || exit 1;
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $transtac_tmpdir/train/twoway/pendleton/2005/lists
  steps/compute_cmvn_stats.sh $transtac_tmpdir/train/twoway/pendleton/2005/lists
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/pendleton/2005/lists || exit 1;
fi

if [ $stage -le 29 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way San Diego 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/san_diego/2006/lists
  local/transtac/twoway/san_diego/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/san_diego/2006/lists || exit 1;
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 $transtac_tmpdir/train/twoway/san_diego/2006/lists
  steps/compute_cmvn_stats.sh $transtac_tmpdir/train/twoway/san_diego/2006/lists
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/san_diego/2006/lists || exit 1;
fi

if [ $stage -le 30 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic eval data."
  mkdir -p $tmp_eval_dir/lists
  local/transtac/eval/make_lists.pl || exit 1;
  utils/fix_data_dir.sh $tmp_eval_dir/lists || exit 1;
fi

if [ $stage -le 31 ]; then
  echo "$0: Preparing the Libyan dev and test sets."
  local/libyan/prepare_data.sh || exit 1;
fi

if [ $stage -le 32 ]; then
  echo "$0: Consolidating  TRANSTAC Iraqi Arabic read and twoway training data."
  mkdir -p $transtac_tmpdir/lists/train
  for d in read/appen/2005 read/appen/2006 read/ma/2006 twoway/appen/2006 twoway/appen/2007 twoway/detroit/2006 twoway/dli/2006 twoway/nist/2007 twoway/pendleton/2005 twoway/san_diego/2006; do
    echo "$0: Copying corpus $d."
    for y in wav.scp utt2spk text segments; do
      echo "File: $y."
      cat $transtac_tmpdir/train/$d/lists/$y >> $transtac_tmpdir/lists/train/$y
    done
  done
  utils/utt2spk_to_spk2utt.pl $transtac_tmpdir/lists/train/utt2spk > $transtac_tmpdir/lists/train/spk2utt
  utils/fix_data_dir.sh $transtac_tmpdir/lists/train
fi

if [ $stage -le 33 ]; then
  echo "$0: Consolidating  GALE MSA Arabic and TRANSTAC  Iraqi Arabic training data."
  mkdir -p data/train
  for e in gale transtac; do
    echo "$0: Copying Corpus $e."
    for z in wav.scp utt2spk text segments; do
      echo "$z"
      cat data/local/tmp/$e/lists/train/$z >> data/train/$z
    done
  done
  utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
  utils/fix_data_dir.sh data/train
fi

if [ $stage -le 34 ]; then
  echo "$0: Consolidating GALE test data."
  mkdir -p data/gale_test
  for x in wav.scp utt2spk text segments; do
    cat data/local/tmp/gale/lists/test/$x >> data/gale_test/$x
  done
  utils/utt2spk_to_spk2utt.pl data/gale_test/utt2spk > data/gale_test/spk2utt
  utils/fix_data_dir.sh data/gale_test
fi

if [ $stage -le 35 ]; then
  echo "$0: Consolidating TRANSTAC Iraqi Arabic eval data."
  mkdir -p data/eval
  for x in wav.scp utt2spk text; do
    cat $tmp_eval_dir/lists/$x >> data/eval/$x
  done
  utils/utt2spk_to_spk2utt.pl data/eval/utt2spk > data/eval/spk2utt
  utils/fix_data_dir.sh data/eval
fi

if [ $stage -le 36 ]; then
  echo "$0: Preparing the qcri lexicon."
  local/prepare_dict.sh $lex $tmp_dict_dir/init || exit 1;
fi

if [ $stage -le 37 ]; then
  echo "$0: Training a QCRI g2p model."
  local/g2p/train_g2p.sh $tmp_dict_dir/init \
    $tmp_dict_dir/g2p || exit 1;
fi

if [ $stage -le 38 ]; then
  echo "$0: Applying the QCRI g2p."
  local/g2p/apply_g2p.sh $tmp_dict_dir/g2p/model.fst \
    $tmp_dict_dir/work $tmp_dict_dir/init/lexicon.txt \
    $tmp_dict_dir/init/lexicon_with_tabs.txt $g2p_input_text_files || exit 1;
fi

if [ $stage -le 39    ]; then
  echo "$0: Delimiting fields with space instead of tabs."
  mkdir -p $tmp_dict_dir/final
  expand -t 1 $tmp_dict_dir/init/lexicon_with_tabs.txt > $tmp_dict_dir/final/lexicon.txt
fi

if [ $stage -le 40    ]; then
  echo "$0: Preparing expanded QCRI lexicon."
  local/prepare_dict.sh $tmp_dict_dir/final/lexicon.txt \
    data/local/dict || exit 1;
  echo "$0: Adding <UNK> to the lexicon."
  echo "<UNK> SPN" >> data/local/dict/lexicon.txt
fi

if [ $stage -le 41 ]; then
  echo "$0: Preparing the QCRI lang directory."
  utils/prepare_lang.sh data/local/dict "<UNK>" \
    data/local/lang_tmp data/lang || exit 1;
fi

if [ $stage -le 42 ]; then
  echo "$0: Getting data for lm training."
  mkdir -p $tmpdir/lm
  echo "$0: Put the GALE training transcripts in the lm training set."
  cut -d " " -f 2- $gale_tmp_dir/lists/{test,train}/text >> $tmpdir/lm/train.txt
fi

if [ $stage -le 43 ]; then
  echo "$0: Preparing a 3-gram lm."
  local/prepare_lm.sh || exit 1;
fi

if [ $stage -le 44 ]; then
  echo "$0: Making G.fst."
  mkdir -p data/lang_test
  utils/format_lm.sh data/lang data/local/lm/tg.arpa.gz \
    data/local/dict/lexicon.txt data/lang_test || exit 1;
fi

if [ $stage -le 45 ]; then
  echo "$0: Creating ConstArpaLm format language model with $g."
  utils/build_const_arpa_lm.sh data/local/lm/tg.arpa.gz \
    data/lang data/lang_test || exit 1;
fi

if [ $stage -le 46 ]; then
  for f in dev eval test train gale_test; do
    echo "$0: extracting acoustic features for $f."
    utils/fix_data_dir.sh data/$f
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 data/$f exp/make_mfcc/$f mfcc
    utils/fix_data_dir.sh data/$f
    steps/compute_cmvn_stats.sh data/$f exp/make_mfcc mfcc
    utils/fix_data_dir.sh data/$f
  done
fi

if [ $stage -le 47 ]; then
  echo "$0: monophone training"
  steps/train_mono.sh  --cmd "$train_cmd" --nj 56 data/train \
    data/lang exp/mono || exit 1;
fi

if [ $stage -le 48 ]; then
  echo "$0: aligning with monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/train data/lang \
    exp/mono exp/mono_ali || exit 1;
fi

if [ $stage -le 49 ]; then
  echo "$0: Starting  triphone training in exp/tri1."
  steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25 \
    5500 90000 \
    data/train data/lang exp/mono_ali exp/tri1 || exit 1;
fi

if [ $stage -le 50 ]; then
  echo "$0: Aligning with triphones tri1."
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/train data/lang \
		     exp/tri1 exp/tri1_ali || exit 1;
  fi

if [ $stage -le 51 ]; then
  echo "$0: Starting lda_mllt triphone training in exp/tri2b."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5500 90000 \
    data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
fi

if [ $stage -le 52 ]; then
  echo "$0: aligning with lda and mllt adapted triphones $tri2b."
  steps/align_si.sh  --nj 56 \
    --cmd "$train_cmd" \
    --use-graphs true data/train data/lang exp/tri2b \
    exp/tri2b_ali || exit 1;
fi

if [ $stage -le 53 ]; then
  echo "$0: Starting SAT triphone training in exp/tri3b."
  steps/train_sat.sh --cmd "$train_cmd" \
    5500 90000 \
    data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
fi

if [ $stage -le 54 ]; then
  (
    echo "$0: making decoding graph for SAT and tri3b models."
    utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph || exit 1;

    for f in test eval dev gale_test; do
      echo "$0: Decoding $f with sat models."
      nspk=$(wc -l < data/$f/spk2utt)
      steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nspk \
        exp/tri3b/graph data/$f \
  	exp/tri3b/decode_${f} || exit 1;
    done
  ) &
fi

if [ $stage -le 55 ]; then
  echo "$0: Starting exp/tri3b_ali"
  steps/align_fmllr.sh --cmd "$train_cmd" --nj 56 data/train data/lang \
			 exp/tri3b exp/tri3b_ali || exit 1;
fi

if [ $stage -le 56 ]; then
  echo "$0: Training and testing chain models."
  local/chain2/run_tdnn.sh || exit 1;
fi

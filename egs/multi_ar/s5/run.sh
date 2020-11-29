#!/bin/bash 

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set -u

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
  echo "$0: Preparing the qcri lexicon."
  local/prepare_dict.sh $lex $tmp_dict_dir/init || exit 1;
fi

if [ $stage -le 1 ]; then
  echo "$0: Training a QCRI g2p model."
  local/g2p/train_g2p.sh $tmp_dict_dir/init \
    $tmp_dict_dir/g2p || exit 1;
fi

if [ $stage -le 2 ]; then
  echo "$0: Applying the QCRI g2p."
  local/g2p/apply_g2p.sh $tmp_dict_dir/g2p/model.fst \
    $tmp_dict_dir/work $tmp_dict_dir/init/lexicon.txt \
    $tmp_dict_dir/init/lexicon_with_tabs.txt $g2p_input_text_files || exit 1;
fi

if [ $stage -le 3    ]; then
  echo "$0: Delimiting fields with space instead of tabs."
  mkdir -p $tmp_dict_dir/final
  expand -t 1 $tmp_dict_dir/init/lexicon_with_tabs.txt > $tmp_dict_dir/final/lexicon.txt
fi

if [ $stage -le 4    ]; then
  echo "$0: Preparing expanded QCRI lexicon."
  local/prepare_dict.sh $tmp_dict_dir/final/lexicon.txt \
    data/local/dict || exit 1;
  echo "$0: Adding <UNK> to the lexicon."
  echo "<UNK> SPN" >> data/local/dict/lexicon.txt
fi

if [ $stage -le 5 ]; then
  echo "$0: Preparing the QCRI lang directory."
  utils/prepare_lang.sh data/local/dict "<UNK>" \
    data/local/lang_tmp data/lang || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "$0: Preparing GALE data."
  local/gale/prepare_data.sh --dir1 $dir1 --dir2 $dir2 --dir3 $dir3 \
    --text1 $text1 --text2 $text2 --text3 $text3 || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: Build GALE gmm system to get alignments."
  local/gale/train_gmms4alignment.sh || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Preparing Transtac Read training data."
  local/transtac/read/prepare_data.sh \
    "$read_appen_train_2005_audio_dir" \
    "$read_appen_train_2006_audio_dir" \
    "$ma_train_audio_dir"
fi

if [ $stage -le 9 ]; then \
  echo "$0: Build Transtac Read GMM system for alignments."
  local/transtac/read/train_gmms4alignments.sh
fi

if [ $stage -le 10 ]; then
  local/transtac/twoway/prepare_data.sh \
    "$twoway_appen_2006_train_audio_dir" \
    "$twoway_appen_2006_train_txt_dir" \
    "$twoway_appen_2007_train_audio_dir" \
    "$twoway_appen_2007_train_txt_dir" \
    "$detroit_train_audio_dir" \
    "$detroit_train_txt_dir" \
    "$dli_train_audio_dir" \
    "$dli_train_txt_dir" \
    "$nist_train_audio_dir" \
    "$nist_train_txt_dir" \
    "$pendleton_train_audio_dir" \
    "$pendleton_train_txt_dir" \
    "$san_diego_train_audio_dir" \
    "$san_diego_train_txt_dir"
fi

if [ $stage -le 11 ]; then
    echo "$0: Build Transtac Twoway GMM system for alignments."
    local/transtac/twoway/train_gmms4alignments.sh
fi

if [ $stage -le 12 ]; then
  echo "$0: Getting  a list of the TRANSTAC Iraqi Arabic Eval .wav files."
  mkdir -p $tmp_eval_dir
  find "$eval_audio_dir" -type f -name "*.wav" > $tmp_eval_dir/wav_files.txt
  echo "$0: Getting  TRANSTAC eval transcript files."
  find "$eval_txt_dir" -type f -name "*.txt" > $tmp_eval_dir/txt_files.txt
fi

if [ $stage -le 13 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic eval data."
  mkdir -p $tmp_eval_dir/lists
  local/transtac/eval/make_lists.pl || exit 1;
  utils/fix_data_dir.sh $tmp_eval_dir/lists || exit 1;
fi

if [ $stage -le 14 ]; then
  echo "$0: Preparing the Libyan dev and test sets."
  local/libyan/prepare_data.sh || exit 1;
fi

if [ $stage -le 15 ]; then
  echo "$0: Getting data for lm training."
  mkdir -p $tmpdir/lm
  echo "$0: Put the GALE training transcripts in the lm training set."
  cut -d " " -f 2- $gale_tmp_dir/lists/{test,train}/text >> $tmpdir/lm/train.txt
fi

if [ $stage -le 16 ]; then
  echo "$0: Preparing a 3-gram lm."
  local/prepare_lm.sh || exit 1;
fi

if [ $stage -le 17 ]; then
  echo "$0: Making G.fst."
  mkdir -p data/lang_test
  utils/format_lm.sh data/lang data/local/lm/tg.arpa.gz \
    data/local/dict/lexicon.txt data/lang_test || exit 1;
fi

if [ $stage -le 18 ]; then
  echo "$0: Creating ConstArpaLm format language model with g."
  utils/build_const_arpa_lm.sh data/local/lm/tg.arpa.gz \
    data/lang data/lang_test || exit 1;
fi

if [ $stage -le 19 ]; then
  echo "$0: Training and testing chain models."
  local/chain2/run_tdnn.sh || exit 1;
fi

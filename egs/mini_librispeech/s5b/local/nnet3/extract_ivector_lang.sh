#!/usr/bin/env bash

# Copyright 2016 Pegah Ghahremani

# This scripts extracts iVector using global iVector extractor
# trained on all languages in multilingual setup.

. ./cmd.sh
set -e
stage=1
train_set=train_sp_hires # train_set used to extract ivector using shared ivector
                         # extractor.
ivector_suffix=_gb
nnet3_affix=
#keyword search default
glmFile=conf/glm
duptime=0.5
case_insensitive=false
use_pitch=false
# Lexicon and Language Model parameters
oovSymbol="<unk>"
lexiconFlags="-oov <unk>"
boost_sil=1.5 #  note from Dan: I expect 1.0 might be better (equivalent to not
              # having the option)... should test.
cer=0

#Declaring here to make the definition inside the language conf files more
# transparent and nice
declare -A train_kwlists
declare -A dev10h_kwlists
declare -A dev2h_kwlists
declare -A evalpart1_kwlists
declare -A eval_kwlists
declare -A shadow_kwlists

# just for back-compatibility
declare -A dev10h_more_kwlists
declare -A dev2h_more_kwlists
declare -A evalpart1_more_kwlists
declare -A eval_more_kwlists
declare -A shadow_more_kwlists
[ -f ./path.sh ] && . ./path.sh; # source the path.
[ -f ./cmd.sh ] && . ./cmd.sh; # source train and decode cmds.

. ./utils/parse_options.sh

lang=$1
global_extractor=$2

if [ $stage -le 7 ]; then
  # We extract iVectors on all the train_nodup data, which will be what we
  # train the system on.
  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 data/$lang/${train_set} data/$lang/${train_set}_max2
  if [ ! -f exp/$lang/nnet3${nnet3_affix}/ivectors_${train_set}${ivector_suffix}/ivector_online.scp ]; then
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 200 \
      data/$lang/${train_set}_max2 $global_extractor exp/$lang/nnet3${nnet3_affix}/ivectors_${train_set}${ivector_suffix} || exit 1;
  fi
fi
exit 0;

#!/bin/bash
if [ -d data/local/tmp ]; then
    rm -Rf data/local/tmp
    fi

mkdir -p data/local/tmp

if [ -d data/train_a ]; then
    rm -Rf data/train_a
fi

if [ -d data/train_b ]; then
    rm -Rf data/train_b
fi

if [ -d data/prompts ]; then
    rm -Rf data/prompts
    fi

# tools
tok_home=/home/tools/mosesdecoder/scripts/tokenizer
lc=$tok_home/lowercase.perl
normalizer="$tok_home/normalize-punctuation.perl -l fr"
tokenizer="$tok_home/tokenizer.perl -l fr"
deescaper=$tok_home/deescape-special-chars.perl

# extract  the yaounde prompts
cut \
    -f 1 \
    local/src/yaounde_read_prompts.txt > \
    data/local/tmp/yaounde_prompts_id.txt

cut \
    -f 2 \
    local/src/yaounde_read_prompts.txt > \
    data/local/tmp/yaounde_sents.txt

# condition the prompts
$lc < \
    data/local/tmp/yaounde_sents.txt | \
    $normalizer | \
    $tokenizer | \
    $deescaper | \
    local/yaounde_remove.pl \
	> \
	data/local/tmp/yaounde_prompts_conditioned.txt

# put the prompts and their IDs back together
paste \
    data/local/tmp/yaounde_prompts_id.txt \
    data/local/tmp/yaounde_prompts_conditioned.txt > \
    data/local/tmp/yaounde_prompts.txt

for half in a b; do
    # get wav file names
    local/yaounde_get_wav_filenames_${half}.sh

    local/yaounde_prompts2prompts4speaker.pl \
    data/local/tmp/yaounde_wav_filenames_${half}.txt \
    data/local/tmp/yaounde_prompts.txt

    local/yaounde_get_all_speaker_names.pl  \
    local/src/yaounde_read_speakers_${half}.txt > \
    data/local/tmp/yaounde_all_speakers_${half}.txt

    local/yaounde_get_transcriptions_${half}.sh

    local/yaounde_get_utt2text.pl \
    data/local/tmp/yaounde_trans_${half}_unsorted.txt > \
    data/local/tmp/yaounde_utt2text_${half}_unsorted.txt

    local/yaounde_get_utt2spk_${half}.pl

    local/yaounde_get_spk2utt_${half}.pl

    local/yaounde_get_utt2wav_filename_${half}.pl

done

mkdir -p data/train_a

local/yaounde_sort_train_transcriptions_a.sh

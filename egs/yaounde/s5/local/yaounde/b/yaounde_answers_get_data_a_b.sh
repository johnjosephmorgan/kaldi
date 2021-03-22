#!/bin/bash
# tools
tok_home=/home/tools/mosesdecoder/scripts/tokenizer
lc=$tok_home/lowercase.perl
normalizer="$tok_home/normalize-punctuation.perl -l fr"
tokenizer="$tok_home/tokenizer.perl -l fr"
deescaper=$tok_home/deescape-special-chars.perl

for half in a b; do
    # get wav file names
    local/yaounde_answers_get_wav_filenames_${half}.sh
done
exit
# move the files to make them yaounde answers specific
mv $dir/wav_filenames.txt $dir/answers_wav_filenames.txt
mv $dir/speaker_directory_paths.txt $dir/answers_speaker_directory_paths.txt

# get the questions for the yaounde answers 
cut -f 1 local/src/yaounde_answers_questions.txt> $dir/yaounde_questions_id.txt
cut -f 2 local/src/yaounde_answers_questions.txt > $dir/yaounde_questions_sents.txt

$lc < $dir/yaounde_questions_sents.txt | $normalizer | $tokenizer | \
    $deescaper | local/remove.pl > $dir/yaounde_questions_conditioned.txt
paste $dir/yaounde_questions_id.txt $dir/yaounde_questions_conditioned.txt > \
      $dir/answers_questions.txt

local/prompts2prompts4speaker.pl \
    $dir/answers_wav_filenames.txt \
    $dir/answers_questions.txt

local/get_all_speaker_names.sh $data

mv $dir/speakers_all.txt $dir/answers_speakers_all.txt

local/get_speaker_names.pl \
    $dir/answers_speaker_directory_paths.txt \
    answers > \
    $dir/answers_speaker_names.txt

local/get_transcriptions.sh answers

local/get_utt2text.pl \
    $dir/answers_trans_unsorted.txt > \
    $dir/answers_utt2text_unsorted.txt

local/get_utt2spk.sh $data answers

local/get_spk2utt.sh $data answers

local/get_utt2wav_filename.pl \
    $data \
    $dir/answers_speaker_names.txt > \
    $dir/answers_wav_unsorted.scp

mkdir -p data/answers

fld=answers
localdata=data/local
localtmp=$localdata/tmp/answers
outdir=data
sort  -u $dir/${fld}_wav_unsorted.scp > ${outdir}/${fld}/wav.scp
sort -u  $dir/${fld}_spk2utt_unsorted.txt > ${outdir}/${fld}/spk2utt
sort -u  $dir/${fld}_utt2spk_unsorted.txt > ${outdir}/${fld}/utt2spk
sort -u  $dir/${fld}_utt2text_unsorted.txt > ${outdir}/${fld}/filename2text
sort -u  $dir/${fld}_utt2text_unsorted.txt > ${outdir}/${fld}/text

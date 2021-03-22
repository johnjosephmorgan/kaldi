#!/bin/bash

wav_home=$1
tmpdir=data/local/tmp/yaounde

mkdir -p $tmpdir

# tools
# The tokenizer is from the mosesdecoder 
tok_home=local/tokenizer
lc=$tok_home/lowercase.perl
normalizer="$tok_home/normalize-punctuation.perl -l fr"
tokenizer="$tok_home/tokenizer.perl -l fr"
deescaper=$tok_home/deescape-special-chars.perl

# extract  the yaounde prompts
cut -f 1 local/yaounde/read_prompts.tsv > $tmpdir/prompts_id.txt
cut -f 2 local/yaounde/read_prompts.tsv > $tmpdir/sents.txt

# condition the prompts
$lc < $tmpdir/sents.txt | $normalizer | $tokenizer | $deescaper | \
  local/yaounde/condition.pl > $tmpdir/prompts_conditioned.txt

# put the prompts and their IDs back together
paste $tmpdir/prompts_id.txt $tmpdir/prompts_conditioned.txt > $tmpdir/prompts.txt

# get random lists of speakers
find $wav_home -mindepth 1 -maxdepth 1 -type d | shuf | tee \
  $tmpdir/read_speakers_a+b.txt | head -n 42 > $tmpdir/read_speakers_a.txt
tail -n 42 $tmpdir/read_speakers_a+b.txt > $tmpdir/read_speakers_b.txt

for g in a b; do
  echo "$0: Getting wav files for $g."
  mkdir -p $tmpdir/$g
  {
    while read line; do
      find $line -type f -name "*.wav"
    done
  } < $tmpdir/read_speakers_${g}.txt  > $tmpdir/$g/wav_filenames.txt

  local/yaounde/$g/make_lists.pl
done

for h in a b; do
  echo "Writing the lists under data/train_${h}" 

  mkdir -p data/train_${h}
  for x in wav.scp utt2spk text; do
    cat $tmpdir/$h/lists/$x | tr -d "\r" > data/train_${h}/$x
  done
done

for i in a b; do
  utils/utt2spk_to_spk2utt.pl data/train_${i}/utt2spk > data/train_${i}/spk2utt
done

for j in a b; do
  utils/fix_data_dir.sh data/train_${j} || exit 1;
done

# Now put the lists under data/train_sup and data/train_unsup
for k in a b; do
  cp -R data/train_${k} data/train_${k}_sup
done

# Now cross the groups
# Put train_a under train_b_unsup
# Put train_b under train_a_unsup
cp -R data/train_a data/train_b_unsup
cp -R data/train_b data/train_a_unsup

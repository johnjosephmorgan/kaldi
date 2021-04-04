#!/bin/bash  

# Copyright 2018 John Morgan
# Apache 2.0.

# configuration variables
tmpdir=data/local/tmp
downloaddir=$(pwd)
datadir=$downloaddir/Tunisian_MSA/data
tmptunis=$tmpdir/tunis
tmplibyan=$tmpdir/libyan
# location of test data 
libyansrc=$datadir/speech/test/Libyan_MSA
# end of configuration variable settings

# process the Tunisian MSA devtest data
# get list of  wav files
for s in devtest/CTELLONE/Recordings_Arabic/6 devtest/CTELLTHREE/Recordings_Arabic/10; do
  echo "$0: looking for wav files for $s."
  mkdir -p $tmptunis/$s
  find $datadir/speech/$s -type f \
  -name "*.wav" | grep Recordings_Arabic > $tmptunis/$s/wav.txt

  local/devtest_recordings_make_lists.pl \
  $datadir/transcripts/devtest/recordings.tsv $s tunis

  mkdir -p data/devtest

  for x in wav.scp utt2spk text; do
    cat     $tmptunis/$s/$x | tr "	" " " >> data/devtest/$x
  done
done

#utils/utt2spk_to_spk2utt.pl data/devtest/utt2spk | sort > data/devtest/spk2utt
#utils/fix_data_dir.sh data/devtest

# process Anwar's Libyan MSA devtest data
# get list of  wav files
for s in devtest/anwar_libyan_msa/Recordings_Arabic/1; do
  echo "$0: looking for wav files for $s."
  mkdir -p $tmplibyan/$s
  find $datadir/speech/$s -type f \
  -name "*.wav" | grep Recordings_Arabic > $tmplibyan/$s/wav.txt

  local/devtest_anwar_recordings_make_lists.pl \
  $datadir/transcripts/devtest/recordings.tsv $s libyan

  for x in wav.scp utt2spk text; do
    cat     $tmplibyan/$s/$x | tr "	" " " >> data/devtest/$x
  done
done

# get list of  wav anwar's answers files
for s in devtest/anwar_libyan_msa/Answers_Arabic/1; do
  echo "$0: looking for wav files for $s Answers."
  mkdir -p $tmplibyan/$s
  find $datadir/speech/$s -type f \
  -name "*.wav" | grep Answers_Arabic > $tmplibyan/$s/wav.txt

  local/devtest_anwar_answers_make_lists.pl \
  $datadir/transcripts/devtest/anwar_answers.tsv $s libyan

  for x in wav.scp utt2spk text; do
    cat     $tmplibyan/$s/$x | tr "	" " " >> data/devtest/$x
  done
done

utils/utt2spk_to_spk2utt.pl data/devtest/utt2spk | sort > data/devtest/spk2utt
utils/fix_data_dir.sh data/devtest

# training data consists of several parts: answers, recordings (recited) and Anwar's recordings
answers_transcripts=$datadir/transcripts/train/answers.tsv
recordings_transcripts=$datadir/transcripts/train/recordings.tsv
recordings_anwar_transcripts=$datadir/transcripts/train/recordings_anwar.tsv
answers_anwar_transcripts=$datadir/transcripts/devtest/anwar_answers.tsv
# location of test data
cls_rec_tr=$libyansrc/cls/data/transcripts/recordings/cls_recordings.tsv
lfi_rec_tr=$libyansrc/lfi/data/transcripts/recordings/lfi_recordings.tsv
srj_rec_tr=$libyansrc/srj/data/transcripts/recordings/srj_recordings.tsv
mbt_rec_tr=$datadir/transcripts/test/mbt/recordings/mbt_recordings.tsv

# make acoustic model training  lists
mkdir -p $tmptunis

# get  wav file names
# for recited speech
# the data collection laptops had names like CTELLONE CTELLTWO ...
for machine in CTELLONE CTELLTWO CTELLTHREE CTELLFOUR CTELLFIVE; do
  echo "$0: Looking for audio files for $machine."
  find $datadir/speech/train/$machine -type f -name "*.wav" | grep Recordings \
  >> $tmptunis/recordings_wav.txt
done

# get  wav file names
# for Anwar's recited speech
for m in anwar_libyan_msa; do
  echo "$0: Looking for $m audio files."
  find $datadir/speech/train/$m -type f -name "*.wav" | grep Recordings \
  >> $tmplibyan/recordings_wav.txt
done

# get file names for Answers 
for machine in CTELLONE CTELLTWO CTELLTHREE CTELLFOUR CTELLFIVE; do
  echo "$0: Looking for answers audio files for $machine."
  find $datadir/speech/train/$machine -type f \
    -name "*.wav" \
    | grep Answers >> $tmptunis/answers_wav.txt
done

# make separate transcription lists for answers and recordings
export LC_ALL=en_US.UTF-8
local/answers_make_lists.pl $answers_transcripts

utils/fix_data_dir.sh $tmptunis/answers

local/recordings_make_lists.pl $recordings_transcripts

local/recordings_anwar_make_lists.pl $recordings_anwar_transcripts

utils/fix_data_dir.sh $tmplibyan/recordings

# consolidate Tunisian Recordigns and Answers lists
mkdir -p $tmptunis/lists
for x in wav.scp utt2spk text; do
  cat $tmptunis/answers/$x $tmptunis/recordings/$x > $tmptunis/lists/$x
done
utils/fix_data_dir.sh $tmptunis/lists

# consolidate Tunisian Recordings, Answers and Libyan lists
mkdir -p $tmpdir/lists
for x in wav.scp utt2spk text; do
  cat $tmptunis/lists/$x $tmplibyan/recordings/$x > $tmpdir/lists/$x
done
utils/fix_data_dir.sh $tmpdir/lists

# get training lists
mkdir -p data/train
for x in wav.scp utt2spk text; do
  sort $tmpdir/lists/$x | tr "	" " " > data/train/$x
done

utils/utt2spk_to_spk2utt.pl data/train/utt2spk | sort > data/train/spk2utt
utils/fix_data_dir.sh data/train

# process the Libyan MSA test data
mkdir -p $tmplibyan

for s in cls lfi srj; do
  mkdir -p $tmplibyan/$s

  # get list of  wav files
  find $libyansrc/$s -type f \
    -name "*.wav" \
    | grep recordings > $tmplibyan/$s/recordings_wav.txt

  echo "$0: making recordings list for $s"
  local/test_recordings_make_lists.pl \
    $libyansrc/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan
done

# process the Tunisian MSA test data

mkdir -p $tmptunis/mbt

# get list of  wav files
find $datadir/speech/test/mbt -type f \
  -name "*.wav" \
  | grep recordings > $tmptunis/mbt/recordings_wav.txt

echo "$0: making recordings list for mbt"
local/test_recordings_make_lists.pl \
  $datadir/transcripts/test/mbt/recordings/mbt_recordings.tsv mbt tunis

mkdir -p data/test
# get the Libyan files
for s in cls lfi srj; do
  for x in wav.scp utt2spk text; do
    cat     $tmplibyan/$s/recordings/$x | tr "	" " " >> data/test/$x
  done
done

for x in wav.scp utt2spk text; do
  cat     $tmptunis/mbt/recordings/$x | tr "	" " " >> data/test/$x
done

utils/utt2spk_to_spk2utt.pl data/test/utt2spk | sort > data/test/spk2utt

utils/fix_data_dir.sh data/test

#!/bin/bash  

# Copyright 2019 John Morgan
# Apache 2.0.

# configuration variables
tmpdir=data/local/tmp
tmp_libyan=$tmpdir/libyan
tmp_libyan_test_dir=$tmp_libyan/test
tmp_libyan_dev_dir=$tmp_libyan/dev
tmp_tunis=$tmpdir/tunis
dev_data_dir=/mnt/corpora/Libyan_MSA
test_data_dir=/mnt/corpora/Libyan_msa_arl
# end of configuration variable settings

# process the Libyan MSA test answers data
# get list of  answers wav files
for s in adel anwar bubaker hisham mukhtar redha yousef; do
  #echo "$0: looking for wav files for $s answers."
  mkdir -p $tmp_libyan_test_dir/answers/$s
  find \
    $test_data_dir/$s/data/speech -type f \
    -name "*.wav" \
    | grep answers > $tmp_libyan_test_dir/answers/$s/wav.txt

    local/libyan/make_lists_answers.pl \
	$test_data_dir/$s/data/transcripts/answers/${s}_answers.tsv $s libyan
done

# process the Libyan MSA test recited data

# get list of  wav files
for s in adel anwar bubaker hisham mukhtar redha yousef; do
  #echo "$0: looking for recited wav files for $s."
  mkdir -p $tmp_libyan_test_dir/recordings/$s
  find \
    $test_data_dir/$s/data/speech -type f \
    -name "*.wav" | grep recordings > $tmp_libyan_test_dir/recordings/$s/wav.txt

  local/libyan/make_lists_recordings.pl \
    $test_data_dir/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan
done

# consolidate both recited and answers as dev data 
mkdir -p data/test

for m in answers recordings; do
    for s in adel anwar bubaker hisham mukhtar redha yousef; do
	for x in wav.scp utt2spk text; do
	    cat     $tmp_libyan_test_dir/$m/$s/$x | tr "	" " " >> data/test/$x
	done
    done
done

utils/utt2spk_to_spk2utt.pl data/test/utt2spk | sort > data/test/spk2utt

utils/fix_data_dir.sh data/test

# location of dev data
cls_rec_tr=$dev_data_dir/cls/data/transcripts/recordings/cls_recordings.tsv
lfi_rec_tr=$dev_data_dir/lfi/data/transcripts/recordings/lfi_recordings.tsv
srj_rec_tr=$dev_data_dir/srj/data/transcripts/recordings/srj_recordings.tsv
mbt_rec_tr=/mnt/corpora/Tunisian_MSA/mbt/data/recordings/transcripts/recordings/mbt_recordings.tsv

# process the Libyan MSA data
mkdir -p $tmp_libyan_dev_dir

for s in cls lfi srj; do
  mkdir -vp $tmp_libyan_dev_dir/$s

  #echo "$0: Getting list of  wav files from $s"
  find $dev_data_dir/$s -type f \
    -name "*.wav" \
    | grep recordings > $tmp_libyan_dev_dir/$s/recordings_wav.txt

  #echo "$0: making recordings list for $s"
  local/tunisian/make_lists_dev_recordings.pl \
    $dev_data_dir/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan
done

# process the Tunisian MSA dev data

mkdir -p $tmp_tunis/dev/mbt

#echo "Getting list of  wav files from mbt."
find /mnt/corpora/Tunisian_MSA/mbt -type f \
  -name "*.wav" \
  | grep recordings > $tmp_tunis/dev/mbt/recordings_wav.txt

#echo "$0: making recordings list for mbt"
local/tunisian/make_lists_dev_recordings.pl \
  /mnt/corpora/Tunisian_MSA/mbt/data/transcripts/recordings/mbt_recordings.tsv mbt tunis

mkdir -p data/dev
#echo "$0: Consolidating the Libyan dev files"
for s in cls lfi srj; do
  #echo "$s"
  for x in wav.scp utt2spk text; do
    #echo "$x"
    cat     $tmp_libyan_dev_dir/$s/recordings/$x | tr "	" " " >> data/dev/$x
  done
done

for x in wav.scp utt2spk text; do
  #echo "Consolidating $x from mbt";
  cat     $tmp_tunis/dev/mbt/recordings/$x | tr "	" " " >> data/dev/$x
done

utils/utt2spk_to_spk2utt.pl data/dev/utt2spk | sort > data/dev/spk2utt

utils/fix_data_dir.sh data/dev

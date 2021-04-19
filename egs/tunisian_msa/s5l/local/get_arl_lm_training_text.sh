#!/usr/bin/env bash

arl_lm_data_path=/mnt/corpora/ultra/arabic_lm_text/ar

[ -d data/local/lm ] || mkdir -p data/local/lm;

for f in fm5.0_cleaned_ZA_ar fm6.0_cleaned_ZA_ar fm6.22_cleaned_ZA_ar FM7-8_cleaned_ZA_ar mflts_msa_ar MNSTC-I_cleaned_ZA_ar; do
  cat $arl_lm_data_path/$f.txt >> data/local/lm/training_text.txt
done

#!/usr/bin/env bash

twoway_appen_2006_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/APPEN_2WAY_SEPT2006
twoway_appen_2007_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/APPEN_ADDITIONAL_2WAY_2007/Appen_additional_2-way_IA_Transcription_Training_20070530
detroit_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/DETROIT_2WAY_2006/Detroit_2-way_IA_Transcription_Training_20070302
dli_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/DLI_SEPT2006/Transcription
nist_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ III/Iraqi\ Arabic\ -\ TX-TL/NISTSD_2WAY_BILINGUAL_2007-8
pendleton_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ I/Iraqi\ Arabic-TX-TL/PENDLETON_2005
san_diego_train_txt_dir=/mnt/corpora/TRANSTAC/TRANSTAC\ Database\ P1-P4/Phase\ II/Iraqi\ Arabic-TX-TL/SAN_DIEGO_2WAY_2006/SanDiego_2-way_IA_Transcription_TrainingSet_20070430

tmpdir=data/local/tmp
transtac_tmpdir=$tmpdir/transtac
tmp_twoway_appen_train_2006_dir=$transtac_tmpdir/train/twoway/appen/2006
tmp_twoway_appen_train_2007_dir=$transtac_tmpdir/train/twoway/appen/2007
tmp_twoway_detroit_train_2006_dir=$transtac_tmpdir/train/twoway/detroit/2006
tmp_twoway_dli_train_2006_dir=$transtac_tmpdir/train/twoway/dli/2006
tmp_twoway_nist_train_2007_dir=$transtac_tmpdir/train/twoway/nist/2007
tmp_twoway_pendleton_train_2005_dir=$transtac_tmpdir/train/twoway/pendleton/2005
tmp_twoway_san_diego_train_2006_dir=$transtac_tmpdir/train/twoway/san_diego/2006

echo "$0: Getting a list of the TRANSTAC 2way 2006 training transcript files."
mkdir -p $tmp_twoway_appen_train_2006_dir
find "$twoway_appen_2006_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_appen_train_2006_dir/tdf_files.txt
echo "$0: Getting a list of the TRANSTAC 2way 2007 training transcript files."
mkdir -p $tmp_twoway_appen_train_2007_dir
find "$twoway_appen_2007_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_appen_train_2007_dir/tdf_files.txt
echo "$0: Getting a llist of the TRANSTAC DETROIT 2006 2way training transcript files."
mkdir -p $tmp_twoway_detroit_train_2006_dir
find "$detroit_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_detroit_train_2006_dir/tdf_files.txt
echo "$0: Getting a list of the TRANSTAC Iraqi Arabic DLI 2006 training transcript files."
mkdir -p $tmp_twoway_dli_train_2006_dir
find "$dli_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_dli_train_2006_dir/tdf_files.txt
echo "$0: Getting a list of the TRANSTAC Iraqi Arabic NIST 2007 training transcript files."
mkdir -p $tmp_twoway_nist_train_2007_dir
find "$nist_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_nist_train_2007_dir/tdf_files.txt
echo "$0: Getting a list of the  TRANSTAC Iraqi Arabic Camp Pendleton transcript .txt files."
mkdir -p $tmp_twoway_pendleton_train_2005_dir
find "$pendleton_train_txt_dir" -type f -name "*.txt" > \
    $tmp_twoway_pendleton_train_2005_dir/tdf_files.txt
echo "$0: Getting a list of the TRANSTAC Iraqi Arabic San Diego 2006 2way training transcript files."
mkdir -p $tmp_twoway_san_diego_train_2006_dir
find "$san_diego_train_txt_dir" -type f -name "*.tdf" > \
    $tmp_twoway_san_diego_train_2006_dir/tdf_files.txt

find $transtac_tmpdir/train/twoway -type f -name "tdf_files.txt" | xargs cat > data/transtatc_twoway_text.txt 

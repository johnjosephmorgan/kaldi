#! /bin/bash

tmp_dir=data/local/tmp/transtac_iraqi_arabic/eval
mkdir -p $tmp_dir/lists

local/make_lists_eval.pl

utils/fix_data_dir.sh $tmp_dir/lists

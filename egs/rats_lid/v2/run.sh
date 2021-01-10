#!/usr/bin/env bash

#!/usr/bin/env bash

datadir=/mnt/corpora/LDC2015S02/RATS_SAD/data

local/rats_sad_get_filenames.sh $datadir

local/rats_sad_data_prep.pl $f

local/rats_sad_utt2lang_to_wav.scp.sh $datadirr

#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# configuration variables
lex=$@
tmpdir=data/local/tmp
# where to put the downloaded speech corpus
downloaddir=$(pwd)
# Where to put the uncompressed file
datadir=$(pwd)
# end of configuration variable settings

# download the corpus 
if [ ! -f $downloaddir/ru.dict.tar.gz ]; then
  wget -O $downloaddir/ru.dict.tar.gz "$lex"
  (
    cd $downloaddir
    tar -xzf ru.dict.tar.gz
  )
else
  echo "$0: The corpus $lex was already downloaded."
fi


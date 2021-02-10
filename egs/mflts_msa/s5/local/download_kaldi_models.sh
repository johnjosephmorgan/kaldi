#!/usr/bin/env bash

if [ ! -f 0012_sad_v1.tar.gz ]; then
  wget http://kaldi-asr.org/models/12/0012_sad_v1.tar.gz
  tar -zxf 0012_sad_v1.tar.gz
  (
    mkdir -p exp
    cd exp
    if [ ! -d segmentation_1a ]; then
      ln -s ../0012_sad_v1/exp/segmentation_1a ./
    fi
  )
fi

if [ ! -f 0012_diarization_v1.tar.gz ]; then
  wget http://kaldi-asr.org/models/12/0012_diarization_v1.tar.gz
  tar -zxf 0012_diarization_v1.tar.gz
  (
    cd exp
    if [ ! -d xvector_nnet_1a ]; then
      ln -s ../0012_diarization_v1/exp/xvector_nnet_1a ./
    fi
  )
fi

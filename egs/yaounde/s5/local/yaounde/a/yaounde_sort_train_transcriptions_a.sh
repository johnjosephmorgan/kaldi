#!/bin/bash
sort   \
    data/local/tmp/yaounde_utt2text_a_unsorted.txt > \
    data/train_a/text

sort \
    data/local/tmp/yaounde_wav_a_unsorted.scp > \
    data/train_a/wav.scp

sort \
    data/local/tmp/yaounde_spk2utt_a_unsorted.txt > \
    data/train_a/spk2utt

sort \
    data/local/tmp/yaounde_utt2spk_a_unsorted.txt > \
    data/train_a/utt2spk

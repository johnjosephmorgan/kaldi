#!/usr/bin/env bash
utils/format_lm.sh \
  data/lang \
  data/local/lm/$LM \
  data/local/dict/lexicon.txt \
  data/lang_test || exit 1;

/usr/bin/env bash

utils/format_lm.sh \
  data/gale_arabic/lang \
  data/local/lm/gale.o3g.kn_utf8.gz \
  ../s5a/data/local/dict/lexicon.txt \
  data/lang_test

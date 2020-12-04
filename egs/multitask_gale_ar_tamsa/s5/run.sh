#!/usr/bin/env bash
. ./path.sh
. ./cmd.sh
set -e
set -o pipefail

. utils/parse_options.sh
local/chain2/tuning/run_tdnn.sh

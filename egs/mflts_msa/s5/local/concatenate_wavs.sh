#!/usr/bin/env bash

a=$(find out_diarized/overlaps -type f -name "max.wav" | shuf -n 100)
sox ${a[@]} concatenated.wav

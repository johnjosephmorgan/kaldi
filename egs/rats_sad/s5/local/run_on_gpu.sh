#!/usr/bin/env bash
#$ -N rats_sad
#$ -j y -o $JOB_NAME-$JOB_ID.out 
#$ -M johnjosephmorgan@gmail.com
#$ -m e
#$ -l mem_free=15G,ram_free=15G,gpu=2,hostname=b1[123456789|c0*|c1[123456789]
#$ -q g.pl

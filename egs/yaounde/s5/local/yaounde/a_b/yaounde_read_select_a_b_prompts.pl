#!/usr/bin/perl -w
# yaounde_read_select_prompts.pl - separate a and b prompts by speakers
use strict;
use warnings;
use Carp;

my $a_speakers = "local/src/yaounde_read_speakers_a.txt";
my $b_speakers = "local/src/yaounde_read_speakers_b.txt";
my $prompts = "local/src/yaounde_read_prompts.txt"
    

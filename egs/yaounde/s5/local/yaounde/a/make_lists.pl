#!/usr/bin/env perl

# Copyright 2018 John Morgan
# Apache 2.0.

# make_lists.pl - write lists for acoustic model training
# writes files under data/local/tmp/yaounde/a/lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;

my $tmpdir = "data/local/tmp/yaounde/a";

my $prompts = "local/yaounde/read_prompts.tsv";

system "mkdir -p $tmpdir/lists";

# input wav file list
my $wav_list = "$tmpdir/wav_filenames.txt";

# output temporary wav.scp files
my $out_wav = "$tmpdir/lists/wav.scp";

# output temporary utt2spk files
my $utt = "$tmpdir/lists/utt2spk";

# output temporary text files
my $out_text= "$tmpdir/lists/text";

# initialize hash for prompts
my %prompt = ();

open my $PROMPTS, '<', $prompts or croak "problem with $prompts $!";

# store prompts in hash
LINEA: while ( my $line = <$PROMPTS> ) {
    chomp $line;
    my ($j,$sent) = split /\t/, $line, 2;
    $prompt{$j} = $sent;
}
close $PROMPTS;

open my $WAVLIST, '<', $wav_list or croak "problem with $wav_list $!";
open my $OUTWAVSCP, '+>', $out_wav or croak "problem with $out_wav $!";
open my $UTTTOSPK, '+>', $utt or croak "problem with $utt $!";
open my $TEXT, '+>', $out_text or croak "problem with $out_text $!";

 LINE: while ( my $line = <$WAVLIST> ) {
     chomp $line;
     my ($volume,$directories,$file) = File::Spec->splitpath( $line );
     my @dirs = split /\//, $directories;
     my $mode = $dirs[4];
     my $r = basename $line, ".wav";
     my ($x,$s,$i) = split /\-/, $r, 3;
     my $speaker = $dirs[-1];
     my $sd = 'yaounde-' . $s;
     my $bn = $sd . '-' . $mode . '-' . $i;
     my $fn = $bn . ".wav";

     print $TEXT "$bn\t$prompt{$i}\n";
     print $OUTWAVSCP "$bn\tsox $line -t .wav - |\n";
     print $UTTTOSPK "$bn\t$sd\n";
}
close $TEXT;
close $OUTWAVSCP;
close $UTTTOSPK;
close $WAVLIST;

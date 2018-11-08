#!/usr/bin/env perl

# Copyright 2018 John Morgan
# Apache 2.0.

# make_lists_train.pl - write lists for acoustic model training
# writes files under data/local/tmp/ru/train/lists

use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 1 or croak "USAGE: $0 <DATA_SRC_DIR>
Example:
$0 russian/train";
}

use File::Spec;
use File::Copy;
use File::Basename;

my ($d) = @ARGV;

# Initialize variables
my $tmpdir = "data/local/tmp/ru/train";
my $transcripts_file = "$d/transcription/fn2text.txt";
# input wav file list
my $w = "$tmpdir/wav_list.txt";
# output temporary wav.scp file
my $wav_scp = "$tmpdir/lists/wav.scp";
# output temporary utt2spk file
my $utt_to_spk = "$tmpdir/lists/utt2spk";
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
# initialize hash for transcripts
my %transcript = ();
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.

system "mkdir -p $tmpdir/lists";
open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
# store transcripts in hash
LINEA: while ( my $line = <$TR> ) {
  chomp $line;
  my ($utt_path,$sent) = split /\s/, $line, 2;
  my ($volume,$directories,$file) = File::Spec->splitpath( $utt_path );
  my ($spk,$utt,$mode) = split /\-/, $file, 3;
  $transcript{$file} = $sent;
}
close $TR;

open my $W, '<', $w or croak "problem with $w $!";
open my $WAVSCP, '+>', $wav_scp or croak "problem with $wav_scp $!";
open my $UTTSPK, '+>', $utt_to_spk or croak "problem with $utt_to_spk $!";
open my $TXT, '+>', $txt_out or croak "problem with $txt_out $!";

LINE: while ( my $line = <$W> ) {
    chomp $line;
  my ($volume,$directories,$file) = File::Spec->splitpath( $line );
  my @dirs = split /\//, $directories;
  my $base = basename $file, ".wav";
  my ($spk,$utt,$mode) = split /\_/, $base, 3;
  if ( defined $transcript{$base} ) {
    print $TXT "$base $transcript{$base}\n";
    print $WAVSCP "$base sox $line -t .wav - |\n";
    print $UTTSPK "$base $spk\n";
  } else {
      croak "Problem with $base and $line";
  }
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $W;

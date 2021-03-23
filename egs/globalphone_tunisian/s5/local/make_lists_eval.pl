#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_eval.pl - write  Kaldi IO lists
# writes files under data/local/tmp/transtac_iraqi_arabic/eval/lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;
use Encode;
use utf8;

binmode STDOUT, 'utf8';

# Initialize variables
my $tmpdir = "data/local/tmp/transtac_iraqi_arabic/eval";
my $transcripts_file = "$tmpdir/txt_files.txt";
# input wav file list
my $w = "$tmpdir/wav_files.txt";
# output temporary wav.scp file
my $wav_scp = "$tmpdir/lists/wav.scp";
# output temporary utt2spk file
my $utt_to_spk = "$tmpdir/lists/utt2spk";
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
# initialize utterance hash
my %utterance = ();
my %speaker_dir = ();
my $sample_rate = 16000;
my $data_word_size = 4;
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.

system "mkdir -p $tmpdir/lists";
open my $W, '<', $w or croak "problem with $w $!";
LINE: while ( my $line = <$W> ) {
  chomp $line;
  my ($volume,$directories,$file) = File::Spec->splitpath( $line );
  my @dirs = split /\//, $directories;
  my $base = basename $file, ".wav";
  $speaker_dir{$line} = $dirs[-2];
}
close $W;

open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
# store transcripts in hash
LINE: while ( my $line = <$TR> ) {
  chomp $line;
  open my $TDF, '<', $line or croak "Problems with $line $!";
  undef $/;
  my $transcript = <$TDF> ;
  chomp $transcript;
  $/ = "\n";
  close $TDF;
  $transcript = decode_utf8 $transcript;
  # transcript is on 1 line
  $transcript =~ s/\n+//g;
  # no punctuation
  $transcript =~ s/؟//g;
  $transcript =~ s/\.//g;
  # no english
  next LINE if ( $transcript =~ /[a-zA-Z]/g );
  # skip utterances with parens?
  next LINE if ( $transcript =~ /\(/g );
  $transcript =~ s/-//g;
  $transcript =~ s/\%//g;
  $transcript =~ s/\+//g;
  $transcript =~ s/\///g;
  $transcript =~ s/<//g;
  $transcript =~ s/\^//g;
  $transcript =~ s/\_/ /g;
  $transcript =~ s/\s+/ /g;
  # Store in hash if some character is Arabic
  next LINE if ( $transcript !~ /\p{Arabic}/ );
  my $utt_id = basename $line, ".txt";
  $utterance{$utt_id} = $transcript;
}
close $TR;

open my $WAVSCP, '+>', $wav_scp or croak "problem with $wav_scp $!";
open my $UTTSPK, '+>', $utt_to_spk or croak "problem with $utt_to_spk $!";
open my $TXT, '+>:utf8', $txt_out or croak "problem with $txt_out $!";

LINE: foreach my $line (sort  keys %speaker_dir ) {
    my $b = basename $line, ".wav";
  my $utt_id = $speaker_dir{$line} . '-' . $b;
  my $spk = $speaker_dir{$line};
  my $rec_id = $utt_id;
  if ( defined $utterance{$b} ) {
    print $TXT "$utt_id $utterance{$b}\n";
    print $WAVSCP "$rec_id sox -r 16000 -b 16 -e signed \"$line\" -r 16000 -b 16 -e signed -t .wav - remix 1 |\n";
    print $UTTSPK "$utt_id $spk\n";
  }
}
close $TXT;
close $WAVSCP;
close $UTTSPK;

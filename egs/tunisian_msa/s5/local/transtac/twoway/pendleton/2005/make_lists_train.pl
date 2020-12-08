#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - write  Kaldi IO lists
# writes files under data/local/tmp/transtac/train/twoway/pendleton/2005/lists

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
my $tmpdir = "data/local/tmp/transtac/train/twoway/pendleton/2005";
my $transcripts_file = "$tmpdir/tdf_files.txt";
# input wav file list
my $w = "$tmpdir/wav_files.txt";
# output temporary wav.scp file
my $wav_scp = "$tmpdir/lists/wav.scp";
# output temporary utt2spk file
my $utt_to_spk = "$tmpdir/lists/utt2spk";
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
# temporary segments file
my $segs = "$tmpdir/lists/segments";
my $sample_rate = 16000;
my $data_word_size = 4;
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.

system "mkdir -p $tmpdir/lists";
my %wav_file = ();
open my $W, '<', $w or croak "problem with $w $!";
# Store wav file names in hash
LINE: while ( my $line = <$W> ) {
  chomp $line;
  my ($volume,$directories,$file) = File::Spec->splitpath( $line );
  my $base = basename $file, ".wav";
  $wav_file{$base} = $line;
}
close $W;

open my $WAVSCP, '+>', $wav_scp or croak "problem with $wav_scp $!";
open my $UTTSPK, '+>', $utt_to_spk or croak "problem with $utt_to_spk $!";
open my $TXT, '+>:utf8', $txt_out or croak "problem with $txt_out $!";
open my $SEG, '+>', $segs or croak "problem with $segs $!";
open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";

while ( my $line = <$TR> ) {
  chomp $line;
  my $file = basename $line, ".txt";
  my ($speakerType,$speaker,$suType,$a4) = split /\_/, $file, 4;
  open my $TDF, '<', $line or croak "Problems with $line $!";
  RECORD:  while ( my $rec_info = <$TDF> ) {
    chomp $rec_info;
    my @rec_info = split /\s/, $rec_info;
    my ($rec_num,$rec_data) = split /\-/, $rec_info[1], 2;
    my @transcript = @rec_info[2 .. $#rec_info];
    my $transcript = join ' ', @transcript;
    $transcript = decode_utf8 $transcript;
    # skipp unless some character is Arabic
    next RECORD if ( $transcript !~ /\p{Arabic}/ );
    my ($speakerRole,$interval) = split /\(/, $rec_data, 2;
    my $start = "";
    my $end = "";
    if ( defined $interval ) {
      ($start,$end) = split /\-/, $interval, 2;
    } else {
      next RECORD;
    }
    $end =~ s/\)//;
    $end =~ s/\://;
    # remove non arabic punctuation
    $transcript =~ s/\.|\?/ /g;
    # remove arabic punctuation
    $transcript =~ s/؟/ /g;
    # percent sign?
    $transcript =~ s/%//g;
    # not distinguishable 
    $transcript =~ s/\(\(\)\)/<UNK>/g;
    # single parens?
    $transcript =~ s/\(|\)//g;
    # carat?
    $transcript =~ s/\^//g;
    # Interval?
    $transcript =~ s/\[.+?\]/<UNK>/g;
    # plus  sign
    $transcript =~ s/\+/ /g;
    # at sign
    $transcript =~ s/\@/ /g;
    # backslash
    $transcript =~ s/\\/ /g;
        # dashes?
    $transcript =~ s/\-/ /g;
    # underscores
    $transcript =~ s/\_/ /g; 
    # squeeze
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;
    my $utt_id = $speaker . '-' . $suType . '-' . $speakerType . '-' . $file . '-' . $start . '-' . $end;
    next RECORD if ( $start eq "" );
    next RECORD if ( $end <= $start );
    my $rec_id = "";
    $rec_id = $file;
    my $spk_id = $speaker;
    my $base = $file;
    if ( defined $wav_file{$base} ) {
      print $WAVSCP "$rec_id sox -r 22050 -b 16 -e signed \"$wav_file{$base}\" -r 16000 -b 16 -e signed -t .wav - remix 2 |\n";
    } else {
      next RECORD;
    }
    print $TXT "$utt_id $transcript\n";
    print $UTTSPK "$utt_id $spk_id\n";
    print $SEG "$utt_id $rec_id $start $end\n";
  }
  close $TDF;
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $W;
close $SEG;

close $TR;

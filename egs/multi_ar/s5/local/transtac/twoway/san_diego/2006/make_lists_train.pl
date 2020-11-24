#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train_twoway_san_diego.pl - write  Kaldi IO lists
# writes files under data/local/tmp/transtac/train/twoway/san_diego/2006/lists

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
my $tmpdir = "data/local/tmp/transtac/train/twoway/san_diego/2006";
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
my %wav_file = ();
my $sample_rate = 16000;
my $data_word_size = 4;
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.
# Speakers are only identified by role. 

system "mkdir -p $tmpdir/lists";
# store .wav files in hash
open my $W, '<', $w or croak "problem with $w $!";
LINE: while ( my $line = <$W> ) {
  chomp $line;
  my ($volume,$directories,$file) = File::Spec->splitpath( $line );
  my $base_with_suffix = basename $file, ".wav";
  my $base = "";
  # There are 2 wav files for each basename
  # One has _a suffix and theother has _b suffix.
  # we are arbitrarily choosing to go with suffix _a
  if ( $base_with_suffix =~ /(.+)_a$/ ) {
    $base = $1;
  } elsif ( $base_with_suffix =~ /(.+)_b$/ ) {
      next LINE;
  } else {
    croak "$line has Neither _a nor _b suffixes. $!";
  }
  $wav_file{$base} = $line;
}
close $W;

open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
open my $WAVSCP, '+>', $wav_scp or croak "problem with $wav_scp $!";
open my $UTTSPK, '+>', $utt_to_spk or croak "problem with $utt_to_spk $!";
open my $TXT, '+>:utf8', $txt_out or croak "problem with $txt_out $!";
open my $SEG, '+>', $segs or croak "problem with $segs $!";

while ( my $line = <$TR> ) {
  chomp $line;
  open my $TDF, '<', $line or croak "Problems with $line $!";
  RECORD:  while ( my $rec_info = <$TDF> ) {
    chomp $rec_info;

    # skip header that starts with the word file 
    next RECORD if ( $rec_info =~ /^file/ );
    my ($file,$channel,$start,$end,$speaker,$speakerType,$speakerDialect,$transcript,$section,$turn,$segment,$sectionType,$suType,$speakerRole) = split /\t/, $rec_info, 14;
    $transcript = decode_utf8 $transcript;
    # skip unless some character is Arabic
    next RECORD if ( $transcript !~ /\p{Arabic}/ );
    # map white space to dummy
    $transcript =~ s/\s+/اااا/g;
    # map everything that is not Arabic to <UNK>
    $transcript =~ s/\P{ARABIC}/<UNK>/g;
    # map the dummy back to space
    $transcript =~ s/اااا/ /g;
    # put space around <UNK>
        $transcript =~ s/<UNK>/ <UNK> /g;
    # remove arabic punctuation
    $transcript =~ s/؟/ /g;
    # squeeze
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;
    $transcript =~ s/(<UNK)+/$1/g;
    # the file names in the tdf files do not have the _a and _b suffixes
    my $base = basename $file, ".wav";
    my $utt_id = $speakerRole . '-' . $base . $start . '-' . $end;
  next LINE if ( $end <= $start );
  next LINE unless ( defined $file );
  my $base_without_suffix = basename $file, ".wav";
  next RECORD unless defined $wav_file{$base_without_suffix};
  my $rec_id = $base_without_suffix;
  my $spk = $speakerRole;
  print $TXT "$utt_id $transcript\n";
  print $WAVSCP "$rec_id sox -r 22050 -b 16 -e signed \"$wav_file{$base_without_suffix}\" -r 16000 -b 16 -e signed -t .wav - remix 2 |\n";
  print $UTTSPK "$utt_id $spk\n";
  print $SEG "$utt_id $rec_id $start $end\n";
  }
  close $TDF;
}
close $TR;
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $SEG;

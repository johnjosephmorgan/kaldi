#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - write lists for acoustic model training
# writes files under data/local/tmp/transtac/train/twoway/nist/2007/lists

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
my $tmpdir = "data/local/tmp/transtac/train/twoway/nist/2007";
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
my $question_marks = 0;
my $subs = 0;
my $ws = 0;
my $puncs = 0;
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.

system "mkdir -p $tmpdir/lists";
open my $W, '<', $w or croak "problem with $w $!";
my %wav_file = ();
warn "$0: Storing file names in hash.";
LINE: while ( my $line = <$W> ) {
    chomp $line;
  my ($volume,$directories,$file) = File::Spec->splitpath( $line );
    my $base = basename $file, ".wav";
  $wav_file{$base} = $line;
}
close $W;

open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
open my $WAVSCP, '+>', $wav_scp or croak "problem with $wav_scp $!";
open my $UTTSPK, '+>', $utt_to_spk or croak "problem with $utt_to_spk $!";
open my $TXT, '+>:utf8:', $txt_out or croak "problem with $txt_out $!";
open my $SEG, '+>', $segs or croak "problem with $segs $!";
warn "$0: Processing each .wav and .tdf file pair.";
LINE: while ( my $line = <$TR> ) {
  chomp $line;
  open my $TDF, '<', $line or croak "Problems with $line $!";
  RECORD:  while ( my $rec_info = <$TDF> ) {
    chomp $rec_info;
    # skip header that starts with the word file 
    next RECORD if ( $rec_info =~ /^file/ );
    my ($file,$channel,$start,$end,$speaker,$speakerType,$speakerDialect,$transcript,$section,$turn,$segment,$sectionType,$suType,$speakerRole) = split /\t/, $rec_info, 14;
    $transcript = decode_utf8 $transcript;
    # skip unless   some character is Arabic
    next RECORD if ( $transcript !~ /\p{Arabic}/ );
    $ws += $transcript =~ s/\s+/ااا/g;
    $subs += $transcript =~ s/\P{ARABIC}/<UNK>/g;
    $transcript =~ s/ااا/ /g;
    $transcript =~ s/<UNK>/ <UNK> /g;
    # remove arabic punctuation
    $question_marks += $transcript =~ s/؟/ /g;
    # squeeze
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;
    # squeeze <UNK>s
    $transcript =~ s/(<UNK>)+/$1/g;
    my $base = basename $file, ".wav";
    my $utt_id = $speaker . '-' . $base . '-' . $start . '-' . $end;
  my $rec_id = $base;
    if ( defined $wav_file{$base} ) {
      print $WAVSCP "$rec_id sox -r 44000 -b 16 -e signed \"$wav_file{$base}\" -r 16000 -b 16 -e signed -t .wav - remix 2 |\n";
    } else {
      next RECORD;
    }
    print $TXT "$utt_id $transcript\n";
    print $UTTSPK "$utt_id $speaker\n";
    print $SEG "$utt_id $rec_id $start $end\n";
  }
  close $TDF;
}
warn "Substitutions\t$subs\nWhite Space\t$ws";
close $TR;
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $SEG;


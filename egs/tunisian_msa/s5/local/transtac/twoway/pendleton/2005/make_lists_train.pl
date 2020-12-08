#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - Get text for LM training.
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
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
my $sample_rate = 16000;
my $data_word_size = 4;
# done setting variables

system "mkdir -p $tmpdir/lists";
open my $TXT, '+>:utf8', $txt_out or croak "problem with $txt_out $!";
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
    print $TXT "$transcript\n";
  }
  close $TDF;
}
close $TXT;
close $TR;

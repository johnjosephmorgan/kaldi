#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - Get text for LM training.
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
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
my $sample_rate = 16000;
my $data_word_size = 4;
my $question_marks = 0;
my $subs = 0;
my $ws = 0;
my $puncs = 0;
# done setting variables

system "mkdir -p $tmpdir/lists";
open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
open my $TXT, '+>:utf8:', $txt_out or croak "problem with $txt_out $!";
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
    print $TXT "$transcript\n";
  }
  close $TDF;
}
warn "Substitutions\t$subs\nWhite Space\t$ws";
close $TR;
close $TXT;

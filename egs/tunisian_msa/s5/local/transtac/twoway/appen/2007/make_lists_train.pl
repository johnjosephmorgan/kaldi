#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - Get text for LM training.
# writes files under data/local/tmp/transtac/train/twoway/appen/2007/lists

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
my $tmpdir = "data/local/tmp/transtac/train/twoway/appen/2007";
my $transcripts_file = "$tmpdir/tdf_files.txt";
# input wav file list
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
# initialize utterance hash
my %utterance = ();
my $sample_rate = 16000;
my $data_word_size = 4;
my $percents = 0;
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.

system "mkdir -p $tmpdir/lists";
open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
# store transcripts in hash
while ( my $line = <$TR> ) {
  chomp $line;
  open my $TDF, '<', $line or croak "Problems with $line $!";
  RECORD:  while ( my $rec_info = <$TDF> ) {
    chomp $rec_info;
    my %rec = ();
    # skip header that starts with the word file 
    next RECORD if ( $rec_info =~ /^file/ );
    my ($file,$channel,$start,$end,$speaker,$speakerType,$speakerDialect,$transcript,$section,$turn,$segment,$sectionType,$suType,$speakerRole) = split /\t/, $rec_info, 14;
    $transcript = decode_utf8 $transcript;
    # Store in hash if some character is Arabic
    next RECORD if ( $transcript !~ /\p{Arabic}/ );
    # remove non arabic characters from transcript
    $transcript =~ s/\.|\?|\-\-|\(|\)|<|>|\_|%|[a-zA-Z]/ /g;
    $transcript =~ s/\-/ /g;
    # remove arabic punctuation
    $transcript =~ s/؟/ /g;
    $transcript =~ s/؛/ /g;
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;
    # percent sign?
    $percents += $transcript =~ s/%//g;
    # not distinguishable 
    $transcript =~ s/\(\(\)\)/<UNK>/g;
    # transcribe [int] (intermittent noise) as <UNK>
    $transcript =~ s/\[int\]/<UNK>/g;
    # transcribe [spk] (speaker noise) as <UNK>
    $transcript =~ s/\[spk\]/<UNK>/g;
    # transcribe [sta] stationary noise as <UNK>
    $transcript =~ s/\[sta\]/<UNK>/g;
    # fragments
    #$transcript =~ s/\s\-|\-\s/ /g;
    # dashes?
    $transcript =~ s/\-/ /g;
    # cut off 
    $transcript =~ s/^~|~$/ /g;
    # mispronunciations
    $transcript =~ s/\+/ /g;
    $transcript =~ s/\s+/ /g;
    # Unintelligible?
    $transcript =~ s/\(\(\)\)/<UNK>/g;
    $transcript =~ s/\(\(|\)\)/ /g;
    $transcript =~ s/\s+/ /g;
    # (%...) indicates an interjection or filler
    $transcript =~ s/\(%(.+?)\)/$1/g;
    # single parens?
    $transcript =~ s/\(|\)//g;
    # carat?
    $transcript =~ s/\^//g;
    $transcript =~ s/\/نهاية\sتداخل/<UNK>/g;
    $transcript =~ s/\/نهاية ضجيج/<UNK>/g;
    # underscores
    $transcript =~ s/\_/ /g;
    # squeeze
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;
    my $base = basename $file, ".wav";
    my $rec = {
      ranscript => "",
      channel => "",
      start => "",
      end => "",
      speakerrole => "",
      speakertype => "",
      sutype => "",
      speaker => ""
    };

    $rec{'transcript'} = $transcript;
    $rec{'channel'} = $channel;
    $rec{'start'} = $start;
    $rec{'end'} = $end;
    $rec{'speakerrole'} = $speakerRole;
    $rec{'speakertype'} = $speakerType;
    $rec{'sutype'} = $suType;
    $rec{'speaker'} = $speaker;
    $rec{'filename'} = $file;
    my $utt_id = '2007' . '-' . $speaker . '-' . $suType . '-' . $speakerType . '-' . $base . '-' . $channel . '-' . $start . '-' . $end;
    $utterance{$utt_id} = \%rec;
  }
  close $TDF;
}
close $TR;
warn "percent signs\t$percents";
open my $TXT, '+>:utf8', $txt_out or croak "problem with $txt_out $!";

LINE: foreach my $utt_id (sort  keys %utterance ) {
  next LINE if ( $utterance{$utt_id}->{'end'} <= $utterance{$utt_id}->{'start'} );
  my $base = basename $utterance{$utt_id}->{'filename'}, ".wav";
  my $rec_id = $base;
  my $spk = '2007' . '-' . $utterance{$utt_id}->{'speaker'} . '-' . $utterance{$utt_id}->{'sutype'} . '-' . $utterance{$utt_id}->{'speakertype'} . '-' . $utterance{$utt_id}->{'channel'};
  my $rmx = 1;
  if ( $utterance{$utt_id}->{'channel'} == 0 ) {
    $rmx = 1;
  } elsif ( $utterance{$utt_id}->{'channel'} == 1 ) {
    $rmx = 2;
  } else {
    warn "Channel not set $!";
  }
  print $TXT "$utterance{$utt_id}->{'transcript'}\n";
}
close $TXT;

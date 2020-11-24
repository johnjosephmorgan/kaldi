#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - write  Kaldi IO lists
# writes files under data/local/tmp/transtac/train/twoway/appen/2006/lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;
use Encode;
use utf8;
binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';

# Initialize variables
my $tmpdir = "data/local/tmp/transtac/train/twoway/appen/2006";
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
# initialize utterance hash
my %utterance = ();
my $sample_rate = 16000;
my $data_word_size = 4;
my $qm = 0;
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
    # remove non arabic punctuation
    $transcript =~ s/\.|\?/ /g;
    # I think this means white space?
    $transcript =~ s/<بداية\_ضجيج>/<UNK>/g;
    $transcript =~ s/<\/نهاية\_تداخل>/<UNK>/g;
    $transcript =~ s/<\/نهاية\_ضجيج>/<UNK>/g;
    $transcript =~ s/<بداية_تداخل>/<UNK>/g;
    $transcript =~ s/<بداية_ضجيج>/<UNK>/g;
    $transcript =~ s/ENGLISH\_anyway/<UNK>/g;
    $transcript =~ s/ENGLISH\_cash/<UNK>/g;
    $transcript =~ s/ENGLISH\_company/<UNK>/g;
    $transcript =~ s/ENGLISH\_danger/<UNK>/g;
    $transcript =~ s/ENGLISH\_design/<UNK>/g;
    $transcript =~ s/ENGLISH\_disposable/<UNK>/g;
    $transcript =~ s/ENGLISH\_dose/<UNK>/g;
    $transcript =~ s/ENGLISH\_double/<UNK>/g;
    $transcript =~ s/ENGLISH\_double\_volume/<UNK>/g;
    $transcript =~ s/ENGLISH\_down_load/<UNK>/g;
    $transcript =~ s/\@إكس/<UNK>/g;
    $transcript =~ s/ENGLISH\_expire/<UNK>/g;
    $transcript =~ s/ENGLISH\_first_aid/<UNK>/g;
    $transcript =~ s/ENGLISH\_for_ceiling/<UNK>/g;
    $transcript =~ s/ENGLISH\_form/<UNK>/g;
    $transcript =~ s/ENGLISH\_foundation/<UNK>/g;
    $transcript =~ s/ENGLISH\_free/<UNK>/g;
    $transcript =~ s/ENGLISH\_hardware/<UNK>/g;
    $transcript =~ s/ENGLISH\_headmaster/<UNK>/g;
    $transcript =~ s/ENGLISH\_hose/<UNK>/g;
    $transcript =~ s/ENGLISH\_laptop/<UNK>/g;
    $transcript =~ s/ENGLISH\_like/<UNK>/g;
    $transcript =~ s/ENGLISH\_maximum/<UNK>/g;
    $transcript =~ s/ENGLISH\_nurse/<UNK>/g;
    $transcript =~ s/ENGLISH\_other/<UNK>/g;
    $transcript =~ s/ENGLISH\_out_out/<UNK>/g;
    $transcript =~ s/ENGLISH\_overtime/<UNK>/g;
    $transcript =~ s/ENGLISH\_page/<UNK>/g;
    $transcript =~ s/ENGLISH\_part\_time/<UNK>/g;
    $transcript =~ s/ENGLISH\_please/<UNK>/g;
    $transcript =~ s/ENGLISH\_program/<UNK>/g;
    $transcript =~ s/ENGLISH\_safety/<UNK>/g;
    $transcript =~ s/ENGLISH\_scale/<UNK>/g;
    $transcript =~ s/ENGLISH\_shoes/<UNK>/g;
    $transcript =~ s/ENGLISH\_software/<UNK>/g;
    $transcript =~ s/ENGLISH\_sorry/<UNK>/g;
    $transcript =~ s/ENGLISH\_spare\_parts/<UNK>/g;
    $transcript =~ s/ENGLISH\_stainless\_steel/<UNK>/g;
    $transcript =~ s/ENGLISH\_system/<UNK>/g;
    $transcript =~ s/ENGLISH\_team/<UNK>/g;
    $transcript =~ s/ENGLISH\_torch/<UNK>/g;
    $transcript =~ s/ENGLISH\_volume$/<UNK>/g;
    $transcript =~ s/ENGLISH/<UNK>/g;
    $transcript =~ s/wheel/<UNK>/g;
    $transcript =~ s/yeah/<UNK>/g;
$transcript =~ s/volume/<UNK>/g;
    $transcript =~ s/ENGLISH\_wheel/<UNK>/g;
    $transcript =~ s/ENGLISH\_yeah/<UNK>/g;
    # remove arabic punctuation
    $qm += $transcript =~ s/؟/ /g;
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
    # squeeze
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;
    # underscores
    $transcript =~ s/\_/ /g;
    my $base = basename $file, ".wav";
    my $rec = {
	transcript => "",
	channel => "",
      start => "",
      end => "",
      speakerrole => "",
      speakertype => "",
      sutype => "",
      speaker => ""
    };

    $rec{'transcript'} = $transcript;
    $rec{'start'} = $start;
    $rec{'end'} = $end;
    $rec{'speakerrole'} = $speakerRole;
    $rec{'speakertype'} = $speakerType;
    $rec{'sutype'} = $suType;
    $rec{'speaker'} = $speaker;
    $rec{'channel'} = $channel;
    $rec{'filename'} = $file;
    my $utt_id = '2006' . '-' . $speaker . '-' . $suType . '-' . $speakerType . '-' . $base . '-' . $channel . '-' . '-' . $start . '-' . $end;
      $utterance{$utt_id} = \%rec;
  }
  close $TDF;
}
close $TR;
warn "question markt؟\t$qm\npercent signs\t$percents";
my %wav_file = ();
open my $W, '<', $w or croak "problem with $w $!";
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

LINE: foreach my $utt_id (sort  keys %utterance ) {
  next LINE if ( $utterance{$utt_id}->{'end'} <= $utterance{$utt_id}->{'start'} );
  my $rec_id = "";
  $rec_id = basename $utterance{$utt_id}->{'filename'}, ".wav";
  my $base = basename $rec_id, ".wav";
  my $spk = '2006' . '-' . $utterance{$utt_id}->{'speaker'} . '-' . $utterance{$utt_id}->{'speakertype'} . '-' . $utterance{$utt_id}->{'sutype'} . '-' . $utterance{$utt_id}->{'channel'};
  my $rmx = 1;
  if ( $utterance{$utt_id}->{'channel'} == 0 ) {
      $rmx = 1;
  } elsif ( $utterance{$utt_id}->{'channel'} == 1 ) {
      $rmx = 2;
  } else {
      warn "No channel set $!";
  }
  print $TXT "$utt_id $utterance{$utt_id}->{'transcript'}\n";
  print $WAVSCP "$rec_id sox -r 16000 -b 16 -e signed \"$wav_file{$base}\" -r 16000 -b 16 -e signed -t .wav - remix $rmx |\n";
  print $UTTSPK "$utt_id $spk\n";
  print $SEG "$utt_id $rec_id $utterance{$utt_id}->{'start'} $utterance{$utt_id}->{'end'}\n";
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $W;
close $SEG;

#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - write lists for acoustic model training
# writes Kaldi IO files under data/local/tmp/transtac/train/twoway/detroit/2006/lists

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
my $tmpdir = "data/local/tmp/transtac/train/twoway/detroit/2006";
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
# initialize hash for utterances
my %utterance = ();
my $sample_rate = 16000;
my $data_word_size = 4;
my $subs += 0;
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
    $subs += $transcript =~ s/ENGLISH\_thanks/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_thank\_you\_--\_thank\_you/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_no\_I\_have\_--\_I\_have/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_Baghdad/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_God\_willing/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_I\_am\_not\_responsible\_for/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_I\_don't\_know/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_any\_time/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_attention/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_bleach/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_booby\_trapped/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_boss/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_box/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_break/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_business/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_busy/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_but\_that\_takes\_time/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_by/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_car/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_case/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_cellular\_phone/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_convoy/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_cookies/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_cup/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_damage/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_desk/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_do\_you\_have/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_downtown/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_engine/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_enter/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_every\_think\_is\_okay\_did\_you\_hear/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_feet/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_flat/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_fluid/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_form/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_forty\_or\_ten/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_forty\_seven/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_garbage/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_gas\_station/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_good/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_high\_school/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_hose/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_hot\_line/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_job/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_launch/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_lawyer/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_license/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_line/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_manager/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_marble/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_marines/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_measurement/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_mile/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_mission/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_neighborhood/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_no\_I\_have/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_no\_problem/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_offices/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_office/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_oh/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_oil/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_order/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_owner/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_pipe/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_receipt/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_regime/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_registration/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_right/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_sergeant/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_short/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_speak\_English/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_table/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_tape/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_temporary/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_ten/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_that's\_ok/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_thirty/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_to\_be\_ownest/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_transmission/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_truck/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_very/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_we\_done\_baby/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_yeah/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_you\_know/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_any/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_I'm/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_no/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_and/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_or/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_at/<UNK>/g;
        # Not sure what this is?
    $subs += $transcript =~ s/<\/نهاية\_تداخل>$/<UNK>/g;
    $subs += $transcript =~ s/<\/نهاية\_ضجيج>/<UNK>/g;
    $subs += $transcript =~ s/<بداية\_تداخل>/<UNK>/g;
    $subs += $transcript =~ s/<\/نهاية\_تداخل>/<UNK>/g;
    $subs += $transcript =~ s/<\/نهاية\_ضجيج>/<UNK>/g;
    $subs += $transcript =~ s/<بداية\_ضجيج>/<UNK>/g;
    # remove non arabic punctuation
    $transcript =~ s/\.|\?/ /g;
    # remove arabic punctuation
    $transcript =~ s/؟/ /g;
    # not distinguishable 
    $transcript =~ s/\(\(\)\)/<UNK>/g;
    # single parens?
    $transcript =~ s/\(|\)//g;
    # carat?
    $transcript =~ s/\^//g;
    $transcript =~ s/<\/نهاية\_تداخل>/<UNK>/g;
        # mispronunciations
    $transcript =~ s/\+/ /g;
    $transcript =~ s/\s+/ /g;
    # dashes
    #$transcript =~ s/\-\-/<UNK>/g;
        # dashes?
    $subs += $transcript =~ s/\-/ /g;
    # percent sign?
    $transcript =~ s/%//g;
    # squeeze
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;

    my $base = basename $file, ".wav";
    my $rec = {
      transcript => "",
      start => "",
      end => "",
      speaker => "",
      filename => ""
    };
    $rec{'transcript'} = $transcript;
    $rec{'start'} = $start;
    $rec{'end'} = $end;
    $rec{'speaker'} = $speaker;
    $rec{'filename'} = $file;
    my $utt_id = $speaker . '-' . $base . '-' . $start . '-' . $end;
      $utterance{$utt_id} = \%rec;
  }
  close $TDF;
}
close $TR;
warn "substitutions\t$subs";
# store .wav files in hash 
my %wav_file = ();
open my $W, '<', $w or croak "problem with $w $!";
FILE: while ( my $line = <$W> ) {
    chomp $line;
  my ($volume,$directories,$file) = File::Spec->splitpath( $line );
    my $base = basename $file, ".wav";
    # remove suffixes _a and _b
  if ( $base =~ /(.+)_a$/ ) {
      $base = $1;
  }
  if ( $base =~ /(.+)_b$/ ) {
    $base = $1;
  }
    $wav_file{$base} = $line;
}

open my $WAVSCP, '+>', $wav_scp or croak "problem with $wav_scp $!";
open my $UTTSPK, '+>', $utt_to_spk or croak "problem with $utt_to_spk $!";
open my $TXT, '+>:utf8', $txt_out or croak "problem with $txt_out $!";
open my $SEG, '+>', $segs or croak "problem with $segs $!";
LINE: foreach my $utt_id ( sort keys %utterance ) {
    next LINE if ( $utterance{$utt_id}->{'end'} <= $utterance{$utt_id}->{'start'} );
    my $base = basename $utterance{$utt_id}->{'filename'}, ".wav";
    my $rec_id = $base;
  print $TXT "$utt_id $utterance{$utt_id}->{'transcript'}\n";
  print $WAVSCP "$rec_id sox -r 22050 -b 16 -e signed \"$wav_file{$base}\" -r 16000 -b 16 -e signed -t .wav - remix 2 |\n";
  print $UTTSPK "$utt_id $utterance{$utt_id}->{'speaker'}\n";
  print $SEG "$utt_id $rec_id $utterance{$utt_id}->{'start'} $utterance{$utt_id}->{'end'}\n";
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $W;
close $SEG;

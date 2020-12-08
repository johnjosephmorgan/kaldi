#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - write lists for acoustic model training
# writes files under data/local/tmp/transtac/train/twoway/dli/2006/lists

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
my $tmpdir = "data/local/tmp/transtac/train/twoway/dli/2006";
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
my $subs = 0;
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
    my $t = 0;
 RECORD:  while ( my $rec_info = <$TDF> ) {
    my %rec = ();
    chomp $rec_info;
    # skip header that starts with the word file 
    next RECORD if ( $rec_info =~ /^file/ );
    my ($file,$channel,$start,$end,$speaker,$speakerType,$speakerDialect,$transcript,$section,$turn,$segment,$sectionType,$suType,$speakerRole) = split /\t/, $rec_info, 14;
    $transcript = decode_utf8 $transcript;
    # Store in hash if some character is Arabic
    next RECORD if ( $transcript !~ /\p{Arabic}/ );
    $subs += $transcript =~ s/ENGLISH\_already/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_American/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_and\_also\_I\_would\_like\_to/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_any/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_before/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_box/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_break/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_but/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_cabling/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_coalition/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_contract/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_course/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_C\_P\_R/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_dashboard/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_designs/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_done/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_eighteen/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_facilities/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_flash\_light/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_he\_said\_electrical\_civil/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_I\_D/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_I\_thi-/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_it\_is\_torture/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_lieutenant/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_of\_course/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_oh/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_or/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_passport/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_pipe/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_police/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_pro-/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_project/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_schools/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_sergeant/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_sewerage/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_sometimes/<UNK>/g;
    $subs += $transcript =~ s/ENGLISH\_so/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_staff/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_thank\_you/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_torch\_light/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_training/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_very\_good\_very\_good/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_well/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_we're\_going\_to/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_what/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_where/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_window/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_yeah/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_yes/<UNK>/g;
$subs += $transcript =~ s/ENGLISH\_you\_know/<UNK>/g;
    # remove non arabic punctuation
    $transcript =~ s/\.|\?/ /g;
    # remove arabic punctuation
    $t += $transcript =~ s/؟/ /g;
    # not distinguishable 
    $transcript =~ s/\(\(\)\)/<UNK>/g;
    # single parens?
    $transcript =~ s/\(|\)//g;
    # carat?
    $transcript =~ s/\^//g;
    # dashes?
    $transcript =~ s/\-/ /g;
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
      speaker => ""
    };

    $rec{'transcript'} = $transcript;
    $rec{'start'} = $start;
    $rec{'end'} = $end;
    $rec{'speaker'} = $speaker;
    $rec{'filename'} = $file;
    my $utt_id = 'dli' . '-' . $speaker . '-' . $base . '-' . $start . '-' . $end;
    $utterance{$utt_id} = \%rec;
  }
  close $TDF;
}
close $TR;
warn "substitutions\t$subs";
open my $W, '<', $w or croak "problem with $w $!";
my %wav_file = ();
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

LINE: foreach my $utt_id ( sort keys %utterance ) {
  next LINE if ( $utterance{$utt_id}->{'end'} <= $utterance{$utt_id}->{'start'} );
  my $base = basename $utterance{$utt_id}->{'filename'}, ".wav";
  my $rec_id = $base;
  my $spk = 'dli' . '-' . $utterance{$utt_id}->{'speaker'};
  print $TXT "$utt_id $utterance{$utt_id}->{'transcript'}\n";
  print $WAVSCP "$rec_id sox -r 22050 -b 16 -e signed \"$wav_file{$base}\" -r 16000 -b 16 -e signed -t .wav - remix 2 |\n";
  print $UTTSPK "$utt_id $spk\n";
  print $SEG "$utt_id $rec_id $utterance{$utt_id}->{'start'} $utterance{$utt_id}->{'end'}\n";
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $SEG;

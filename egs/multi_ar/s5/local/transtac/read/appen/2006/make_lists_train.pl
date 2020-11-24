#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - write lists for acoustic model training
# writes files under data/local/tmp/transtac/train/read/appen/2006/lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;

use utf8;
use Encode;

binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';

# Initialize variables
my $tmpdir = "data/local/tmp/transtac/train/read/appen/2006";
my $transcripts_file = "/mnt/corpora/TRANSTAC/TRANSTAC Database P1-P4/Phase II/Iraqi Arabic-TX-TL/APPEN_1.5WAY_SEPT2006/Appen_1.5Way_Sept2006_TrainingSet_20061207/Appen_1.5Way_Sept2006_Transcription_TrainingSet_V4_20061207.txt";
# input wav file list
my $w = "$tmpdir/wav_list.txt";
# output temporary wav.scp file
my $wav_scp = "$tmpdir/lists/wav.scp";
# output temporary utt2spk file
my $utt_to_spk = "$tmpdir/lists/utt2spk";
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
# initialize utterance hash 
my %utterance = ();
my %wav_file = ();
my $sample_rate = 16000;
my $data_word_size = 4;
my $segs = "$tmpdir/lists/segments";
my $noise = 0;
my $percent = 0;
my $parens = 0;
my $question_marks = 0;
my $lrangle = 0;
my $underscores = 0;
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.

#system "mkdir -p $tmpdir/lists";
open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
# store transcripts in hash
LINEA: while ( my $line = <$TR> ) {
  my %rec = ();
  my $utt_id = "";
  my $date = "";
  my $event = "";
  my $spk_id = "";
  my $spk_num = "";
  my $uid = "";
  my $rec = {
    date => "",
    event => "",
    spk_id => "",
    spk_num => "",
    uid => "",
    transcript => ""
  };
  chomp $line;
  my ($utt_path,$sent) = split /\s/, $line, 2;
  $sent = decode_utf8 $sent;
  my ($volume,$directories,$file) = File::Spec->splitpath( $utt_path );
  my $base = basename $file;
  my @recording_attributes = split /\_/, $utt_path;
  if ( $#recording_attributes == 4 ) {
    next LINEA;
  } elsif ( $#recording_attributes == 3 ) {
    ($date,$event,$spk_id,$uid) = split /\_/, $base, 4;
    next LINEA unless ( $date =~ /2006/ );
    $rec{'date'} = $date;
    $rec{'event'} = $event;
    $rec{'spk_id'} = $spk_id;
    $rec{'uid'} = $uid;
    $rec{'filename'} = $file;
    $utt_id = $spk_id . '-' . $base;
  } else {
    croak "Problem with $line $!";
  }
  if ( defined $sent ) {
    # I think this means white space?
      $lrangle += $sent =~ s/<بداية_ضجيج>/<UNK>/g;
    $sent =~ s/ENGLISH\_cold\_room/<UNK>/g;
    $sent =~ s/ENGLISH\_double\_volume/<UNK>/g;
      # underscores
    $underscores += $sent =~ s/\_/ /g;
    # transcribe [int] (intermittent noise) as <UNK>
    $noise += $sent =~ s/\[int\]/<UNK>/g;
    # transcribe [spk] (speaker noise) as <UNK>
    $sent =~ s/\[spk\]/<UNK>/g;
    # transcribe [sta] stationary noise as <UNK>
    $noise += $sent =~ s/\[sta\]/<UNK>/g;
    # fragments
    #$sent =~ s/\s\-|\-\s/ /g;
    # cut off 
    $sent =~ s/^~|~$/ /g;
    # mispronunciations
    $sent =~ s/\+/ /g;
    $sent =~ s/\s+/ /g;
    # Unintelligible?
    $sent =~ s/\(\(\)\)/<UNK>/g;
    $sent =~ s/\(\(|\)\)/ /g;
    $sent =~ s/\s+/ /g;
    $sent =~ s/<\// /g;
    # remove arabic punctuation
    $question_marks += $sent =~ s/؟|؟/ /g;
    # (%...) indicates an interjection or filler
    $sent =~ s/\(%(.+?)\)/$1/g;
    # delete the percent sign?
    $percent += $sent =~ s/%//g;
    # carat?
    $sent =~ s/\^//g;
    # dashes?
    $sent =~ s/\-/ /g;
    # No dots
    $sent =~ s/\.//g;
    # no parens
    $parens += $sent =~ s/\(|\)/ /g;
    # squeeze
    $sent =~ s/\s+/ /g;
    $sent =~ s/^\s+//g;
    $sent =~ s/\s+$//g;
  } else {
    next LINEA;
  }
  $rec{'transcript'} = $sent;
  $utterance{$utt_id} = \%rec;
}
close $TR;
warn "noise\t$noise\npercent\t$percent\nparens\t$parens\nquestion marks\t؟\t$question_marks\n<بداية_ضجيج>\t$lrangle\nunderscores\t$underscores";
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
open my $TXT, '+>:utf8:', $txt_out or croak "problem with $txt_out $!";
open my $SEG, '+>', $segs or croak "problem with $segs $!";
UTTERANCE: foreach my $utt_id ( sort keys %utterance ) {
  my $base = basename $utterance{$utt_id}->{'filename'}, ".wav:";
  next UTTERANCE unless ( defined $wav_file{$base} );
  next UTTERANCE unless ( defined $utterance{$utt_id}->{'transcript'} );
  my $spk_id = $utterance{$utt_id}->{'spk_id'};
  my $rec_id = $base;
  my $f_size = ( -s $wav_file{$base});
  my $f_size_sans_head = $f_size - 44;
  my $f_secs = $f_size_sans_head / ( $sample_rate * $data_word_size );
  print $TXT "$utt_id $utterance{$utt_id}->{'transcript'}\n";
  print $WAVSCP "$rec_id sox -r 16000 -b 16 -e signed \"$wav_file{$base}\" -r 16000 -b 16 -e signed -t .wav - |\n";
  print $UTTSPK "$utt_id $spk_id\n";
  print $SEG "$utt_id $rec_id 0 $f_secs\n";
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $SEG;

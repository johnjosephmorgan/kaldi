#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train.pl - write lists for acoustic model training
# writes files under data/local/tmp/transtac/train/read/ma/2006/lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;
use Encode;

binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';

# Initialize variables
my $tmpdir = "data/local/tmp/transtac/train/read/ma/2006";
my $transcripts_file = "/mnt/corpora/TRANSTAC/TRANSTAC Database P1-P4/Phase I/Iraqi Arabic-TX-TL/MARINE_ACOUSTICS/Iraq1.5WayData_AllTranscriptions.txt";
# input wav file list
my $w = "$tmpdir/wav_list.txt";
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
my %wav_file = ();
my $sample_rate = 16000;
my $data_word_size = 4;
my $question_marks = 0;
my $backslashes = 0;
# done setting variables

# This script looks at 2 files.
# One containing text transcripts and another containing file names for .wav files.
# It associates a text transcript with a .wav file name.

system "mkdir -p $tmpdir/lists";
open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
# store transcripts in hash
LINEA: while ( my $line = <$TR> ) {
  my %rec = ();
  my $rec = {
    date => "",
    event => "",
    spk_id => "",
    uid => "",
    transcript => ""
  };
  chomp $line;
  my ($utt_path,$sent) = split /\s/, $line, 2;
  $sent = decode_utf8 $sent;
  my ($volume,$directories,$file) = File::Spec->splitpath( $utt_path );
  # get the basename of the wav file. 
  #Notice the colon after .wav.
  my $base = basename $file, ".wav:";
  my @recording_attributes = split /\_/, $utt_path, 4;
  my $utt_id = "";
  my ($date,$event,$spk_id,$uid) = split /\_/, $base, 4;
  $rec{'date'} = $date;
  $rec{'event'} = $event;
  $rec{'spk_id'} = $spk_id;
  $rec{'uid'} = basename $uid, '.wav';
  $rec{'filename'} = $file;
  $utt_id = join '-', $spk_id, $date, $event, $uid;
  if ( defined $sent ) {
    # backslash
    $backslashes += $sent =~ s/\\/ /g;
    # transcribe [int] (intermittent noise) as <UNK>
    $sent =~ s/\[int\]/<UNK>/g;
    # transcribe [spk] (speaker noise) as <UNK>
    $sent =~ s/\[spk\]/<UNK>/g;
    # transcribe [sta] stationary noise as <UNK>
    $sent =~ s/\[sta\]/<UNK>/g;
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
    # remove arabic punctuation
    $question_marks += $sent =~ s/؟/ /g;

    # (%...) indicates an interjection or filler
    $sent =~ s/\(%(.+?)\)/$1/g;
    # delete the percent sign?
    $sent =~ s/%//g;
    # carat?
    $sent =~ s/\^//g;
    # dashes?
    $sent =~ s/\-/ /g;
    # No dots
    $sent =~ s/\.//g;
    # squeeze
    $sent =~ s/\s+/ /g;
  } else {
    next LINEA;
  }
  $rec{'transcript'} = $sent;
  $utterance{$utt_id} = \%rec;
}
close $TR;
warn "backslashes\t$backslashes";
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
  next UTTERANCE unless ( defined $utterance{$utt_id}->{'filename'} );
  # get the basename.
  # Again notice the colon after .wav. 
  my $b = basename $utterance{$utt_id}->{'filename'}, ".wav:";
  next UTTERANCE unless ( defined $wav_file{$b} );
  my $rec_id = $b;
  my $f_size = ( -s $wav_file{$b});
  my $f_size_sans_head = $f_size - 44;
  my $f_secs = $f_size_sans_head / ( $sample_rate * $data_word_size );
  my $spk_id = $utterance{$utt_id}->{'spk_id'};
  print $TXT "$utt_id $utterance{$utt_id}->{'transcript'}\n";
  # The wav files appear to have been recorded in stereo.
  # We only use 1 channel.
  print $WAVSCP "$rec_id sox -r 16000 -b 16 -e signed \"$wav_file{$b}\" -r 16000 -b 16 -e signed -t .wav - remix 1 |\n";
  print $UTTSPK "$utt_id $spk_id\n";
print $SEG "$utt_id $rec_id 0 $f_secs\n";  
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $SEG;

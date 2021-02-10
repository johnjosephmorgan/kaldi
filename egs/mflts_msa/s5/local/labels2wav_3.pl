#!/usr/bin/env perl
# labels2wav_3.pl - Make audio files from diarization.

use strict;
use warnings;
use Carp;

BEGIN {
  @ARGV == 2 or croak "USAGE: $0 <SRC_FLAC_FILE> <OUTPUT_DIR>
For Example:
$0 src/data/flac/DH_0001.flac out_diarized
";
}

use File::Basename;

my ($src,$out) = @ARGV;

my $base = basename $src, ".flac";
my $labels = "$out/clusters/labels_threshold";
my $out_dir = "$out/audio_threshold";

mkdir $out_dir;

open my $LABELS, '<', $labels or croak "Problem with $labels $!";
my $i = 1000;
while ( my $line = <$LABELS> ) {
  chomp $line;
  my ($utt,$name) = split /\s+/, $line, 2;
  $name =~ s/\s+$//;
  my ($b,$start,$end) = split /\-/, $utt, 3;
  $start = $start * 1000;
  $start = $start / 100000;
  $end = $end * 1000;
  $end = $end / 100000;
  my $dur = $end - $start;
  mkdir "$out_dir/$name";
  my $out = "$out_dir/$name/${i}_${start}_${end}.wav";
  system "sox $src $out trim $start $dur";
  $i++;
}
close $LABELS;

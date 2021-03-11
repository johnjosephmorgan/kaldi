#!/usr/bin/env perl
# labels2wav.pl - Make audio files from diarization.

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
my $out_dir = "work/speakers/$base";

open my $LABELS, '<', $labels or croak "Problem with $labels $!";
my $i = 1000;
my $speaker_dir = "";
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
  if ( $name ne "" ) {
    $speaker_dir = $out_dir . "_${name}";
    system "mkdir -p $speaker_dir";
    my $out = "$speaker_dir/${i}_${start}_${end}.wav";
    system "sox $src $out trim $start $dur";
    $i++;
  }
  $speaker_dir = "";
}
close $LABELS;

#!/usr/bin/env perl

use strict;
use warnings;
use Carp;

BEGIN {
  @ARGV == 1 or croak "USAGE: $0 <SRC_FLAC_FILE>
For example:
$0 src/data/flac/DH_0001.flac
";
}

use File::Basename;
use File::Copy;

my ($src) = @ARGV;
my $base = basename $src, ".flac";
my $in = "$base/speechactivity/subsegments/segments";
my $out_dir = "$base/speechactivity/segmented_audio";

mkdir $out_dir;

open my $IN, '<', $in or croak "Problem with $in $!";
my $i = 1000;
while ( my $line = <$IN> ) {
  chomp $line;
  my ($segid,$recid,$start,$end) = split /\s+/, $line, 4;
  my $dur = $end - $start;
  my $out = "${i}_${start}_${end}.wav";
  system "sox $src $out_dir/$out trim $start $dur";
  $i++;
}

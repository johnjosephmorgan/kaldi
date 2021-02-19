#!/usr/bin/env perl
# make_silent_buffer_file.pl - Write a silent wav file.
# This script writes a wav file containing silence.
# Input:  A marker file
# Output: silent wav file 

use strict;
use warnings;
use Carp;

BEGIN {
  @ARGV == 1 or croak "USAGE: $0 <WAV_FILE>
for example:
$0 out_dirized/NISTMSA_A41_sM11iM16fM29_050910_sif/audio_threshold/1/1000_1.69_4.4.wav
";
}

use File::Basename;
use File::Copy;

my ($marker) = @ARGV;

# Store the samples info
my $base = basename $marker, "_marker.txt";
my $marker_dir = dirname $marker;
my $dir = dirname $marker_dir;
open my $SAMPLES, '<', "$marker" or croak "Problem with $marker !";
my $samples = <$SAMPLES>;
chomp $samples;
close $SAMPLES;

my $duration = 1.0;

# Append an "s" to indicate samples
$duration = $samples . 's';
# Make the sils directory
system "mkdir -p $dir/sils";
# Make a name for the output silence file
my $silwav = "$dir/sils/$base.wav";
# Write the silent wav file with sox
system "sox -n -r 16000  $silwav trim 0.0 $duration";

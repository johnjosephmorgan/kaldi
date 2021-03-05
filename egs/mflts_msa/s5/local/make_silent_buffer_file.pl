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
my $marker_dir = dirname $marker;
open my $SAMPLES, '<', "$marker" or croak "Problem with $marker !";
my $samples = <$SAMPLES>;
chomp $samples;
close $SAMPLES;

# Append an "s" to indicate samples
my $duration = $samples . 's';# express duration in seconds
my $duration_in_seconds = 0.0;
#warn "duration in samples: $duration";
$duration_in_seconds = $samples / 32000;
#warn "duration in seconds: $duration_in_seconds";
# Make a name for the output silence file
my $silwav_seconds = "$marker_dir/sil_seconds.wav";
my $silwav_samples = "$marker_dir/sil_samples.wav";
# Write the silent wav file with sox using samples
system "sox -n -r 16000  $silwav_samples trim 0s $duration";
# Write the silent wav file with sox using seconds
system "sox -n -r 16000  $silwav_seconds trim 0.0 $duration_in_seconds";

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
my $duration = $samples . 's';

# Make a name for the output silence file
my $silwav = "$marker_dir/sil.wav";
# Write the silent wav file with sox
#warn "duration: $duration";
system "sox -n -r 16000  $silwav trim 0s $duration";

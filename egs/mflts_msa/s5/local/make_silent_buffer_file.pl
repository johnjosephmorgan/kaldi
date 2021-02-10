#!/usr/bin/env perl
# make_silent_buffer_file.pl - Write a silent wav file.
# This script writes a wav file containing silence.
# Input: 3 arguments.
# 1. wav file
# 2. Samples data file created by get_info.sh script
# 3. percentage, the amount of desired overlap 
# Output: wav file with duration equal to percentage of input file.

use strict;
use warnings;
use Carp;

BEGIN {
  @ARGV == 3 or croak "USAGE: $0 <WAV_FILE> <SAMPLES_INFO_FILE> <PERCENTAGE>
for example:
$0 out_dirized/NISTMSA_A41_sM11iM16fM29_050910_sif/audio_threshold/1/1000_1.69_4.4.wav tmp/samples.txt 20
"
}

use File::Basename;
use File::Copy;

my ($inwav,$samples,$overlap_percent) = @ARGV;

# Store the samples info
my %samples = ();
open my $SAMPLES, '<', $samples or croak "Problem with $samples $!";

while ( my $line = <$SAMPLES> ) {
  chomp $line;
  my ($fn,$samps) = split /\t/, $line, 2;
  $samples{$fn} = $samps;
}
close $SAMPLES;

my $duration = 1.0;

foreach my $f (sort keys %samples) {
    if ( defined $samples{$f} ) {
	my $buffer_percent = (100 - $overlap_percent) / 100;
    # get the duration in number of samples
    $duration = $samples{$f} / $buffer_percent;
    # Append an "s" to indicate samples
    $duration = $duration . 's';
    my $base = basename $f;
    my $dir = dirname $f;
    # prepend "sil" to the file name
    my $silwav = 'sil_' . $base;
    system "sox -n -r 16000  $silwav trim 0.0 $duration";
    system "mv $silwav $dir";
  } else {
    warn "Problem with $f $!";
  }
}

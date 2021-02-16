#!/usr/bin/env perl
# make_silent_buffer_file.pl - Write a silent wav file.
# This script writes a wav file containing silence.
# Input: 2 arguments.
# 1. wav file
# 2. percentage, the amount of desired overlap 
# Output: wav file with duration equal to percentage of input file.

use strict;
use warnings;
use Carp;

BEGIN {
  @ARGV == 2 or croak "USAGE: $0 <WAV_FILE> <PERCENTAGE>
for example:
$0 out_dirized/NISTMSA_A41_sM11iM16fM29_050910_sif/audio_threshold/1/1000_1.69_4.4.wav 20
"
}

use File::Basename;
use File::Copy;

my ($inwav,$overlap_percent) = @ARGV;

# Store the samples info
my %samples = ();
my $base = basename $inwav, ".wav";
my $dir = dirname $inwav;
if ( ! -e "$dir/${base}_samples.txt" ) { 
    warn "$dir/${base}_samples.txt";
}
open my $SAMPLES, '<', "$dir/${base}_samples.txt" or croak "Problem with $dir/${base}_samples.txt $!";
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
    my $base = basename $f, ".wav";
    my $dir = dirname $f;
    system "mkdir -p $dir/sils";
    # prepend "sil" to the file name
    #my $silwav = 'sil_' . $base;
    my $silwav = "$dir/sils/$base.wav";
    system "sox -n -r 16000  $silwav trim 0.0 $duration";
    #system "mv $silwav $dir";
  } else {
    warn "Problem with $f $!";
  }
}

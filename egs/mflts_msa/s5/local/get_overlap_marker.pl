#!/usr/bin/env perl
# get_overlap_marker.pl - Get the sample number where the overlap begins

use strict;
use warnings;
use Carp;

# Input: 3 arguments, 2 file names and a number.
# The 2 files are the segmetns we want to overlap.
# We want the resulting file to overlap by a percentage given by the third argument.
# OUtput: A number indicating the sample where the overlap begins.

# This script assumes that:
# The input segment wav files have been written to a directory called wavs
# Information about the input segments has been written to a directory called infos
# The information is in a file with extension _samples.txt.

BEGIN {
    @ARGV == 3 or croak "USAGE $0 <First_Segment_file_name> <second_Segment_file_name> <Target_overlap_percentage>";
}

use File::Basename;
use List::Util qw( min max );

# Get the input arguments.
my ($seg_1,$seg_2,$target_percentage) = @ARGV;

# First we need the lengths of the 2 segments
# Get the info file corresponding to the first segment
# Get the basename of the first segment
my $seg_1_base = basename $seg_1, ".wav";
# Get the path to the wavs directory containing the first segment
my $seg_1_wavs_dir = dirname $seg_1;
# Get the path to the speaker directory containing the previous wavs directory
my $seg_1_spk_path = dirname $seg_1_wavs_dir;
# Get the basename of the speaker
my $seg_1_spk_base = basename $seg_1_spk_path;
# Set the path to the infos directory for the first segment
my $seg_1_infos_path = "$seg_1_spk_path/infos";
# Piece together the name of the samples file for the first segment
my $seg_1_samples_fn = "$seg_1_infos_path/${seg_1_base}_samples.txt";
# Check the the samples file exists
croak "$!" if ( -z $seg_1_samples_fn );
# Set 2 dummy variables that do not get used.
my $fn_1 = "";
my $fn_2 = "";
# Initialize the variables that will hold the number of samples in the 2 segments.
my $samples_1 = 0;
my $samples_2 = 0;
# Open the file with the first segment's sample count for reading.
open my $SEGONESAMPLES, '<', $seg_1_samples_fn or croak "Problem with file $seg_1_samples_fn $!";
# Get the total number of samples in the first segment.
while ( my $line = <$SEGONESAMPLES> ) {
    chomp $line;
    # The samples file has 2 fields, the file name and the number of samples.
    ($fn_1,$samples_1) = split /\t/, $line, 2;
}
close $SEGONESAMPLES;

# Repeat the above for the second segment
my $seg_2_base = basename $seg_2, ".wav";
my $seg_2_wavs_path = dirname $seg_2;
my $seg_2_spk_path = dirname $seg_2_wavs_path;
my $seg_2_spk_base = basename $seg_2_spk_path;
my $seg_2_infos_path = "$seg_2_spk_path/infos";
my $seg_2_samples_fn = "$seg_2_infos_path/${seg_2_base}_samples.txt";
open my $SEGTWOSAMPLES, '<', $seg_2_samples_fn or croak "Problem with file $seg_2_samples_fn $!";
while ( my $line = <$SEGTWOSAMPLES> ) {
    chomp $line;
    ($fn_2,$samples_2) = split /\t/, $line, 2;
}
close $SEGTWOSAMPLES;
# Make the output directory
my $output_marker_path = "out_diarized/overlaps/${seg_1_spk_base}_${seg_2_spk_base}_${seg_1_base}_${seg_2_base}";
system "mkdir -p $output_marker_path";
# Open the output marker file for writing
open my $MARKER, '+>', "$output_marker_path/marker.txt" or croak "Problem with $output_marker_path/marker.txt $!";
# Set theinitial conditions for the algorithm.
my $marker = $samples_1;
# Initialize the overlap length to 0.
my $current_overlap_length = 0;
# We add the lengths of the 2 segments to get the total length.
my $current_total_length = $samples_1 + $samples_2;
# The overlap percentage is equal to the current length over the total.
my $current_overlap_percentage = $current_overlap_length / $current_total_length;
# express target percentage as a decimal
my $decimal_target_percentage = $target_percentage / 100;
# Variable to display current percentage between 0 and 100 
my $show_percentage = 0;

# Use a loop to step down 
SAMPLE: for my $i ( 0 .. ($samples_1 + $samples_2 ) ) {
    # Get the total length of the current segment
    $current_total_length = $current_total_length -= 1;
    # Get the current overlap length
    $current_overlap_length += 1;
    # Get the current overlap percentage
    $current_overlap_percentage = $current_overlap_length / $current_total_length;
    # Store the current marker
    $marker = $samples_1 - $i; 
    $show_percentage = $current_overlap_percentage * 100;
    # Check if we are there
    if ( $current_overlap_percentage == $decimal_target_percentage ) {
	print $MARKER $marker;
	croak "We hit the target!";
    } elsif ( $current_overlap_percentage > $decimal_target_percentage ) {
	print $MARKER $marker;
	$show_percentage = $current_overlap_percentage * 100;
	exit();
	croak "We overshot the target !\nDone getting marker for $seg_1 and $seg_2.\nTarget Percent: $target_percentage\n Achieved percentage: $show_percentage.\noverlap length: $current_overlap_length\nTotal length: $current_total_length\n";
    }
}
close $MARKER;

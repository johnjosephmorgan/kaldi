#!/usr/bin/env perl
# get_overlap_marker.pl - Get the sample number where the overlap begins and ends

use strict;
use warnings;
use Carp;

# Input: 3 arguments, 2 file names and a number.
# The 2 files are the segmetns we want to overlap.
# We want the resulting file to overlap by a percentage given by the third argument.
# OUtput: A 2 files
# 1 file containing number indicating the sample where the overlap begins.
# 1 file containing number indicating the sample where the overlap ends.

# This script assumes that:
# The input segment wav files have been written to a directory called wavs
# Information about the input segments has been written to a directory called speakers
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
# Get the path to the speaker directory 
my $seg_1_spk_path = dirname $seg_1;
# Get    the speaker ID
my $seg_1_spk = basename $seg_1_spk_path;
# Piece together the name of the samples file for the first segment
my $seg_1_samples_fn = "out_diarized/work/speakers/$seg_1_spk/${seg_1_base}_samples.txt";
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
my $seg_2_spk_path = dirname $seg_2;
my $seg_2_spk = basename $seg_2_spk_path;
my $seg_2_samples_fn = "out_diarized/work/speakers/$seg_2_spk/${seg_2_base}_samples.txt";
croak "$!" if ( -z $seg_2_samples_fn );
    open my $SEGTWOSAMPLES, '<', $seg_2_samples_fn or croak "Problem with file $seg_2_samples_fn $!";
while ( my $line = <$SEGTWOSAMPLES> ) {
    chomp $line;
    ($fn_2,$samples_2) = split /\t/, $line, 2;
}
close $SEGTWOSAMPLES;

# express target percentage as a decimal
my $decimal_target_percentage = $target_percentage / 100;
# Make the output directory
my $output_marker_path = "out_diarized/overlaps/${seg_1_spk}_${seg_2_spk}_${seg_1_base}_${seg_2_base}";
system "mkdir -p $output_marker_path";
# Open the output marker file for writing
open my $START, '+>', "$output_marker_path/start.txt" or croak "Problem with $output_marker_path/start.txt $!";
open my $END, '+>', "$output_marker_path/end.txt" or croak "Problem with $output_marker_path/end.txt $!";
print $END "$samples_1";
close $END;
open my $TOT, '+>', "$output_marker_path/total.txt" or croak "Problem with $output_marker_path/total.txt $!";
open my $DUR, '+>', "$output_marker_path/overlap_duration.txt" or croak "Problem with $output_marker_path/overlap_duration.txt $!";
# Set theinitial conditions for the algorithm.
my $start = $samples_1;
# Initialize the overlap length to 0.
my $current_overlap_length = 0;
# We add the lengths of the 2 segments to get the total length.
my $current_total_length = $samples_1 + $samples_2;
warn "Initial total: $current_total_length";
# The overlap percentage is equal to the current length over the total.
my $current_overlap_percentage = $current_overlap_length / $current_total_length;
# Variable to display current percentage between 0 and 100 
my $show_percentage = 0;

# Use a loop to step down 
SAMPLE: for my $i ( 0 .. ($samples_1 + $samples_2 ) ) {
    # Get the total length of the current segment
    $current_total_length = $current_total_length -= 1;
    warn "Current total length $current_total_length\nsamples 1 $samples_1\noverlap $current_overlap_length\nsamples 2 $samples_2";
    if ( $current_total_length <= ( $samples_1 + $current_overlap_length ) ) {
	croak "Segment 2 too short";
    }
    # Get the current overlap length
    $current_overlap_length += 1;
    # Get the current overlap percentage
    $current_overlap_percentage = $current_overlap_length / $current_total_length;
    # Store the current marker
    $start = $samples_1 - $i; 
    $show_percentage = $current_overlap_percentage * 100;
    # Check if we are there
    if ( $current_overlap_percentage == $decimal_target_percentage ) {
	if ( ( $current_overlap_length >= $samples_1 ) or ( $current_overlap_length >= $samples_2 ) ) {
	    croak "Segment too small.";
	}
	print $START $start;
	print $TOT $current_total_length;
	print $DUR $current_overlap_length;
	#croak "We hit the target!";
	exit()
    } elsif ( $current_overlap_percentage > $decimal_target_percentage ) {
	#warn "overlap percent: $current_overlap_percentage";
	#warn "target percentage: $decimal_target_percentage";
	#warn "overlap length: $current_overlap_length";
	#warn "samples 1: $samples_1";
	#warn "samples 2: $samples_2";
	#warn "total length: $current_total_length";
	#warn "marker: $start";
	if ( ( $current_overlap_length >= $samples_1 ) or ( $current_overlap_length >= $samples_2 ) ) {
	    croak "Segment too small.";
	}
	print $START $start;
	print $TOT $current_total_length;
	print $DUR $current_overlap_length;
	$show_percentage = $current_overlap_percentage * 100;
	exit();
	croak "We overshot the target !\nDone getting marker for $seg_1 and $seg_2.\nTarget Percent: $target_percentage\n Achieved percentage: $show_percentage.\noverlap length: $current_overlap_length\nTotal length: $current_total_length\n";
    }
}
close $START;

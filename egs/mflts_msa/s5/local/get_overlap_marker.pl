#!/usr/bin/env perl
# get_overlap_marker.pl - Get the sample number where the overlap begins

use strict;
use warnings;
use Carp;

# Input: 3 arguments, 2 file names and a number
# The 2 files are the segmetns we want to overlap.
# We want the 2 files to overlap by the percentage given by the third argument.
# OUtput: A number indicating the sample where the overlap begins.
# Writes to a file under a directory called marks

BEGIN {
    @ARGV == 3 or croak "USAGE $0 <First_Segment_file_name> <second_Segment_file_name> <Target_overlap_percentage>";
}

use File::Basename;

my ($seg_1,$seg_2,$target_percentage) = @ARGV;

# We will store the markers in an array
my @marker = ();

# Get the info file corresponding to the first segment
# Get the basename of the first segment
my $seg_1_base = basename $seg_1, ".wav";
# Get the path to the wavs directory containing the first segment
my $seg_1_wavs_dir = dirname $seg_1;
# Get the path to the speaker directory containing the previous wavs directory
my $seg_1_spk_dir = dirname $seg_1_wavs_dir;
# Make the output directory
system "mkdir -p $seg_1_spk_dir/marks";
# Open the output marker file
open my $MARKER, '+>', "$seg_1_spk_dir/marks/${seg_1_base}_marker.txt" or croak "Problem with $seg_1_spk_dir/marks/${seg_1_base}_marker.txt $!";
# Get the path to the infos directory for the first segment
my $seg_1_infos_dir = "$seg_1_spk_dir/infos";
# Piece together the name of the samples file for the first segment
my $seg_1_samples_fn = "$seg_1_infos_dir/${seg_1_base}_samples.txt";
croak "$!" if ( -z $seg_1_samples_fn );
my $fn_1 = "";
my $fn_2 = "";
my $samples_1 = 0;
my $samples_2 = 0;
open my $SEGONESAMPLES, '<', $seg_1_samples_fn or croak "Problem with file $seg_1_samples_fn $!";
# Get the total number of samples in the first segment
while ( my $line = <$SEGONESAMPLES> ) {
    chomp $line;
    ($fn_1,$samples_1) = split /\t/, $line, 2;
}
close $SEGONESAMPLES;

# Repeat the above for the second segment
my $seg_2_base = basename $seg_2, ".wav";
my $seg_2_wavs_dir = dirname $seg_2;
my $seg_2_spk_dir = dirname $seg_2_wavs_dir;
my $seg_2_infos_dir = "$seg_2_spk_dir/infos";
my $seg_2_samples_fn = "$seg_2_infos_dir/${seg_2_base}_samples.txt";
open my $SEGTWOSAMPLES, '<', $seg_2_samples_fn or croak "Problem with file $seg_2_samples_fn $!";
# Get the total number of samples in the second segment
while ( my $line = <$SEGTWOSAMPLES> ) {
    chomp $line;
    ($fn_2,$samples_2) = split /\t/, $line, 2;
}

close $SEGTWOSAMPLES;

# Initialize variables
$marker[0] = 0;
my $current_total_distance = $marker[0] + $samples_2;
$marker[1] = $samples_1;
$current_total_distance = $marker[1] + $samples_2;
my $current_overlap_distance = 0;
my $current_overlap_percentage = $current_overlap_distance / $current_total_distance;
if ( $current_overlap_percentage == $target_percentage ) {
    print "$marker[1]\n";
    croak "Done getting marker."
} elsif ( $current_overlap_percentage < $target_percentage ) {
    $marker[2] = abs($marker[1] - $marker[0] ) / 2 - $marker[0];
} elsif ( $current_overlap_percentage > $target_percentage ) {
$marker[2] = abs( $marker[1] - $marker[0] ) / 2 + $marker[0];
}

for my $i ( 3 .. ( $samples_1 + $samples_2 )) {
    $current_overlap_percentage = $current_overlap_distance / $current_total_distance;
    if ( $current_overlap_percentage == $target_percentage ) {
	print "$marker[$i - 1]";
    } elsif ( $current_overlap_percentage < $target_percentage ) {
	$marker[$i] = abs( $marker[$i - 1] - $marker[$i - 2]) / 2 + $marker[$i - 1];
    } elsif ( $current_overlap_percentage > $target_percentage ) {
	$marker[$i] = abs( $marker[$i - 1] - $marker[$i -2 ]) / 2 + $marker[$i - 1];
    }
    if ( $i == ( $samples_1 + $samples_2 ) ) {
	print $MARKER "$marker[$i]\n";
	croak "Done getting marker.";
    }
}
close $MARKER;

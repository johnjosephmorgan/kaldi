#!/usr/bin/env perl
# pairs2rttm.pl - Write rttm file
use strict;
use warnings;
use Carp;

# input: The path to a directory with  a file that has pair-level overlap information
# output: an rttm file with the recording-level overlap information

BEGIN {
    @ARGV == 1 or croak "USAGE: $0 <DIRECTORY>
For Example:
$0 out_diarized/concats/0
";
}

my ($dir) = @ARGV;

# open the input pair-level file
open my $PAIRS, '<', "$dir/pairs.txt" or croak "Problem with $dir/pairs.txt $!";
# open the output recording-level file for writing
open my $RTTM, '+>', "$dir/overlap.rttm" or croak "Problem with $dir/overlap.rttm $!";

# initialize the variables for the segment start times
my $start_1 = 0;
my $start_2 = 0;

# There is 1 pair per line in the input file
while ( my $line = <$PAIRS> ) {
    chomp $line;
    # first split the 2 pairs on the pattern SPEAKER
    # a_1 has information on the first segment a_3 on the second
    my ($a_1,$a_2,$a_3) = split /\<NA\>(SPEAKER)/, $line, 2;
    # There are 4 relevant fields: rec_id, start, duration, and speaker id
    my ($type_1,$rec_id_1,$chn_1,$begin_1,$dur_1,$foo_1,$foo_2,$spk_1,$foo_3) = split /\s+/, $a_1, 9;
    # We need the times in seconds
    my $start_1_in_seconds = $start_1 / 32000;
    my $dur_1_in_seconds = $dur_1 / 32000;
    # WRite the fields for the first segment on 1 line
    print $RTTM "SPEAKER $rec_id_1 $chn_1 $start_1_in_seconds $dur_1 \<NA\> \<NA\> $spk_1 \<NA\> \<NA\>\n";
    # get the fields for the  second segment
    my ($empty,$rec_id_2,$chn_2,$begin_2,$dur_2,$foo_5,$foo_6,$spk_2,$foo_7,$foo_8) = split /\s+/, $a_3, 9;
    # update start for segment 2
    $start_2 += $begin_2;
    # We need the times in seconds
    my $start_2_in_seconds = $start_2 / 32000;
    my $dur_2_in_seconds = $dur_2 / 32000;
    # write the fields for the second segment on the next line
    print $RTTM "SPEAKER $rec_id_2 $chn_2 $start_2_in_seconds $dur_2_in_seconds \<NA\> \<NA\> $spk_2 \<NA\> \<NA\>\n";
    # set end time
    my $end = $begin_2 + $dur_2;
    # update begin time for segment 1
    $start_1 += $end;
    # reset start of segment 2
    $start_2 = $end;
}
close $PAIRS;
close $RTTM;

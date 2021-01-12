#!/usr/bin/env perl
# rats_sad_make_utt2spk.pl - Write utt2spk file

use strict;
use warnings;
use Carp;

use File::Basename;

foreach my $f ( 'dev-1', 'dev-2', 'train' ) {
    open my $UTTS, '<', "data/$f/utt.txt" or croak "Problem with data/$f/utt.txt $!";
    open my $UTTSPK, '+>', "data/$f/utt2spk" or croak "Problem with data/$f/utt2spk $!";
    # store the Utterance IDs
    my %utts = ();
    while ( my $line = <$UTTS> ) {
	chomp $line;
	$utts{$line} = 1;
    }
    close $UTTS;
    # Write the wav.scp
    foreach my $utt_id ( sort keys %utts ) {
	my ($spk,$foo) = split /\_/, $utt_id, 2;
	print $UTTSPK "$utt_id $spk\n";
    }
    close $UTTSPK;
}

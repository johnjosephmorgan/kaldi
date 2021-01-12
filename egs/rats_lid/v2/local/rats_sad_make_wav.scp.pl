#!/usr/bin/env perl
# rats_sad_make_wav.scp.pl - Prepare wav.scp

use strict;
use warnings;
use Carp;

use File::Basename;

foreach my $f ( 'dev-1', 'dev-2', 'train' ) {
    open my $FLACS, '<', "data/$f/flac.txt" or croak "Problem with data/$f/flac.txt $!";
    open my $UTTS, '<', "data/$f/utt.txt" or croak "Problem with data/$f/utt.txt $!";
    open my $WAVSCP, '+>', "data/$f/wav.scp" or croak "Problem with data/$f/wav.scp $!";
    # store the flacs
    my %flacs = ();
    while ( my $line = <$FLACS> ) {
	chomp $line;
	my $uid = basename $line, '.flac';
	$flacs{$uid} = $line;
    }
    close $FLACS;
    # store the utterances
    my %utts = ();
    while ( my $line = <$UTTS> ) {
	chomp $line;
	$utts{$line} = 1;
    }
    close $UTTS;
    # Write the wav.scp
    foreach my $utt_id ( sort keys %utts ) {
	print $WAVSCP "$utt_id sox $flacs{$utt_id} -t wav |\n";
    }
    close $WAVSCP;
}

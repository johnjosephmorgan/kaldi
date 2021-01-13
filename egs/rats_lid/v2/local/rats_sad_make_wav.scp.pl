#!/usr/bin/env perl
# rats_sad_make_wav.scp.pl - Prepare wav.scp

use strict;
use warnings;
use Carp;

use File::Basename;

foreach my $f ( 'dev-1', 'dev-2', 'train' ) {
    open my $FLACS, '<', "data/$f/flac.txt" or croak "Problem with data/$f/flac.txt $!";
    open my $UTTLANG, '<', "data/$f/uttlang.txt" or croak "Problem with data/$f/uttlang.txt $!";
    open my $WAVSCP, '+>', "data/$f/wav.scp" or croak "Problem with data/$f/wav.scp $!";
        open my $UTTSPK, '+>', "data/$f/utt2spk" or croak "Problem with data/$f/utt2spk $!";
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
    my %lang = ();
    while ( my $line = <$UTTLANG> ) {
	chomp $line;
	my ($utt,$lang) = split /\s/, $line, 2;
	$lang{$utt} = $lang;
	$utts{$utt} = 1;
    }
    close $UTTLANG;
    # Write the wav.scp
    foreach my $utt_id ( keys %utts ) {
	print $WAVSCP "$lang{$utt_id}_${utt_id} sox $flacs{$utt_id} -t wav - |\n";
	print $UTTSPK "$lang{$utt_id}_${utt_id} $lang{$utt_id}\n";
    }
    close $WAVSCP;
    close $UTTSPK;
}

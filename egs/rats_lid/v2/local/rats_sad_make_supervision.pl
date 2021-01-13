#!/usr/bin/env perl
# rats_sad_make_supervision.pl - Prepare utt2spl and wav.scp

# This script assumes the following files have been written in previous steps:
# data/{dev-1,dev-2,train}/flac.txt
# data/{dev-1,dev-2,train}/utt2lang.txt
# It writes the following files:
# data/{dev-1,dev-2,train}/utt2spk
# data/{dev-1,dev-2,train}/wav.scp
# data/{dev-1,dev-2,train}/utt2lang

use strict;
use warnings;
use Carp;

use File::Basename;

my @folds = ( 'dev-1', 'dev-2', 'train' );

foreach my $f ( @folds ) {
    open my $FLACS, '<', "data/$f/flac.txt" or croak "Problem with data/$f/flac.txt $!";
    open my $UTTLANGIN, '<', "data/$f/utt2lang.txt" or croak "Problem with data/$f/utt2lang.txt $!";
    open my $WAVSCP, '+>', "data/$f/wav.scp" or croak "Problem with data/$f/wav.scp $!";
    open my $UTTSPK, '+>', "data/$f/utt2spk" or croak "Problem with data/$f/utt2spk $!";
    open my $UTTLANG, '+>', "data/$f/utt2lang" or croak "Problem with data/$f/utt2lang $!";

    # store the flacs
    my %flacs = ();
    while ( my $line = <$FLACS> ) {
	chomp $line;
	my $uid = basename $line, '.flac';
	$flacs{$uid} = $line;
    }
    close $FLACS;

    # store the utterance and language IDs
    my %utts = ();
    my %lang = ();
    while ( my $line = <$UTTLANGIN> ) {
	chomp $line;
	my ($utt,$lang) = split /\s/, $line, 2;
	$lang{$utt} = $lang;
	$utts{$utt} = 1;
    }
    close $UTTLANG;

    # Write the utt2spk, utt2lang and wav.scp
    foreach my $utt_id ( keys %utts ) {
	# Notice that we prepend the language id to the utt id
	print $WAVSCP "$lang{$utt_id}_${utt_id} sox $flacs{$utt_id} -t wav - |\n";
	print $UTTSPK "$lang{$utt_id}_${utt_id} $lang{$utt_id}\n";
	print $UTTLANG "$lang{$utt_id}_${utt_id} $lang{$utt_id}\n";
    }
    close $WAVSCP;
    close $UTTSPK;
}

#!/usr/bin/env perl
# rats_sad_data_prep.pl - Prepare utt2lang and wav.scp files

use strict;
use warnings;
use Carp;

system "mkdir -p data/{dev-1,dev-2,train}";

open my $TRAIN, '+>', "data/train/utt2lang" or croak "Problem writing file data/train/utt2lang $!";
open my $DEVONE, '+>', "data/dev-1/utt2lang" or croak "Problem writing file data/dev-1/utt2lang $!";
open my $DEVTWO, '+>', "data/dev-2/utt2lang" or croak "Problem writing file data/dev-2/utt2lang $!";

while ( my $line=<> ) {
    my @fields = split /\t/, $line, 12;
    if ( $fields[0] -eq 'train' ) {
	print $TRAIN "$fields[1] $fields[8]\n";
	} elsif ( $fields[0] -eq 'dev-1' ) {
	    print $DEVONE "$fields[1] $fields[8]\n";
	    } elsif ( $fields[0] -eq 'dev-2' ) {
		print $DEVTWO "$fields[1] $fields[8]\n";

    } else {
	croak "$Problem with line $!";
    }
    

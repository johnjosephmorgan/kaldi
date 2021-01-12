#!/usr/bin/env perl
# rats_sad_data_prep.pl - Prepare utt2lang

use strict;
use warnings;
use Carp;

# make the directories
system "mkdir -p data/dev-1";
system "mkdir -p data/dev-2";
system "mkdir -p data/train";

open my $TRAIN, '+>', "data/train/utt2lang" or croak "Problem writing file data/train/utt2lang $!";
open my $DEVONE, '+>', "data/dev-1/utt2lang" or croak "Problem writing file data/dev-1/utt2lang $!";
open my $DEVTWO, '+>', "data/dev-2/utt2lang" or croak "Problem writing file data/dev-2/utt2lang $!";

my @fields = ();
while ( my $line=<> ) {
    chomp $line;
    @fields = split /\t/, $line, 12;
    if ( $fields[0] eq 'train' ) {
	print $TRAIN "$fields[1] $fields[8]\n";
    } elsif ( $fields[0] eq 'dev-1' ) {
	print $DEVONE "$fields[1] $fields[8]\n";
    } elsif ( $fields[0] eq 'dev-2' ) {
	print $DEVTWO "$fields[1] $fields[8]\n";
    } else {
	croak "Problem with $line $!";
    }
}
close $TRAIN;
close $DEVONE;
close $DEVTWO;

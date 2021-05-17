#!/usr/bin/env perl

# Copyright 2017 John Morgan
# Apache 2.0.

# make_lists.pl - write lists for acoust model training
# writes files under data/local/tmp/lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;

my $tmpdir = "data/local/tmp/arti";

my ($d) = @ARGV;

my $p = "conf/arti/Recordings_French.txt";

system "mkdir -p $tmpdir/lists";

# input wav file list
my $w = "$tmpdir/wav_list.txt";

# output temporary wav.scp files
my $o = "$tmpdir/lists/wav.scp";

# output temporary utt2spk files
my $u = "$tmpdir/lists/utt2spk";

# output temporary text files
my $t = "$tmpdir/lists/text";

# initialize hash for prompts
my %p = ();

open my $P, '<', $p or croak "problem with $p $!";

# store prompts in hash
LINEA: while ( my $line = <$P> ) {
    chomp $line;

    my ($i,$sent) = split /\t/, $line, 2;
    $p{$i} = $sent;
}
close $P;

open my $W, '<', $w or croak "problem with $w $!";
open my $O, '+>', $o or croak "problem with $o $!";
open my $U, '+>', $u or croak "problem with $u $!";
open my $T, '+>', $t or croak "problem with $t $!";

 LINE: while ( my $line = <$W> ) {
     chomp $line;
     my ($volume,$directories,$file) = File::Spec->splitpath( $line );
     my @dirs = split /\//, $directories;
     my $r = basename $line, ".wav";
     my ($s,$i) = split /\_/, $r, 2;
     my $speaker = $dirs[-1];

	print $T "$r\t$p{$i}\n";
     print $O "$r\tsox $line -t .wav -|\n";
     print $U "$r\t$s\n";
}
close $T;
close $O;
close $U;
close $W;

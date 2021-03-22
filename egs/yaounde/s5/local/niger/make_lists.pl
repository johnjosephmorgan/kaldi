#!/usr/bin/env perl

# Copyright 2018 John Morgan
# Apache 2.0.

# make_lists.pl - write lists for acoustic model training
# writes files under data/local/tmp/niger/lists

use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 1 or croak "USAGE: $0 <DATA_DIR>
Example:
$0 /mnt/corpora/niger_west_african_fr
"
}

use File::Spec;
use File::Copy;
use File::Basename;

my $tmpdir = "data/local/tmp/niger";

my ($d) = @ARGV;

my $p = "conf/niger/niger_wav_file_name_transcript.tsv";

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
    my ($j,$sent) = split /\t/, $line, 2;
    my ($volume,$directories,$file) = File::Spec->splitpath( $j );
    my @dirs = split /\//, $directories;
    my $bn = basename $j, ".wav";
    my ($x,$y,$s,$i) = split /\_/, $j, 4;
    $p{$bn} = $sent;
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
     my $speaker = $dirs[-1];

     # only work with utterances in transcript file
     if ( exists $p{$r} ) {
	 my $fn = $r . ".wav";
	 print $T "$r\t$p{$r}\n";
	 print $O "$r\tsox $line -t .wav - |\n";
	 print $U "$r\t$speaker\n";
     } else {
	 warn "no transcript for $line";
     }
}
close $T;
close $O;
close $U;
close $W;

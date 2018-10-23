#!/usr/bin/env perl

# Copyright 2018 John Morgan
# Apache 2.0.

# make_lists.pl - write lists for acoustic model training
# writes files under data/local/tmp/yaounde/lists

use strict;
use warnings;
use Carp;


BEGIN {
    @ARGV == 1 or croak "USAGE: $0 <DATA_SRC_DIR>
Example:
$0 Yaounde
"
}

use File::Spec;
use File::Copy;
use File::Basename;

my $tmpdir = "data/local/tmp/yaounde";

my ($d) = @ARGV;

my $p = "$d/transcripts/train/yaounde/fn_text.txt";

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
    my ($j,$sent) = split /\s/, $line, 2;
    my ($volume,$directories,$file) = File::Spec->splitpath( $j );
    my @dirs = split /\//, $directories;
    my $mode = "$dirs[4]";
    my $speaker = $dirs[-1];
    my $bn = basename $file, ".wav";
    my ($x,$s,$i) = split /\-/, $bn, 3;
    my $k = 'yaounde-' . $s . '-' . $mode . '-' . $i;
    # dashes?
    $sent =~ s/(\w)(\p{dash_punctuation}+?)/$1 $2/g;
    $p{$k} = $sent;
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
     my $mode = $dirs[4];
     my $r = basename $line, ".wav";
     my ($x,$s,$i) = split /\-/, $r, 3;
     my $speaker = $dirs[-1];
     my $sd = 'yaounde-' . $s;
     my $bn = $sd . '-' . $mode . '-' . $i;
     my $fn = $bn . ".wav";
     print $T "$bn $p{$bn}\n";
     print $O "$bn sox $line -t .wav - |\n";
     print $U "$bn $sd\n";
}
close $T;
close $O;
close $U;
close $W;

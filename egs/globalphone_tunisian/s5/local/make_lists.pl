#!/usr/bin/env perl
# make_lists.pl - write lists for acoustic model training

use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 1 or croak "USAGE: make_lists.pl <FOLD>
Example:
$0 dev
";
}

use File::Spec;
use File::Copy;
use File::Basename;


my ($fld) = @ARGV;

my $tmpdir = "data/local/tmp/gp/arabic";
my $p = "$tmpdir/$fld/prompts.tsv";

system "mkdir -p $tmpdir/$fld/lists";

# input wav file list
my $w = "$tmpdir/$fld/lists/wav.txt";

# output temporary wav.scp file
my $o = "$tmpdir/$fld/lists/wav.scp";

# output temporary utt2spk file
my $u = "$tmpdir/$fld/lists/utt2spk";

# output temporary text files
my $t = "$tmpdir/$fld/lists/text";

# initialize hash for prompts
my %p = ();

open my $P, '<', $p or croak "problem with $p $!";

# store prompts in hash
LINEA: while ( my $line = <$P> ) {
    chomp $line;
    my ($j,$sent) = split /\s/, $line, 2;
    $p{$j} = $sent;
}
close $P;

open my $W, '<', $w or croak "problem with $w $!";
open my $O, '+>', $o or croak "problem with $o $!";
open my $U, '+>', $u or croak "problem with $u $!";
open my $T, '+>', $t or croak "problem with $t $!";

 LINE: while ( my $line = <$W> ) {
     chomp $line;
     my ($volume,$directories,$file) = File::Spec->splitpath( $line );
     my $u = basename $line, ".wav";
     my ($s,$i) = split /\_/, $u, 2;
     #$s =~ s/AR(\d{1,3})/$1/;

     if ( exists $p{$u} ) {
	 # remove parens
	 $p{$u} =~ s/\(|\)//g;
	 print $T "$u\t$p{$u}\n";
	 print $O "$u\tsox $line -t .wav - |\n";
	 print $U "$u\t$s\n"
     }
}
close $T;
close $O;
close $U;
close $W;

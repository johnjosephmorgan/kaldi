#!/usr/bin/perl -w
# make_lists.pl - write lists for acoustic model training
# writes files under data/local/tmp/gp/lists

use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 1 or croak "USAGE: $0 <GP_DIRECTORY_PATH>
example:
$0 /mnt/corpora/Globalphone/French/adc/wav
"
}

use File::Spec;
use File::Copy;
use File::Basename;

my ($d) = @ARGV;

my $tmpdir = "data/local/tmp/gp";

my $p = "conf/gp/train_fn_text.tsv";

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
    my $bn = basename $file, ".wav";
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
     my $r = basename $line, ".wav";
     my ($s,$i) = split /\_/, $r, 2;
     my $u = $s . '_' . $i;

     if ( exists $p{$r} ) {
	 print $T "$u\t$p{$r}\n";
	 print $O "$u\tsox $line -t .wav - |\n";
	 print $U "$u\t$s\n"
     }
}
close $T;
close $O;
close $U;
close $W;

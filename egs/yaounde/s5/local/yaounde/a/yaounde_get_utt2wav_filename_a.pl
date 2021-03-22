#!/usr/bin/perl -w
#get_utt2wavfilename_a.pl - write wav.scp file
use strict;
use warnings;
use Carp;

use File::Basename;
use File::Spec;

my $w = "data/local/tmp/yaounde_wav_filenames_a.txt";
my $out = "data/local/tmp/yaounde_wav_a_unsorted.scp";

open my $W, '<', "$w" or croak "could not open file $w for reading $!";

open my $O, '+>', "$out" or croak "could not open file $out for writing $!";

while ( my $line = <$W> ) {
    chomp $line;
    my $utt = basename $line, ".wav";
    my ($volume,$directories,$file) = File::Spec->splitpath( $line );
    my $spk = basename $directories;
    print $O "$utt\t$line\n";
}
close $W;
close $O;

#!/usr/bin/perl -w
# yaounde_get_utt2spk_a.pl - make tt 2spkfile
use strict;
use warnings;
use Carp;
use File::Spec;
use File::Basename;

my $wavs = "data/local/tmp/yaounde_wav_filenames_a.txt";
my $out = "data/local/tmp/yaounde_utt2spk_a_unsorted.txt";

open my $W, '<', "$wavs" or croak "could not open $wavs for reading $!";

open my $O, '+>', "$out", or croak "could not open file $out for writing $!";

while ( my $line = <$W> ) {
    chomp $line;
    my $utt = basename $line, ".wav";
    my ($volume,$directories,$file) = File::Spec->splitpath( $line );
    my $spk = basename $directories;
    print $O "$utt\t$spk\n";
}
close $W;
close $O;

#!/usr/bin/perl -w
# yaounde_get_spk2utt_b.pl - make spk2utt file
use strict;
use warnings;
use Carp;
use File::Spec;
use File::Basename;

my $wavs = "data/local/tmp/yaounde_wav_filenames_b.txt";
my $out = "data/local/tmp/yaounde_spk2utt_b_unsorted.txt";

open my $W, '<', "$wavs" or croak "could not open $wavs for reading $!";

open my $O, '+>', "$out" or croak "could not open file $out for writing $!";

# associate each utterance with its speaker 
my %spk_utt = ();
while ( my $line = <$W> ) {
    chomp $line;
    my $utt = basename $line, ".wav";
    my ($volume,$directories,$file) = File::Spec->splitpath( $line );
    my $spk = basename $directories;
    push @{$spk_utt{$spk}}, $utt;
}
close $W;

foreach my $s (sort keys %spk_utt ) {
    print $O "$s\t@{$spk_utt{$s}}\n";
}
close $O;

#!/usr/bin/env perl
# rats_sad_flac2wav.sp.pl - Write wav.scp from flac file list.

use strict;
use warnings;
use Carp;

use File::Basename;

while ( my $line = <> ) {
    chomp $line;
    my $utt_id = basename $line, '.flac';
    print "$utt_id sox $line -t wav |\n"
}

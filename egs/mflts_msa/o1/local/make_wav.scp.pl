#!/usr/bin/env perl
# make_wav.scp.pl - Write the wav.scp file

use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 2 or croak "USAGE: $0 <INPUT_DATA_DIR> <FOLD>";
}

my ($datadir,$fld) = @ARGV;
# Input comes from $datadir
# output is written to data/$fld
open my $FLDRTTM, '+>', "data/$fld/overlap.rttm" or croak "Problem with data/$fld/overlap.rttm $!";
my %place = ();

opendir my $DIRS, "$datadir/$fld";
my @dirs = readdir $DIRS;

DIR: foreach my $d (sort @dirs ) {
    next DIR unless ( -e "$datadir/$fld/$d/overlap.rttm" );
    open my $RTTM, '<', "$datadir/$fld/$d/overlap.rttm" or croak "Problem with $datadir/$fld/$d/overlap.rttm $!";
    while ( my $line = <$RTTM> ) {
	chomp $line;
	print $FLDRTTM "$line\n";
	my ($type,$reco_id,$chn,$start,$dur,$u,$v,$spk,$y,$z) = split /\s+/, $line, 10;
	$place{$reco_id} = $d;
    }
    close $RTTM;
}
closedir $DIRS;
close $FLDRTTM;

open my $WAVSCP, '+>', "data/$fld/wav.scp" or croak "Problem with data/$fld/wav.scp $!";
open my $FRTTM, '<', "data/$fld/overlap.rttm" or croak "Problem with data/$fld/overlap.rttm $!";
while ( my $line = <$FRTTM> ) {
    chomp $line;
    my ($type,$reco_id,$chn,$start,$dur,$u,$v,$spk,$y,$z) = split /\s+/, $line, 10;
    print $WAVSCP "$reco_id sox $datadir/$fld/$place{$reco_id}/overlap.wav -t wav - |\n";
}
close $FRTTM;
close $WAVSCP;

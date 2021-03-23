#!/usr/bin/perl -w
# get_prompts.pl - make  a prompts file

use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 1 or croak "USAGE: get_prompts.pl <FOLD>
$0 dev
";
}

my ($fld) = @ARGV;

my $o = "data/local/tmp/gp/arabic/$fld/prompts.tsv";
my $l = "data/local/tmp/gp/arabic/$fld/lists/trl.txt";

open my $L, '<', "$l" or croak "$l $!";

open my $O, '+>', "$o" or croak "problems with $o  $!";

while ( my $line = <$L> ) {
    chomp $line;
    open my $T, '<', $line or croak "problems with $line $!";
    my $spkr = "";
    my $sn = 0;
    LINE: while ( my $linea = <$T> ) {
	chomp $linea;
	$linea =~ s/$//;

	next LINE if ( $linea =~ /^$/);

	if ( $linea =~ /^\;SpRecheRID\s(\d{1,3})/ ) {
	    $spkr = $1;
	} elsif ( $linea =~ /^\;\s(\d{1,})/ ) {
	    my $n = $1;
	    print $O "AR${spkr}_${n}.adc\t";
	} else {
	    print $O "$linea\n";
	}      
    }
    close $T;
}
close $O;

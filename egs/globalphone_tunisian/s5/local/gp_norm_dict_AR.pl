#!/usr/bin/env perl

use strict;
use warnings;
use Carp;

# normalizes the GlobalPhone Arabic dictionary.
# Removes the braces that separate word & pronunciation. 
# Removes the 'M_' marker from each phone.

BEGIN {
    @ARGV == 1 or croak "USAGE:  <DICT>
$0 /mnt/corpora/Globalphone/GlobalPhoneLexicons/Arabic/Arabic-GPDict.txt
";
}

my ($in_dict) = @ARGV;

open my $L, '<', $in_dict or croak "Problems with $in_dict $!";
LINE: while ( my $line = <$L>) {
    # files may have CRLF line-breaks!
    $line =~ s/\r//g;
    next LINE if($line =~ /\+|\=|^\{\'|^\{\-|\<_T\>/);

    $line =~ m:^\{?(\S*?)\}?\s+\{?(.+?)\}?$: or croak "Bad line: $line";
    my $word = $1;
    my $pron = $2;
    # Silence will be added later to the lexicon
    next if ($pron =~ /SIL/);

    # First, normalize the pronunciation:

    $pron =~ s/\{//g;

    # remove leading or trailing spaces
    $pron =~ s/^\s*//;
    $pron =~ s/\s*$//;

    $pron =~ s/ WB\}//g;
    $pron=~ s/\}//g;
    # Normalize spaces
    $pron =~ s/\s+/ /g;
    # Get rid of the M_ marker before the phones
    $pron =~ s/M_//g;

    # Next, normalize the word:
    # Pron variants should have same orthography
    $word =~ s/\(.*\)//g;
    $word =~ s/^\%//;
    next if($word =~ /^\'|^\-|^$|^\(|^\)|^\*/);
    # Check for spurious prons: quick & dirty!
    my @w = split(//, $word);
    my @p = split(/ /, $pron);
    next if (scalar(@p)<=5 && scalar(@w)>scalar(@p)+5);
    print "$word\t$pron\n";
}
close $L;

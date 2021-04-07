#!/usr/bin/env perl
use strict;
use warnings;
use Carp;

BEGIN {
    @ARGV == 1 or croak "USAGE: map_phones.pl PHONELIST
for example:
$0 phones.txt
";
}

my ($phone_list) = @ARGV;

while ( my $line = <> ) {
  chomp $line;
  my @phones = split /\s/, $line;
  foreach my $phone ( @phones ) {
    $phone =~ s/\"//;
    $phone =~ s/\.//;
    $phone =~ s/\?\`/e/;
    $phone =~ s/\?/gs/;
    $phone =~ s/t\`/tt/;
    $phone =~ s/D\`/zz/;
        $phone =~ s/D/th/;
    $phone =~ s/G/g/;
    $phone =~ s/S\`/ss/;

    $phone =~ s/S/sh/;
    $phone =~ s/T/t/;
    $phone =~ s/X\\/hh/;
    $phone =~ s/Z/j/;
    $phone =~ s/a\:/ae/;
    $phone =~ s/d\`/dh/;
    $phone =~ s/i\:/iy/;
    $phone =~ s/j/y/;
                $phone =~ s/s\`/ss/;
    $phone =~ s/t\`/tt/;
    $phone =~ s/u\:/uu/;
    print "$phone ";
  }
  print "\n";
}

#!/usr/bin/env perl

# Copyright 2019 John Morgan
# Apache 2.0.

# make_lists_train_twoway_san_diego.pl - Get text for LM training.
# writes files under data/local/tmp/transtac/train/twoway/san_diego/2006/lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;
use Encode;
use utf8;
binmode STDOUT, 'utf8';

# Initialize variables
my $tmpdir = "data/local/tmp/transtac/train/twoway/san_diego/2006";
my $transcripts_file = "$tmpdir/tdf_files.txt";
# output temporary text file
my $txt_out = "$tmpdir/lists/text";
my $sample_rate = 16000;
my $data_word_size = 4;
# done setting variables

system "mkdir -p $tmpdir/lists";
open my $TR, '<', $transcripts_file or croak "problem with $transcripts_file $!";
open my $TXT, '+>:utf8', $txt_out or croak "problem with $txt_out $!";

while ( my $line = <$TR> ) {
  chomp $line;
  open my $TDF, '<', $line or croak "Problems with $line $!";
  RECORD:  while ( my $rec_info = <$TDF> ) {
    chomp $rec_info;

    # skip header that starts with the word file 
    next RECORD if ( $rec_info =~ /^file/ );
    my ($file,$channel,$start,$end,$speaker,$speakerType,$speakerDialect,$transcript,$section,$turn,$segment,$sectionType,$suType,$speakerRole) = split /\t/, $rec_info, 14;
    $transcript = decode_utf8 $transcript;
    # skip unless some character is Arabic
    next RECORD if ( $transcript !~ /\p{Arabic}/ );
    # map white space to dummy
    $transcript =~ s/\s+/اااا/g;
    # map everything that is not Arabic to <UNK>
    $transcript =~ s/\P{ARABIC}/<UNK>/g;
    # map the dummy back to space
    $transcript =~ s/اااا/ /g;
    # put space around <UNK>
        $transcript =~ s/<UNK>/ <UNK> /g;
    # remove arabic punctuation
    $transcript =~ s/؟/ /g;
    # squeeze
    $transcript =~ s/\s+/ /g;
    $transcript =~ s/\s+$//g;
    $transcript =~ s/^\s+//g;
    $transcript =~ s/(<UNK)+/$1/g;
    # the file names in the tdf files do not have the _a and _b suffixes
    my $base = basename $file, ".wav";
    my $utt_id = $speakerRole . '-' . $base . $start . '-' . $end;
  next LINE if ( $end <= $start );
  next LINE unless ( defined $file );
  my $base_without_suffix = basename $file, ".wav";
  my $rec_id = $base_without_suffix;
  my $spk = $speakerRole;
  print $TXT "$transcript\n";
  }
  close $TDF;
}
close $TR;
close $TXT;

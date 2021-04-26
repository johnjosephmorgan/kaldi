#!/usr/bin/env perl

# devtest_anwar_answers_make_lists.pl - make acoustic model training lists

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;

BEGIN {
  @ARGV == 3 or croak "USAGE $0 <TRANSCRIPT_FILENAME> <SPEAKER_NAME> <COUNTRY>
example:
$0 Tunisian_MSA/data/transcripts/devtest/anwar_answers.tsv anwar libyan
";
}

my ($transcript,$spk,$lang) = @ARGV;

open my $TRANSCRIPT, '<', $transcript or croak "problems with $transcript $!";

my $tmp_dir = "data/local/tmp/$lang/$spk";

# input wav file list
my $wav_list = "$tmp_dir/wav.txt";
croak "$! $wav_list" unless ( -f $wav_list );
# output temporary wav.scp files
my $wav_scp = "$tmp_dir/wav.scp";

# output temporary utt2spk files
my $uttspk = "$tmp_dir/utt2spk";

# output temporary text files
my $txt = "$tmp_dir/text";

# initialize hash for prompts
my %prompts = ();

# store prompts in hash
LINEA: while ( my $line = <$TRANSCRIPT> ) {
    chomp $line;
    my ($idx,$sent) = split /\t/, $line, 2;
    $prompts{$idx} = $sent;
}

open my $WAVLIST, '<', $wav_list or croak "problem with $wav_list $!";
open my $WAVSCP, '+>', $wav_scp or croak "problem with $wav_scp $!";
open my $UTTSPK, '+>', $uttspk or croak "problem with $uttspk $!";
open my $TXT, '+>', $txt or croak "problem with $txt $!";

 LINE: while ( my $line = <$WAVLIST> ) {
     chomp $line;
     next LINE if ($line =~ /recordings/ );
     next LINE unless ( $line =~ /Answers/ );
     my ($volume,$directories,$file) = File::Spec->splitpath( $line );
     my @dirs = split /\//, $directories;
     my $base = basename $line, ".wav";
     my $speaker = $dirs[-1];
     my $rec_id = $speaker . '_' . 'answers' . '_' . $base;
     my $utt_id = $speaker . '_' . 'recording';
     if ( exists $prompts{$base} ) {
	 print $TXT "$rec_id\t$prompts{$base}\n";
     } elsif ( defined $speaker ) {
	 warn  "problem\t$speaker";
	 next LINE;
     } else {
	 croak "$line";
     }

     print $WAVSCP "$rec_id sox $line -t wav - |\n";
	print $UTTSPK "$rec_id\t$utt_id\n";
}
close $TXT;
close $WAVSCP;
close $UTTSPK;
close $WAVLIST;

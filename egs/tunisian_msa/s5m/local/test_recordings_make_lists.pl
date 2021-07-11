#!/usr/bin/env perl

# Copyright 2018 John Morgan
# Apache 2.0.

# test_recordings_make_lists.pl - make standard kaldi directory

use strict;
use warnings;
use Carp;

use File::Spec;
use File::Copy;
use File::Basename;

BEGIN {
    @ARGV == 3 or croak "USAGE $0 <TRANSCRIPT_FILENAME> <SPEAKER_NAME> <COUNTRY>
example:
$0 Libyan_msa_arl/srj/data/transcripts/recordings/srj_recordings.tsv srj libyan
";
}

my ($transcripts,$spk,$l) = @ARGV;

open my $TRANS, '<', $transcripts or warn "problems with $transcripts";

my $datadir = "data/$spk";

system "mkdir -p $datadir";

# input wav file list
my $in_wav_list = "$datadir/recordings_wav.txt";

# output wav.scp files
my $out_wav_scp = "$datadir/wav.scp";

# output utt2spk files
my $out_utt_to_spk = "$datadir/utt2spk";

# output text files
my $out_text = "$datadir/text";

# initialize hash for prompts
my %prompts = ();

# store prompts in hash<
LINEA: while ( my $line = <$TRANS> ) {
    chomp $line;
    my ($s,$sent) = split /\t/, $line, 2;
    $prompts{$s} = $sent;
}
close $TRANS;

open my $WLST, '<', $in_wav_list or croak "problem with $in_wav_list $!";
open my $WAVSCP, '+>', $out_wav_scp or croak "problem with $out_wav_scp $!";
open my $UTTSPK, '+>', $out_utt_to_spk or croak "problem with $out_utt_to_spk $!";
open my $TXT, '+>', $out_text or croak "problem with $out_text $!";

LINE: while ( my $line = <$WLST> ) {
    chomp $line;
    # skip answer;
    next LINE if ($line =~ /answers/ );
    # only process recordings
    next LINE unless ( $line =~ /recordings/ );
    my ($volume,$directories,$file) = File::Spec->splitpath( $line );
    my @dirs = split /\//, $directories;
    my $base = basename $line, ".wav";
    my ($spk_id,$rec_id) = split /\_/, $base, 2;
    my $spk = $dirs[-1];
    my $rid = $spk_id . '_' . $rec_id;
    if ( exists $prompts{$base} ) {
	 print $TXT "$rid\t$prompts{$base}\n";
     } elsif ( defined $rid ) {
	 warn  "problem\t$rid";
	 next LINE;
     } else {
	 croak "$line";
     }

     print $WAVSCP "$rid sox $line -t wav - |\n";
	print $UTTSPK "$rid\t${spk_id}_r\n";
}
close $TXT;
close $WAVSCP;
close $UTTSPK;

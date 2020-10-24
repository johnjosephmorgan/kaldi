#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
from collections import defaultdict
import itertools


class Segment:
    def __init__(self, fields):
        self.partition = fields[0]
        self.file_id = fields[1]
        self.start_time = float(fields[2])
        self.end_time = float(fields[3])
        self.dur = self.end_time - self.start_time
        self.sad_label = fields[4]
        self.sad_provenance = fields[5]
        self.speaker_id = fields[6]
        self.sid_provenance = fields[7]
        self.language_id = fields[8]
        self.lid_provenance = fields[9]
        self.transcript = fields[10]
        self.transcript_provenance = fields[11]


def groupby(iterable, keyfunc):
    """Wrapper around ``itertools.groupby`` which sorts data first."""
    iterable = sorted(iterable, key=keyfunc)
    for key, group in itertools.groupby(iterable, keyfunc):
        yield key, group

def find_audios(data, fold):
    # Get all flac file names from audio directory
    wav_path = Path(data)
    if wav_path[-4] == fold:
        wav_list = wav_path.rglob('*.flac')
        return wav_list

def find_rec_info(info_dir):
    # Get all tab file names from data directory
    info_path = Path(info_dir)
    info_file_list = info_path.rglob('*.tab')
    segments = []
    for info_file in info_file_list:
        file_path = Path(info_file)
        with open(str(file_path), 'r') as f:
            for line in f.readlines():
                fields = line.strip().split()
                segments.append(Segment(fields))

    return segments

def write_wavscp(wav_list, fold):
    out_dir = Path('data' / fold / 'wav.scp')
    with open(out_dir, 'w') as f:
        for wav_file in wav_list:
            wav_path = Path(wav_file)
            rec_id = wav_path.stem
            f.write('%s sox %s -t wav - remix 1 | \n' % (rec_id, wav_file))

def write_output(segments):
    rttm_str = "SPEAKER {0} 1 {1:7.3f} {2:7.3f} <NA> <NA> {3} <NA> <NA>\n"
    with open('rttm.annotation','w') as rttm_writer:
        for seg in segments:
                if seg.dur >= 0.025:
                    rttm_writer.write(rttm_str.format(seg.file_id, seg.start_time, seg.dur, spk_id))

                    
if __name__ == "__main__":
    parser=argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,                
        fromfile_prefix_chars='@',
        description='Prepare RATS_SAD for speech activity detection.')

    parser.add_argument('partition', help="Partition, train, dev or eval")
    parser.add_argument('data', help="Location of data.")
    args=parser.parse_args()

    audios_list = find_audios(args.data, args.partition)
    segments = find_rec_info(args.data, args.partition)
    make_sad_data(audios_list, segments)

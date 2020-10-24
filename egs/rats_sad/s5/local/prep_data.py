#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
from collections import defaultdict
import itertools


class Segment:
    def __init__(self, fields):
        self.fold_id = fields[0]
        self.reco_id = fields[1]
        self.start_time = float(fields[2])
        self.end_time = float(fields[3])
        self.dur = self.end_time - self.start_time
        self.sad_label = fields[4]
        self.lng = fields[6]

def groupby(iterable, keyfunc):
    """Wrapper around ``itertools.groupby`` which sorts data first."""
    iterable = sorted(iterable, key=keyfunc)
    for key, group in itertools.groupby(iterable, keyfunc):
        yield key, group

def find_audios(wav_dir):
    # Get all flac file names from audio directory
    wav_path = Path(wav_dir)
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

def write_wavscp(wav_list):
    with open('/wav.scp', 'w') as f:
        for wav_file in wav_list:
            wav_path = Path(wav_file)
            rec_id = wav_path.stem
            f.write('%s sox %s -t wav - remix 1 | \n' % (rec_id, wav_file))


def write_output(segments):
    reco_and_spk_to_segs = defaultdict(list,
        {uid : list(g) for uid, g in groupby(segments, lambda x: (x.reco_id,x.spk_id))})
    rttm_str = "SPEAKER {0} 1 {1:7.3f} {2:7.3f} <NA> <NA> {3} <NA> <NA>\n"
    with open('/rttm.annotation','w') as rttm_writer:
        for uid in sorted(reco_and_spk_to_segs):
            segs = sorted(reco_and_spk_to_segs[uid], key=lambda x: x.start_time)
            reco_id, spk_id = uid

            for seg in segs:
                if seg.dur >= min_length:
                    rttm_writer.write(rttm_str.format(reco_id, seg.start_time, seg.dur, spk_id))

def make_sad_data(audios, segments):
    reco_to_segs = defaultdict(list,
        {reco_id : list(g) for reco_id, g in groupby(segments, lambda x: x.reco_id)})

    write_wavscp(audios)

if __name__ == "__main__":
    parser=argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,                
        fromfile_prefix_chars='@',
        description='Prepare RATS_SAD for speech activity detection.')

    parser.add_argument('data', help="Path to data directory directory")
    args=parser.parse_args()

    audios_list = find_audios(args.data)
    segments = find_rec_info(args.data)
    make_sad_data(audios_list, segments)

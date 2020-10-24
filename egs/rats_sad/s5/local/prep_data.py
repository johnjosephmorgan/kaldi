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
    exit()
    wavs = subprocess.check_output(command, shell=True).decode('utf-8').splitlines()
    keys = [ os.path.splitext(os.path.basename(wav))[0] for wav in wavs ]
    data = {'key': keys, 'file_path': wavs}
    df_wav = pd.DataFrame(data)

    # Filter list to keep only those in annotations (for the specific data split)
    file_names_str = "|".join(file_list)
    df_wav = df_wav.loc[df_wav['key'].str.contains(file_names_str)].sort_values('key')
    return df_wav
def read_annotations(file_path):
    segments = []
    with open(file_path, 'r') as f:
        for line in f.readlines():
            fields = line.strip().split()
            segments.append(Segment(fields))
    return segments

def make_sad_data(annotations_path, output_path):
    if not os.path.exists(output_path):
        os.makedirs(output_path)

    print ('read annotations to get segments')
    segments = read_annotations(annotations_path)
    print('segments', segments)
    reco_to_segs = defaultdict(list,
        {reco_id : list(g) for reco_id, g in groupby(segments, lambda x: x.reco_id)})
    file_list = list(reco_to_segs.keys())

if __name__ == "__main__":
    parser=argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,                
        fromfile_prefix_chars='@',
        description='Prepare RATS_SAD for speech activity detection.')

    parser.add_argument('annotations', help="Path to annotations directory")
    parser.add_argument('output', help="Path to output directory directory")
    parser.add_argument('data', help="Path to data directory directory")
    args=parser.parse_args()

    find_audios(data)
    make_sad_data(args.annotations, args.output)

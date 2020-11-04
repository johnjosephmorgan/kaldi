#! /usr/bin/env python3
# Copyright   2020   Desh Raj# Copyright   2020   John Morgan
# Apache 2.0.

"""
This script takes as input an RTTM. 
The output is written to stdout.
"""

import argparse, os
import itertools
from collections import defaultdict

def get_args():
    parser = argparse.ArgumentParser(
        description="""This script filters an RTTM in several ways.""",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--label", type=str, default="speech",
                        help="Label for the speech segments")
    parser.add_argument("input_rttm", type=str,
                        help="path of input rttm file")
    args = parser.parse_args()
    return args

class Segment:
    """Stores all information about a segment"""

    def __init__(self, reco_id, start_time, dur = None, end_time = None, spk_id = None):
        self.reco_id = reco_id
        self.start_time = start_time
        if (dur is None):
            self.end_time = end_time
            self.dur = end_time - start_time
        else:
            self.dur = dur
            self.end_time = start_time + dur
        self.spk_id = spk_id

def groupby(iterable, keyfunc):
    """Wrapper around ``itertools.groupby`` which sorts data first."""
    iterable = sorted(iterable, key=keyfunc)
    for key, group in itertools.groupby(iterable, keyfunc):
        yield key, group


def find_speech_segments(segs):
    reco_id = segs[0].reco_id
    tokens = []
    for seg in segs:
        tokens.append(("BEG", seg.start_time, seg.spk_id))
        tokens.append(("END", seg.end_time, seg.spk_id))
    sorted_tokens = sorted(tokens, key=lambda x: x[1])
    
    single_speaker_segs = []
    running_spkrs = set()
    for token in sorted_tokens:
        if (token[0] == "BEG"):
            running_spkrs.add(token[2])
            if (len(running_spkrs) == 1):
                seg_begin = token[1]
                cur_spkr = token[2]
            elif (len(running_spkrs) == 2):
                single_speaker_segs.append(Segment(reco_id, seg_begin, end_time=token[1], spk_id=cur_spkr))
        elif (token[0] == "END"):
            try:
                running_spkrs.remove(token[2])
            except:
                Warning ("Speaker not found")
            if (len(running_spkrs) == 1):
                seg_begin = token[1]
                cur_spkr = list(running_spkrs)[0]
            elif (len(running_spkrs) == 0):
                single_speaker_segs.append(Segment(reco_id, seg_begin, end_time=token[1], spk_id=cur_spkr))
    
    return single_speaker_segs

def main():
    args = get_args()

    # Read all segments and store as a list of objects
    segments = []
    with open(args.input_rttm, 'r') as f:
        for line in f.readlines():
            fields = line.strip().split()
            segments.append(Segment(fields[1], float(fieldss[3]), dur=float(fields[4]), spk_id=fields[7]))

    # Group the segment list into a dictionary indexed by reco_id
    reco2segs = defaultdict(list,
        {reco_id : list(g) for reco_id, g in groupby(segments, lambda x: x.reco_id)})

    speech_segs = []
    for reco_id in reco2segs.keys():
        segs = reco2segs[reco_id]
        speech_segs.extend(find_speech_segments(segs))
    final_segs = sorted(speech_segs, key = lambda x: (x.reco_id, x.start_time))
    rttm_str = "SPEAKER {0} 1 {1:7.5f} {2:7.5f} <NA> <NA> {3} <NA> <NA>"
    for seg in final_segs:
        if (seg.dur > 0):
            print(rttm_str.format(seg.reco_id, seg.start_time, seg.dur, seg.spk_id))


if __name__ == '__main__':
    main()

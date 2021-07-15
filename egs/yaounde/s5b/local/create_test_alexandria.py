''' This script will create test_alexandria files :
text, utt2spk and wav.scp for kaldi /yaounde
Version = 1.02
'''
''' 
keyword argument:- 
path = Path to Data Directory
file = Transcription Text file name including file extension

Usage :
python create_test_alexandria.py --path Data directory path --file Transcription file
Or
python create_test_alexandria.py --h for help
'''

'''
This script will create the files inside data directory 
and must run it from s5b directory terminal
'''

import os
import csv
import string
import argparse

### global variables ###

spkrs = [] # list for speakers
line_text = [] # list for Transcription text content without line numbers
line_numbers = [] # list for transcription line numbers only without the text
text_content = [] # list includes the content for text output file
wav_scp = [] # list includes the content for wav.scp file
utt2spk = [] # list includes the content for utt2spk  file
    
''' This function reads transcription text file with UTF-8-BOM encoding'''
def read_file(file):
    with open (file, 'r', encoding="utf-8-sig") as test_read: #opening the transcription file
        content = test_read.readlines()
        return list(content)
    
''' This function appends lines to text_content 
to be used in output file "text" 
'''
def add_text(utterrance_id, utterrance_index): 
    text_content.append(utterrance_id + " " + line_text[utterrance_index])

''' This function appends lines ro wav_scp list to be used in wav.scp
including adding sox command '''
def new_wav_scp(utterrance_id, dir_path, file_name): 
    wav_scp_command = "sox -r 22050 -e signed -b 16 " + dir_path + file_name + " -r 16000 -t wav - |" # sox command 
    wav_scp_line = utterrance_id + " " + wav_scp_command 
    wav_scp.append(wav_scp_line)

'''This function appends lines to utt2spk list 
to be used in utt2spk file
'''
def new_utt2spk(utterrance_id, speaker): 
    utt2spk.append(utterrance_id + " " + speaker)

''' This function create the three requested files:
text, utt2spk and wav.scp for kaldi /yaounde 
and save them in s5b/data/test_alexandria
if data directory does not exist the function will create it
if any of the three files already exist in test_alexandria directory 
the function will skip the file and won't create or append to it
'''   
def create_kaldi_test(data_dir, transcript_path, file_name):
    text_file = transcript_path + "/" + file_name # transcription file name and path
    testing = read_file(text_file) # reading transcrtiption content
    for item in testing: # iterate through transcription content lines
        split_on_tab = item.split('\t')
        line1 = split_on_tab[0].rstrip("\n")
        line2 = split_on_tab[1].rstrip("\n")
        line_numbers.append(line1) # first column in transcroption file
        line_text.append(line2) # second column in transcroption file
        split_on_tab.clear() 
    dir_path = data_dir + "/" # adding "/" to data directory  
    dir_contents = os.listdir(dir_path)
    data_folder = "./data"
    test_folder = data_folder + "/" + "test_alexandria"
    if not os.path.exists(data_folder):
        os.mkdir(data_folder)
    if not os.path.exists(test_folder):
        os.mkdir(test_folder)
    
    new_text_file = test_folder + "/text"
    new_utt2spk_file = test_folder + "/utt2spk"
    new_wav_scp_file = test_folder + "/wav.scp"
    
    for item in dir_contents: # iterate through each file and directory
        path = dir_path + item
        if os.path.isdir(path): # checking the item is directory not file
            spkrs.append(item) # append to speakers list

    for item in spkrs:  # iterate through each speaker
        spkr_path = dir_path + item
        spkr_content = os.listdir(spkr_path)
        for f in spkr_content: # iterate through each speaker directory
                try:
                    utterrance_id = f[:-4] 
                    utterrance_index = line_numbers.index(f.strip(item + "_")[:-4])
                    wav_scp_command = "sox -r 22050 -e signed -b 16 " + dir_path + f + " -r 16000 -t wav - |"
                    add_text(utterrance_id, utterrance_index)
                    new_wav_scp(utterrance_id, dir_path, f)
                    new_utt2spk(utterrance_id, item)
                except IndexError:
                    print (f"couln't match speaker {item} for wav file {f} with text")
                
    try:
        with open (new_text_file, 'x', newline='', encoding='utf-8') as test_file:
            test_file.write('\n'.join(text_content))
            test_file.write('\n')
    except FileExistsError:
        print (f'file{new_text_file} already exist, will not create this file')
        
    try:
        with open (new_wav_scp_file, 'x', newline='', encoding='utf-8') as wscp:
            wscp.write('\n'.join(wav_scp))
            wscp.write('\n')
    except FileExistsError:
        print (f'file{new_wav_scp_file} already exist, will not create this file')
        
    try:
        with open (new_utt2spk_file, 'x', newline='', encoding='utf-8') as ut2sp:
            ut2sp.write('\n'.join(utt2spk))
            ut2sp.write('\n')
    except FileExistsError:
        print (f'file{new_utt2spk_file} already exist, will not create this file')

if __name__=='__main__':
    default_path = "/mnt/corpora/ARTI_Cameroon_242_fr"
    default_transcript = "Recordings_French_utf8.txt"
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--path', default=default_path, help='Path to Data Directory if not stated will use default', required=False)
    parser.add_argument('--tpath', default=default_path, help='Transcription Text file path if not stated will use default', required=False)
    parser.add_argument('--file', default=default_transcript, help='Transcription Text file name including file extension if not stated will use default', required=False)
    parser.add_argument('-h', '--help', action='help', default=argparse.SUPPRESS, 
                       help='Usage example (default) : python3 create_test_alexandria.py --path /mnt/corpora/ARTI_Cameroon_242_fr --tpath /mnt/corpora/ARTI_Cameroon_242 --file Recordings_French_utf8.txt'
                       )
    
    args=parser.parse_args()
    path = args.path
    tpath = args.tpath
    file = args.file
    create_kaldi_test(path, tpath, file)

''' This script will create test_alexandria files :
text, utt2spk and wav.scp for kaldi /yaounde
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
linetext = [] # list for Transcription text content without line numbers
linenumbers = [] # list for transcription line numbers only without the text
textcontent = [] # list includes the content for text output file
wavscp = [] # list includes the content for wav.scp file
utt2spk = [] # list includes the content for utt2spk  file
    
''' This function reads transcription text file with UTF-8-BOM encoding'''
def readfile(file):
    with open (file, 'r', encoding="utf-8-sig") as test_read: #opening the transcription file
        content = test_read.readlines()
        return list(content)
    
''' This function appends lines to textcontent 
to be used in output file "text" 
'''
def addtext(uterranceid, uterranceindex): 
    textcontent.append(uterranceid + " " + linetext[uterranceindex])

''' This function appends lines ro wavscp list to be used in wav.scp
including adding sox command '''
def newwavscp(uterranceid, dirpath, filename): 
    wavscpcommand = "sox -r 22050 -e signed -b 16 " + dirpath + filename + " -r 16000 -t wav - |" # sox command 
    wavscpline = uterranceid + " " + wavscpcommand 
    wavscp.append(wavscpline)

'''This function appends lines to utt2spk list 
to be used in utt2spk file
'''
def newutt2spk(uterranceid, speaker): #
    utt2spk.append(uterranceid + " " + speaker)

''' This function create the three requested files:
text, utt2spk and wav.scp for kaldi /yaounde 
and save them in s5b/data/test_alexandria
if data directory does not exist the function will create it
if any of the three files already exist in test_alexandria directory 
the function will skip the file and won't create or append to it
'''   
def createkalditest(datadir, filename):
    textfile = datadir + "/" + filename # transcription file name and path
    testing = readfile(textfile) # reading transcription content
    for item in testing: # iterate through transcription content lines
        splitontab = item.split('\t')
        line1 = splitontab[0].rstrip("\n")
        line2 = splitontab[1].rstrip("\n")
        linenumbers.append(line1) # first column in transcription file
        linetext.append(line2) # second column in transcription file
        splitontab.clear() 
    dirpath = datadir + "/" # adding "/" to data directory  
    dir_contents = os.listdir(dirpath)
    datafolder = "./data"
    testfolder = datafolder + "/" + "test_alexandria"
    if not os.path.exists(datafolder):
        os.mkdir(datafolder)
    if not os.path.exists(testfolder):
        os.mkdir(testfolder)
    
    newtextfile = testfolder + "/text"
    newutt2spkfile = testfolder + "/utt2spk"
    newwavscpfile = testfolder + "/wav.scp"
    
    for item in dir_contents: # iterate through each file and directory
        path = dirpath+item
        if os.path.isdir(path): # checking the item is directory not file
            spkrs.append(item) # append to speakers list

    for item in spkrs:  # iterate through each speaker
        spkrpath = dirpath + item
        spkr_content = os.listdir(spkrpath)
        for f in spkr_content: # iterate through each speaker directory
                try:
                    uterranceid = f[:-4] 
                    uterranceindex = linenumbers.index(f.strip(item + "_")[:-4])
                    wavscpcommand = "sox -r 22050 -e signed -b 16 " + dirpath + f + " -r 16000 -t wav - |"
                    addtext(uterranceid, uterranceindex)
                    newwavscp(uterranceid, dirpath, f)
                    newutt2spk(uterranceid, item)
                except IndexError:
                    print (f"couln't match speaker {speakername} for wav file {filename} with text")
                
    try:
        with open (newtextfile, 'x', newline='', encoding='utf-8') as testfile:
            testfile.write('\n'.join(textcontent))
    except FileExistsError:
        print (f'file{newtextfile} already exist, will not create this file')
        
    try:
        with open (newwavscpfile, 'x', newline='', encoding='utf-8') as wscp:
            wscp.write('\n'.join(wavscp))
    except FileExistsError:
        print (f'file{newwavscpfile} already exist, will not create this file')
        
    try:
        with open (newutt2spkfile, 'x', newline='', encoding='utf-8') as ut2sp:
            ut2sp.write('\n'.join(utt2spk))
    except FileExistsError:
        print (f'file{newutt2spkfile} already exist, will not create this file')

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', help='Path to Data Directory ', required=True)
    parser.add_argument('--file', help='Transcription Text file name including file extension', required=True)
    args=parser.parse_args()
    path = args.path
    file = args.file
    createkalditest(path, file)

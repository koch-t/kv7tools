from gzip import GzipFile
import sys
import os
import codecs
from datetime import datetime,timedelta

output = codecs.open('kv7kalender.idx', 'w', 'UTF-8')

lastupdated_filenames = {}

kalender_filenames = [sys.argv[1] + '/' + x for x in os.listdir(sys.argv[1])]
kalender_threshold = (datetime.now() - timedelta(days=3)).isoformat()

for filename in sorted(kalender_filenames):
    with GzipFile(filename, 'r') as f:
        firstline = f.readline()[:-1]
        values = firstline.split('|')
        subscription = values[2]
        creationdate = values[7]
        if (creationdate < kalender_threshold):
            continue
        if subscription not in lastupdated_filenames:
            lastupdated_filenames[subscription] = {'filename' : filename, 'creationdate' : creationdate}
        elif creationdate > lastupdated_filenames[subscription]['creationdate']:
            lastupdated_filenames[subscription] = {'filename' : filename, 'creationdate' : creationdate}

for key, values in lastupdated_filenames.items():
        print key + ' - ' + values['filename']
        output.write(values['filename']+'\n')

output.close()

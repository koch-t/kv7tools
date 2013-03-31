from gzip import GzipFile
import sys
import os
import codecs

output = codecs.open('kv7kalender.idx', 'w', 'UTF-8')

files = []

lastupdated_filenames = {}

for dirs in sys.argv[1:]:
    files += [dirs + '/' + x for x in os.listdir(dirs)]

for filename in sorted(files):
    data = GzipFile(filename, 'r').read()
    firstline = data.split('\n', 1)[0]
    values = firstline.split('|')
    subscription = values[2]
    creationdate = values[7]
    if subscription not in lastupdated_filenames:
        lastupdated_filenames[subscription] = {'filename' : filename, 'creationdate' : creationdate}
    elif creationdate > lastupdated_filenames[subscription]['creationdate']:
        lastupdated_filenames[subscription] = {'filename' : filename, 'creationdate' : creationdate}

for keys, values in lastupdated_filenames.items():
        print keys
        output.write(values['filename']+'\n')

output.close()


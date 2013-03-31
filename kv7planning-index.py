from gzip import GzipFile
import sys
import os
import codecs

table = None

dumping = False
knownfiles = set([])

try:
    with codecs.open('kv7planning.idx', 'r', 'UTF-8') as output:
        old = output.read()
        for x in old.split('\n'):
                knownfiles.add(sys.argv[1] + '/' + x.split('|')[-1])
except:
    old = ''

files = []
for dirs in sys.argv[1:]:
    files += [dirs + '/' + x for x in os.listdir(dirs)]

files = set(files) - (knownfiles)

output = codecs.open('kv7planning.idx', 'w', 'UTF-8')
output.write(old)

for filename in sorted(files):
    localservicelevelcodes = set([])

    for line in GzipFile(filename, 'r'):
        if line[0] == '\\':
            if dumping:
                dumping = False

            if table == 'LOCALSERVICEGROUPPASSTIME' and line[1] == 'L':
                dumping = True

            elif line[1] == 'T':
                table = line[2:].split('|')[0]

        else:
            if dumping:
                line = line.decode('UTF-8').split('|')
                localservicelevelcodes.add(line[0] + "|" + line[1])

    for x in localservicelevelcodes:
        output.write(x + "|" + os.path.basename(filename) + '\n')

output.close()

from gzip import GzipFile
import sys
import os
import codecs

table = None

dumping = False
network = False
networkfiles = {}

planningout = codecs.open('kv7planning.idx', 'r', 'UTF-8')
planningold = planningout.read()

knownfiles = set([])
for x in planningold.split('\n'):
    try:
         knownfiles.add(sys.argv[1] + '/' + x.split('|')[-1])
    except:
         pass

planningout.close()

files = []
for dirs in sys.argv[1:]:
    files += [dirs + '/' + x for x in os.listdir(dirs)]

files = set(files) - (knownfiles)
files = list(files)
files.sort()

planningout = codecs.open('kv7planning.idx', 'w', 'UTF-8')
planningout.write(planningold)

networkout = codecs.open('kv7network.idx', 'a', 'UTF-8')

for filename in files:
    localservicelevelcodes = set([])
    network = False
    for line in GzipFile(filename, 'r'):
        if line[0] == '\\':
            if line[1] == 'G':
                network = line.split('|')[1] == 'KV7turbo_network'
            if dumping:
                dumping = False

            if table == 'LOCALSERVICEGROUPPASSTIME' and line[1] == 'L' and not network:
                dumping = True
            if table == 'LINE' and line[1] == 'L' and network:
                dumping = True

            elif line[1] == 'T':
                table = line[2:].split('|')[0]

        else:
            if dumping and not network:
                line = line.decode('UTF-8').split('|')
                localservicelevelcodes.add(line[0] + "|" + line[1])
            if dumping and network:
                line = line.decode('UTF-8').split('|')
		networkfiles[line[0] + "|" + line[1]] = os.path.basename(filename)

    for x in localservicelevelcodes:
        planningout.write(x + "|" + os.path.basename(filename) + '\n')

for key, value in networkfiles.items():
    networkout.write(key + "|" + value + '\n')

planningout.close()
networkout.close()

from gzip import GzipFile
import sys
import os
import codecs
from datetime import datetime,timedelta

lastupdated_filenames = {}

kalender_filenames = [sys.argv[1] + '/' + x for x in os.listdir(sys.argv[1])]
kalender_threshold = (datetime.now() - timedelta(days=3)).isoformat()

for filename in kalender_filenames:
    with GzipFile(filename, 'r') as f:
        data = GzipFile(filename, 'r')
        firstline = GzipFile(filename, 'r').readline()[2:-1]
        values = firstline.split('|')
        if values[0] != 'KV7turbo_calendar':
            raise Exception('Dit is geen KV7kalender')
        subscription = values[2]
        timestamp = values[7]
        if (timestamp < kalender_threshold):
            continue
        if subscription not in lastupdated_filenames:
            lastupdated_filenames[subscription] = {'filename' : filename, 'timestamp' : timestamp}
        elif timestamp > lastupdated_filenames[subscription]['timestamp']:
            lastupdated_filenames[subscription] = {'filename' : filename, 'timestamp' : timestamp}


required_kalender = set(x['filename'] for x in lastupdated_filenames.values())
required_localservicelevelcodes = set([])
for filename in kalender_filenames:
    if filename not in required_kalender:
       os.remove(filename)

for filename in required_kalender:
    with GzipFile(filename, 'r') as f:
        columns = None
        table = None
        dumping = False
        for line in f:
            line = line[:-2]
            if line[0] == '\\':
                dumping = False
                if line[1] == 'G':
                    subscription = line[2:-2].split('|')[2]
                elif line[1] == 'L':
                    columns = line[2:-2].split('|')
                elif line[1] == 'T':
                    table = line[2:].split('|')[0]
            elif table == 'LOCALSERVICEGROUP':
                values = line.split('|')
                required_localservicelevelcodes.add(line)

planning_filenames = [sys.argv[2] + '/' + x for x in os.listdir(sys.argv[2])]
required_planning = set([])

for filename in reversed(sorted(planning_filenames)):
    with GzipFile(filename, 'r') as f:
        sys.stdout.write('\r'+filename)
        sys.stdout.flush()
        columns = None
        table = None
        dumping = False
        lslcodes = set([])
        for line in f:
            line = line[:-2]
            if line[0] == '\\':
                dumping = False
                if line[1] == 'G':
                    subscription = line[2:-2].split('|')[2]
                elif line[1] == 'L':
                    columns = line[2:-2].split('|')
                elif line[1] == 'T':
                    table = line[2:].split('|')[0]
            elif table == 'LOCALSERVICEGROUPPASSTIME':
                values = line.split('|')
                lslcode = values[0]+'|'+values[1]
                lslcodes.add(values[0]+'|'+values[1])
        for lslcode in lslcodes:
            if lslcode in required_localservicelevelcodes:
                required_planning.add(filename)
                required_localservicelevelcodes.remove(lslcode)


for filename in planning_filenames:
    if filename not in required_planning:
        os.remove(filename)

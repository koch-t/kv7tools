from gzip import GzipFile
import sys
import os
import codecs

tables = {
    'LOCALSERVICEGROUP': ['DataOwnerCode', 'LocalServiceLevelCode'],
    'LOCALSERVICEGROUPVALIDITY': ['DataOwnerCode', 'LocalServiceLevelCode', 'OperationDate'],
    'LOCALSERVICEGROUPPASSTIME': ['DataOwnerCode', 'LocalServiceLevelCode', 'LinePlanningNumber', 'JourneyNumber', 'FortifyOrderNumber', 'UserStopCode', 'UserStopOrderNumber', 'LineDirection'],
    'TIMINGPOINT': ['DataOwnerCode', 'TimingPointCode'],
    'LINE': ['DataOwnerCode', 'LinePlanningNumber'],
    'DESTINATION': ['DataOwnerCode', 'DestinationCode'],
    'DESTINATIONVIA': ['DataOwnerCode', 'DestinationCodeP', 'DestinationCodeC'],
    'TIMINGPOINT': ['DataOwnerCode', 'TimingPointCode'],
    'USERTIMINGPOINT': ['DataOwnerCode', 'UserStopCode'],
    'DATAOWNER': ['DataOwnerCode'],
    'STOPAREA': ['DataOwnerCode', 'StopAreaCode'],
    'JOPATIMINGLINK': ['DataOwnerCode', 'LinePlanningNumber', 'JourneyPatternCode', 'TimingLinkOrder', 'ValidFrom'],
    'JOPATIMINGLINKPOOL': ['DataOwnerCode', 'LinePlanningNumber', 'JourneyPatternCode', 'TimingLinkOrder', 'ValidFrom', 'DistanceSinceStartOfLink'],
    'USERSTOP': ['DataOwnerCode', 'UserStopCode'],
}

requirements = set([])
subscriptions = {}
requirementsdate = set([])

output = codecs.open('kv7.sql', 'w', 'UTF-8')

first = True

kv7kalenderindex = open('kv7kalender.idx', 'r')
for filename in kv7kalenderindex:
    columns = None
    table = None
    dumping = False
    subscription = None
    for line in GzipFile(filename[:-1], 'r'):
        if line[0] == '\\':
            dumping = False
	    if line[1] == 'G':
	        subscription = line[2:-2].split('|')[2]
            elif line[1] == 'L' and table == 'LOCALSERVICEGROUPVALIDITY':
                columns = line[2:-2].split('|')
                if first:
                    output.write("COPY %(table)s (%(columns)s) FROM STDIN CSV DELIMITER '|' NULL AS '';\n" % {'columns': ', '.join(columns), 'table': table})
                    first = False
                dumping = True
            elif line[1] == 'T':
                table = line[2:].split('|')[0]

        elif dumping:
            line = line.decode('UTF-8')
            if line not in requirementsdate:
                dataownercode, localservicelevelcode, operationdate = line.split('|')
                subscriptions[dataownercode+'|'+localservicelevelcode] = subscription
                requirements.add(dataownercode+'|'+localservicelevelcode)
                requirementsdate.add(line)
                output.write(line[:-2].replace('\\0', '') + '\n')

                available = {}
kv7kalenderindex.close()

kv7planningindex = open('kv7planning.idx', 'r')
for line in kv7planningindex:
    dataownercode, localservicelevelcode, filename = line[:-1].split('|')
    key = dataownercode + "|" + localservicelevelcode
    if key in available:
        pass
        #available[key].append(filename)
    elif (dataownercode + '|' + localservicelevelcode) in requirements:
        available[key] = [filename]
kv7planningindex.close()

output.write('\\.\n')
use_files = set([])
incomplete_subscriptions = set([])

for x in requirements:
    try:
        for y in available[x]:
            use_files.add(y)
    except:
        print x + ' Subscription ' + subscriptions[x]
	incomplete_subscriptions.add(subscriptions[x])

print '----------------------------------------------------'
if len(incomplete_subscriptions) == 0:
    print 'All subscriptions complete'
else:
    print 'Incomplete: ' 
    for x in incomplete_subscriptions:
        print x

del(subscriptions)
print

kv7networkindex = open('kv7network.idx', 'r')
networkfiles = {}
for line in kv7networkindex:
    dataownercode, lineplanningnumber, filename = line[:-1].split('|')
    networkfiles[dataownercode+'|'+lineplanningnumber] = filename
kv7networkindex.close()

for key,filename in networkfiles.items():
    use_files.add(filename)

first = True
i = 0

memory = {}
memory_columns = {}


for filename in sorted(use_files, reverse=True):
    i += 1
    sys.stderr.write('\r%d/%d'%(i, len(use_files)))
    columns = None
    table = None
    dumping = False
    network = False
    done = set([])
    for line in GzipFile(sys.argv[2] + '/' + filename, 'r'):
        if line[0] == '\\':
            if line[1] == 'G':
                network = line.split('|')[1] == 'KV7turbo_network'
            elif line[1] == 'L':
                columns = line[2:-2].split('|')
                if table == 'LOCALSERVICEGROUPPASSTIME' and first:
                    output.write("COPY %(table)s (%(columns)s) FROM STDIN CSV DELIMITER '|' NULL AS '';\n" % {'columns': ', '.join(columns), 'table': table})
                    first = False
                elif not (network and table == 'DESTINATION'):
                    if table not in memory:
                        memory[table] = {}
                        memory_columns[table] = ', '.join(columns)
            elif line[1] == 'T':
                table = line[2:].split('|')[0]
        else:
            line = line.decode('UTF-8')
            if table == 'LOCALSERVICEGROUPPASSTIME':
                myline = line.split('|')
                key = myline[0]+"|"+myline[1]
                if key in requirements:
                    done.add(key)
                    output.write(line[:-2].replace('\\0', '') + '\n')
            elif not (network and table == 'DESTINATION'):
                mylines = line[:-2].split('|')
                key = '|'.join(mylines[0:len(tables[table])])
                if key not in memory[table]:
                    memory[table][key] = line[:-2].replace('\\0', '')
    requirements = requirements - done

output.write('\\.\n')

for table in memory.keys():
    output.write("COPY %(table)s (%(columns)s) FROM STDIN CSV DELIMITER '|' NULL AS '';\n" % {'columns': memory_columns[table], 'table': table})
    for line in memory[table].values():
        output.write(line)
        output.write('\n')
    output.write('\\.\n')

output.close()
sys.stderr.write('\nDone!\n')

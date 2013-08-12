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
}

requirements = set([])
subscriptions = {}
requirementsdate = set([])
usedUserstopCodes = set([])
usedTimingPoints = set([])
skipInfopoints = (len(sys.argv) == 4 and sys.argv[-1] == '--skipInfopoints')
if skipInfopoints:
    print 'Skipping Infopoints/dummies'

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

kv7planningindex = open('kv7planning.idx', 'r')
for line in kv7planningindex:
    dataownercode, localservicelevelcode, filename = line[:-1].split('|')
    key = dataownercode + "|" + localservicelevelcode
    if (dataownercode + '|' + localservicelevelcode) in requirements:
        available[key] = [filename]

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
first = True
i = 0

memory = {}
memory_columns = {}
usedUserStopCodes = set([])
usedTimingPointCodes = set([])

for filename in sorted(use_files, reverse=True):
    i += 1
    sys.stderr.write('\r%d/%d'%(i, len(use_files)))
    columns = None
    table = None
    dumping = False
    done = set([])
    for line in GzipFile(sys.argv[2] + '/' + filename, 'r'):
        if line[0] == '\\':
            if line[1] == 'L':
                columns = line[2:-2].split('|')
                if table == 'LOCALSERVICEGROUPPASSTIME' and first:
                    output.write("COPY %(table)s (%(columns)s) FROM STDIN CSV DELIMITER '|' NULL AS '';\n" % {'columns': ', '.join(columns), 'table': table})
                    first = False
                else:
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
                    if skipInfopoints and str(myline[14]) == 'INFOPOINT':
                        continue
                    output.write(line[:-2].replace('\\0', '').replace('\"','\"\"') + '\n')
                    usedUserstopCodes.add(str(myline[0])+'|'+str(myline[5]))
            else:
                mylines = line[:-2].split('|')
                key = '|'.join(mylines[0:len(tables[table])])
                if key not in memory[table]:
                    memory[table][key] = line[:-2].replace('\\0', '').replace('\"','\"\"')
    requirements = requirements - done

output.write('\\.\n')

if skipInfopoints:
    usedTimingPoints = set([])
    for key,line in memory['USERTIMINGPOINT'].items():
        values = line.split('|')
        if key not in usedUserstopCodes:
            del(memory['USERTIMINGPOINT'][key])
        else:
            usedTimingPoints.add(values[2]+'|'+values[3])
    for key,line in memory['TIMINGPOINT'].items():
        if key not in usedTimingPoints:
            del(memory['TIMINGPOINT'][key])

for table in memory.keys():
    output.write("COPY %(table)s (%(columns)s) FROM STDIN CSV DELIMITER '|' NULL AS '';\n" % {'columns': memory_columns[table], 'table': table})
    for line in memory[table].values():
        output.write(line)
        output.write('\n')
    output.write('\\.\n')

output.close()
sys.stderr.write('\nDone!\n')

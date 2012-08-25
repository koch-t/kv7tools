create table gtfs_route_type (transporttype varchar(5) primary key, route_type int4);
insert into gtfs_route_type values ('TRAM', 0);
insert into gtfs_route_type values ('METRO', 1);
insert into gtfs_route_type values ('TRAIN', 2);
insert into gtfs_route_type values ('BUS', 3);
insert into gtfs_route_type values ('BOAT', 4);

create table gtfs_wheelchair_accessibility (wheelchairaccessibility
varchar(13) primary key, wheelchair_accessible int4);
insert into gtfs_wheelchair_accessibility values ('UNKNOWN', 0);
insert into gtfs_wheelchair_accessibility values ('ACCESSIBLE', 1);
insert into gtfs_wheelchair_accessibility values ('NOTACCESSIBLE', 2);

create table dataownerurl (dataownercode varchar(10) primary key, agency_url varchar(50));
insert into dataownerurl values ('GVB', 'http://www.gvb.nl');
insert into dataownerurl values ('VTN', 'http://www.veolia.nl');
insert into dataownerurl values ('ARR', 'http://www.arriva.nl');
insert into dataownerurl values ('HTM', 'http://www.htm.nl');
insert into dataownerurl values ('CXX', 'http://www.connexxion.nl');
insert into dataownerurl values ('EBS', 'http://www.ebs-ov.nl');
insert into dataownerurl values ('SYNTUS', 'http://www.syntus.nl');
insert into dataownerurl values ('QBUZZ', 'http://www.qbuzz.nl');
insert into dataownerurl values ('NS', 'http://www.ns.nl');

copy (
SELECT 
d.dataownercode AS agency_id,
dataownername AS agency_name,
'http://'||dataownername||'.nl/' AS agency_url,
'Europe/Amsterdam' AS agency_timezone,
'nl' AS agency_lang
FROM dataowner as d,dataownerurl
WHERE d.dataownercode <> 'ALGEMEEN' and d.dataownercode = dataownerurl.dataownercode
)TO '/tmp/gtfs/agency.txt' WITH CSV HEADER;

copy (
SELECT
'OVapi' as feed_publisher_name,
'http://ovapi.nl/' as feed_publisher_url,
'nl' as feed_lang,
replace(cast(min(operationdate) AS text), '-', '') as feed_start_date,
replace(cast(max(operationdate) AS text), '-', '') as feed_end_date,
now() as feed_version
FROM localservicegroupvalidity
) TO '/tmp/gtfs/feed_info.txt' WITH CSV HEADER;

copy (
SELECT
dataownercode||'|'||localservicelevelcode as service_id,
replace(cast(operationdate as text), '-', '') as date,
'1' as exception_type 
FROM localservicegroupvalidity
) TO '/tmp/gtfs/calendar_dates.txt' WITH CSV HEADER;

copy (
SELECT
dataownercode||'|'||lineplanningnumber as route_id,
dataownercode as agency_id,
linepublicnumber as route_short_name,
CASE WHEN linepublicnumber <> linename THEN linename ELSE '' END as route_long_name,
g.route_type as route_type
FROM line as l, gtfs_route_type as g 
WHERE 
l.transporttype = g.transporttype
) TO '/tmp/gtfs/routes.txt' WITH CSV HEADER;

alter table timingpoint add column wheelchairaccessible VARCHAR(13);
update timingpoint set wheelchairaccessible = 'UNKNOWN' where wheelchairaccessible is null;

COPY (
SELECT * FROM (
SELECT 'sa_'||a.stopareacode AS stop_id, stopareaname AS stop_name,
       CAST(st_X(the_geom) AS NUMERIC(8,5)) AS stop_lon,
       CAST(st_Y(the_geom) AS NUMERIC(9,6)) AS stop_lat,
       1      AS location_type,
       NULL   AS parent_station,
       NULL   as wheelchair_boarding
FROM   (SELECT stopareacode,
               ST_Transform(st_setsrid(st_makepoint(AVG(locationx_ew), AVG(locationy_ns)), 28992), 4326) AS the_geom
        FROM   (SELECT stopareacode,
                       locationx_ew,
                       locationy_ns
                FROM   timingpoint
                WHERE  stopareacode <> '') AS x
        GROUP  BY stopareacode) AS y,
       stoparea AS a
WHERE y.stopareacode = a.stopareacode
UNION
SELECT 
stop_id,
stop_name,
CAST(st_X(the_geom) AS NUMERIC(8,5)) AS stop_lon,
CAST(st_Y(the_geom) AS NUMERIC(9,6)) AS stop_lat,
0 AS location_type, parent_station,
wheelchair_boarding
FROM (
	SELECT distinct t.timingpointcode as stop_id,
	t.timingpointname as stop_name,
	'sa_'||t.stopareacode as parent_station,
	ST_Transform(st_setsrid(st_makepoint(locationx_ew, locationy_ns), 28992), 4326) AS the_geom,
        wheelchair_accessible as wheelchair_boarding
	FROM timingpoint as t, usertimingpoint as u, gtfs_wheelchair_accessibility as g
	WHERE wheelchairaccessibility = wheelchairaccessible AND
	NOT EXISTS (
                     SELECT 1 
		      FROM usertimingpoint,localservicegrouppasstime
			WHERE t.timingpointcode = usertimingpoint.timingpointcode AND
				journeystoptype = 'INFOPOINT' AND
				usertimingpoint.dataownercode = localservicegrouppasstime.dataownercode AND
				usertimingpoint.userstopcode = localservicegrouppasstime.userstopcode) AND
					u.timingpointcode = t.timingpointcode AND u.userstopcode in 
					(SELECT distinct userstopcode FROM localservicegrouppasstime)
                    ) AS X) 
        AS stops
ORDER BY location_type DESC, stop_id ASC
)TO '/tmp/gtfs/stops.txt' WITH CSV HEADER;

copy (
SELECT 
l.dataownercode||'|'||lineplanningnumber as route_id, l.dataownercode||'|'||l.localservicelevelcode as service_id,
l.dataownercode||'|'||lineplanningnumber||'|'||l.localservicelevelcode||'|'||journeynumber||'|'||fortifyordernumber as trip_id,
destinationname50 as trip_headsign,
(cast(linedirection as int4) - 1) as direction_id,
wheelchair_accessible
FROM 
localservicegrouppasstime as l, destination as d, gtfs_wheelchair_accessibility as g,
(SELECT distinct dataownercode, localservicelevelcode FROM localservicegroupvalidity) as v 
WHERE l.dataownercode = d.dataownercode AND
l.destinationcode = d.destinationcode AND
l.userstopordernumber = 1 AND
v.dataownercode = l.dataownercode AND
v.localservicelevelcode = l.localservicelevelcode AND
g.wheelchairaccessibility = l.wheelchairaccessible
) TO '/tmp/gtfs/trips.txt' WITH CSV HEADER;

copy (
SELECT
l.dataownercode||'|'||lineplanningnumber||'|'||l.localservicelevelcode||'|'||journeynumber||'|'||fortifyordernumber as trip_id,
targetarrivaltime as arrival_time,
CASE WHEN (targetdeparturetime = '00:00:00' and journeystoptype = 'LAST') THEN targetarrivaltime ELSE targetdeparturetime END as departure_time,
timingpointcode as stop_id,
userstopordernumber as stop_sequence,
destinationname50 as stop_headsign,
cast (istimingstop as INT4) as timedstop
FROM
localservicegrouppasstime as l,destination as d, usertimingpoint as u,
     (SELECT distinct dataownercode, localservicelevelcode FROM localservicegroupvalidity) as v
WHERE journeystoptype <> 'INFOPOINT' AND
l.dataownercode = d.dataownercode AND
l.destinationcode = d.destinationcode AND
l.dataownercode = u.dataownercode AND
l.userstopcode = u.userstopcode AND
v.dataownercode = l.dataownercode AND
v.localservicelevelcode = l.localservicelevelcode
) TO '/tmp/gtfs/stop_times.txt' WITH CSV HEADER;

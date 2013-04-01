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

create table gtfs_route_bikes_allowed (
        "dataownercode"      VARCHAR(10)   NOT NULL,
        "lineplanningnumber" VARCHAR(10)   NOT NULL,
        "trip_bikes_allowed" int4,
	PRIMARY KEY ("dataownercode", "lineplanningnumber")
);
insert into gtfs_route_bikes_allowed values ('GVB','900',2);
insert into gtfs_route_bikes_allowed values ('GVB','901',2);
insert into gtfs_route_bikes_allowed values ('GVB','902',2);
insert into gtfs_route_bikes_allowed values ('GVB','904',2);
insert into gtfs_route_bikes_allowed values ('GVB','905',2);
insert into gtfs_route_bikes_allowed values ('GVB','906',2);
insert into gtfs_route_bikes_allowed values ('GVB','907',2);
insert into gtfs_route_bikes_allowed values ('GVB','50',2);
insert into gtfs_route_bikes_allowed values ('GVB','51',2);
insert into gtfs_route_bikes_allowed values ('GVB','52',2);
insert into gtfs_route_bikes_allowed values ('GVB','53',2);
insert into gtfs_route_bikes_allowed values ('GVB','54',2);
insert into gtfs_route_bikes_allowed values ('CXX','N419',2);
insert into gtfs_route_bikes_allowed values ('CXX','Z020',2);
insert into gtfs_route_bikes_allowed values ('CXX','Z050',2);
insert into gtfs_route_bikes_allowed values ('CXX','Z060',2);



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
insert into dataownerurl values ('RET', 'http://www.ret.nl');

copy (
SELECT 
d.dataownercode AS agency_id,
dataownername AS agency_name,
agency_url,
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
       NULL   AS wheelchair_boarding,
       NULL   AS platform_code
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
wheelchair_accessible as wheelchair_boarding,
CASE WHEN (platform_code in ('-','Left','Right')) THEN NULL ELSE platform_code END as platform_code
FROM gtfs_wheelchair_accessibility as g, (
	SELECT distinct t.timingpointcode as stop_id,
	t.timingpointname as stop_name,
	'sa_'||t.stopareacode as parent_station,
	ST_Transform(st_setsrid(st_makepoint(locationx_ew, locationy_ns), 28992), 4326) AS the_geom,
        wheelchairaccessible,
	platform_code
	FROM timingpoint as t, (SELECT distinct on(timingpointcode)
	              timingpointcode,sidecode as platform_code
		      FROM usertimingpoint,localservicegrouppasstime
			WHERE	journeystoptype != 'INFOPOINT' AND
				usertimingpoint.dataownercode = localservicegrouppasstime.dataownercode AND
				usertimingpoint.userstopcode = localservicegrouppasstime.userstopcode) as tpc
                    WHERE t.timingpointcode = tpc.timingpointcode
		    ) AS X WHERE wheelchairaccessibility = wheelchairaccessible) 
        AS stops
ORDER BY location_type DESC, stop_id ASC
)TO '/tmp/gtfs/stops.txt' WITH CSV HEADER;

copy (
SELECT 
l.dataownercode||'|'||lineplanningnumber as route_id, l.dataownercode||'|'||l.localservicelevelcode as service_id,
l.dataownercode||'|'||lineplanningnumber||'|'||l.localservicelevelcode||'|'||journeynumber||'|'||fortifyordernumber as trip_id,
destinationname50 as trip_headsign,
(cast(linedirection as int4) - 1) as direction_id,
wheelchair_accessible,
trip_bikes_allowed
FROM 
destination as d, gtfs_wheelchair_accessibility as g,
localservicegrouppasstime as l LEFT JOIN gtfs_route_bikes_allowed using (dataownercode,lineplanningnumber)
WHERE l.dataownercode = d.dataownercode AND
l.destinationcode = d.destinationcode AND
l.journeystoptype = 'FIRST' AND
g.wheelchairaccessibility = l.wheelchairaccessible
) TO '/tmp/gtfs/trips.txt' WITH CSV HEADER;

copy (
SELECT
l.dataownercode||'|'||l.lineplanningnumber||'|'||l.localservicelevelcode||'|'||l.journeynumber||'|'||l.fortifyordernumber as trip_id,
l.targetarrivaltime as arrival_time,
CASE WHEN (l.targetdeparturetime = '00:00:00' and l.journeystoptype = 'LAST') THEN l.targetarrivaltime ELSE l.targetdeparturetime END as departure_time,
timingpointcode as stop_id,
l.userstopordernumber as stop_sequence,
CASE WHEN (l.destinationcode <> trip.destinationcode) THEN destinationname50 ELSE null END as stop_headsign,
cast (l.istimingstop as INT4) as timepoint,
CASE WHEN (l.productformulatype in ('2','35','36')) THEN 2 ELSE 0 END as pickup_type,
CASE WHEN (l.productformulatype in ('2','35','36')) THEN 2 ELSE 0 END as drop_off_type
FROM
localservicegrouppasstime as l,destination as d, usertimingpoint as u,
(select distinct dataownercode,localservicelevelcode,lineplanningnumber,journeypatterncode,destinationcode from localservicegrouppasstime where journeystoptype = 'FIRST') as trip
WHERE l.journeystoptype <> 'INFOPOINT' AND
l.dataownercode = d.dataownercode AND
l.destinationcode = d.destinationcode AND
l.dataownercode = u.dataownercode AND
l.userstopcode = u.userstopcode AND
l.dataownercode = trip.dataownercode AND
l.localservicelevelcode = trip.localservicelevelcode AND
l.lineplanningnumber = trip.lineplanningnumber AND
l.journeypatterncode = trip.journeypatterncode
) TO '/tmp/gtfs/stop_times.txt' WITH CSV HEADER;

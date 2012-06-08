--alter table timingpoint drop column ignore;
--alter table usertimingpoint drop column ignore;
alter table timingpoint add column ignore boolean;
alter table usertimingpoint add ignore boolean;
update usertimingpoint set ignore = true WHERE EXISTS (SELECT 1 FROM localservicegrouppasstime as "p" where journeystoptype = 'INFOPOINT' AND p.userstopcode = usertimingpoint.userstopcode);
update timingpoint set ignore = (select ignore from usertimingpoint as u where u.timingpointcode = timingpoint.timingpointcode LIMIT 1);


create table gtfs_route_type (transporttype varchar(5) primary key, route_type int4);
insert into gtfs_route_type values ('TRAM', 0);
insert into gtfs_route_type values ('METRO', 1);
insert into gtfs_route_type values ('RAIL', 2);
insert into gtfs_route_type values ('BUS', 3);
insert into gtfs_route_type values ('BOAT', 4);

create table gtfs_wheelchair_accessibility (wheelchairaccessibility
varchar(13) primary key, wheelchair_accessible int4);
insert into gtfs_wheelchair_accessibility values ('UNKNOWN', 0);
insert into gtfs_wheelchair_accessibility values ('ACCESSIBLE', 1);
insert into gtfs_wheelchair_accessibility values ('INACCESSIBLE', 2);

--copy (select dataownercode AS agency_id, dataownername AS agency_name, 'http://'||dataownername||'.nl/' AS agency_url, 'Europe/Amsterdam' AS agency_timezone, 'nl' AS agency_lang FROM dataowner WHERE dataownercode <> 'ALGEMEEN') TO '/tmp/gtfs/agency.txt' WITH CSV HEADER;

copy (select 'OVapi' as feed_publisher_name, 'http://ovapi.nl/' as feed_publisher_url, 'nl' as feed_lang, replace(cast(min(operationdate) AS text), '-', '') as feed_start_date, replace(cast(max(operationdate) AS text), '-', '') as feed_end_date, now() as feed_version from localservicegroupvalidity) TO '/tmp/gtfs/feed_info.txt' WITH CSV HEADER;

copy (select dataownercode||'_'||localservicelevelcode as service_id, replace(cast(operationdate as text), '-', '') as date, '1' as exception_type from localservicegroupvalidity) TO '/tmp/gtfs/calendar_dates.txt' WITH CSV HEADER;

copy (select dataownercode||'_'||lineplanningnumber as route_id, dataownercode as agency_id, linepublicnumber as route_short_name, CASE WHEN linepublicnumber <> linename THEN linename ELSE '' END as route_long_name, g.route_type as route_type from line as l, gtfs_route_type as g where l.transporttype = g.transporttype) TO '/tmp/gtfs/routes.txt' WITH CSV HEADER;

COPY (
SELECT * FROM (
SELECT 'sa_'||a.stopareacode AS stop_id, stopareaname AS stop_name,
       CAST(st_X(the_geom) AS NUMERIC(8,5)) AS stop_lon,
       CAST(st_Y(the_geom) AS NUMERIC(9,6)) AS stop_lat,
       1      AS location_type,
       NULL   AS parent_station
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
select stop_id, stop_name, CAST(st_X(the_geom) AS NUMERIC(8,5)) AS stop_lon, CAST(st_Y(the_geom) AS NUMERIC(9,6)) AS stop_lat, 0 AS location_type, parent_station FROM (select distinct t.timingpointcode as stop_id, t.timingpointname as stop_name, 'sa_'||t.stopareacode as parent_station, ST_Transform(st_setsrid(st_makepoint(locationx_ew, locationy_ns), 28992), 4326) AS the_geom from timingpoint as t, usertimingpoint as u where t.ignore is null AND u.timingpointcode = t.timingpointcode and u.userstopcode in (select distinct userstopcode from localservicegrouppasstime)) AS X) AS stops ORDER BY location_type DESC, stop_id ASC) TO '/tmp/gtfs/stops.txt' WITH CSV HEADER;

update localservicegrouppasstime set linedirection = '1' where linedirection = 'A';
update localservicegrouppasstime set linedirection = '2' where linedirection = 'B';


copy (select l.dataownercode||'_'||lineplanningnumber as route_id, l.dataownercode||'_'||l.localservicelevelcode as service_id, l.dataownercode||'_'||lineplanningnumber||'_'||l.localservicelevelcode||'_'||journeynumber||'_'||fortifyordernumber as trip_id, destinationname50 as trip_headsign, (cast(linedirection as int4) - 1) as direction_id from localservicegrouppasstime as l, destination as d, (select distinct dataownercode, localservicelevelcode from localservicegroupvalidity) as v where l.dataownercode = d.dataownercode and l.destinationcode = d.destinationcode and l.userstopordernumber = 1 and v.dataownercode = l.dataownercode and v.localservicelevelcode = l.localservicelevelcode) TO '/tmp/gtfs/trips.txt' WITH CSV HEADER;

update localservicegrouppasstime set targetdeparturetime = targetarrivaltime where targetdeparturetime = '00:00:00' AND journeystoptype = 'LAST';
copy (select l.dataownercode||'_'||lineplanningnumber||'_'||l.localservicelevelcode||'_'||journeynumber||'_'||fortifyordernumber as trip_id, targetarrivaltime as arrival_time, targetdeparturetime as departure_time, timingpointcode as stop_id, userstopordernumber as stop_sequence, destinationname50 as stop_headsign, wheelchair_accessible from localservicegrouppasstime as l, destination as d, usertimingpoint as u, (select distinct dataownercode, localservicelevelcode from localservicegroupvalidity) as v,  gtfs_wheelchair_accessibility as w where w.wheelchairaccessibility = l.wheelchairaccessible and ignore is null and l.dataownercode = d.dataownercode and l.destinationcode = d.destinationcode and l.dataownercode = u.dataownercode and l.userstopcode = u.userstopcode and v.dataownercode = l.dataownercode and v.localservicelevelcode = l.localservicelevelcode) TO '/tmp/gtfs/stop_times.txt' WITH CSV HEADER;

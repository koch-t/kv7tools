kv7tools
========
Tool om kv7 bestanden in database te laden.

Handleiding
========
1. Maak database schema aan ```psql -U <username> -d <db_name> -a -f kv7_create.sql ```
2. Download kv7planning en kv7calender bestanden
	* ```wget -q -N --accept=gz --limit-rate=1000k -r http://kv7turbo.openov.nl/GOVI/KV7planning/ -l 1 ```
	* ```wget -q -N --accept=gz --limit-rate=1000k -r http://kv7turbo.openov.nl/GOVI/KV7calendar/ -l 1 ```
3. ```python kv7clean.py <verwijzing naar map KV7calendar> <verwijzing naar map KV7planning> ```
4. Preprocess kv7
	* ```python kv7planning-index.py data/kv7turbo.openov.nl/GOVI/KV7planning/```
	* ```python kv7kalender-index.py data/kv7turbo.openov.nl/GOVI/KV7calendar/ ```
5. Genereer kv7.sql ```python kv7-import2.py <verwijzing naar map KV7calendar> <verwijzing naar map KV7planning> ```
6. Laad kv7.sql in database ```psql -U <username> -d <db_name> -a -f kv7.sql ```

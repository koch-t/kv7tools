CREATE TABLE "dataowner" (
        "dataownercode"          VARCHAR(10)   NOT NULL,
        "dataownertype"          VARCHAR(10)   NOT NULL,
        "dataownername"          VARCHAR(30)   NOT NULL,
        "dataownercompanynumber" DECIMAL(3),
         PRIMARY KEY ("dataownercode")
);
CREATE TABLE "line" (
        "dataownercode"      VARCHAR(10)   NOT NULL,
        "lineplanningnumber" VARCHAR(10)   NOT NULL,
        "linepublicnumber"   VARCHAR(4)    NOT NULL,
        "linename"           VARCHAR(50),
        "linevetagnumber"    DECIMAL(3),
        "transporttype"      VARCHAR(5)    NOT NULL,
        "lineicon"           INTEGER,
        "linecolor"          VARCHAR(6),
        "linetextcolor"      VARCHAR(6),
         PRIMARY KEY ("dataownercode", "lineplanningnumber")
);
CREATE TABLE "destination" (
        "dataownercode"        VARCHAR(10)   NOT NULL,
        "destinationcode"      VARCHAR(10)   NOT NULL,
        "destinationname50"    VARCHAR(50)   NOT NULL,
        "destinationname30"    VARCHAR(30),
        "destinationname24"    VARCHAR(24),
        "destinationname19"    VARCHAR(19),
        "destinationname16"    VARCHAR(16)   NOT NULL,
        "destinationdetail24"  VARCHAR(24),
        "destinationdetail19"  VARCHAR(19),
        "destinationdetail16"  VARCHAR(16),
        "destinationdisplay16" VARCHAR(16),
        "destinationname21"    VARCHAR(21),
        "destinationdetail21"  VARCHAR(21),
        "relevantdestnamedetail" VARCHAR(5),
        "desticon"             INTEGER,
        "destcolor"            VARCHAR(6),
        "desttextcolor"        VARCHAR(6),
         PRIMARY KEY ("dataownercode", "destinationcode")
);
CREATE TABLE "destinationvia" (
        "dataownercode"         VARCHAR(10)   NOT NULL,
        "destinationcodep"      VARCHAR(10)   NOT NULL,
        "destinationcodec"      VARCHAR(10)   NOT NULL,
        "destinationviaordernr" INT4       NOT NULL,
         PRIMARY KEY ("dataownercode", "destinationcodep", "destinationcodec")
);

CREATE TABLE "timingpoint" (
        "dataownercode"   VARCHAR(10)   NOT NULL,
        "timingpointcode" VARCHAR(10)   NOT NULL,
        "timingpointname" VARCHAR(50)   NOT NULL,
        "timingpointtown" VARCHAR(50)   NOT NULL,
        "locationx_ew"    INTEGER       ,
        "locationy_ns"    INTEGER       ,
        "locationz"       INTEGER,
        "stopareacode"    VARCHAR(10),
         PRIMARY KEY ("dataownercode", "timingpointcode")
);
CREATE TABLE "usertimingpoint" (
        "dataownercode"            VARCHAR(10)   NOT NULL,
        "userstopcode"             VARCHAR(10)   NOT NULL,
        "timingpointdataownercode" VARCHAR(10)   NOT NULL,
        "timingpointcode"          VARCHAR(10)   NOT NULL,
        "getin"                    BOOLEAN       NOT NULL,
        "getout"                   BOOLEAN       NOT NULL,
         PRIMARY KEY ("dataownercode", "userstopcode")
);
CREATE TABLE "stoparea" (
        "dataownercode" VARCHAR(10)   NOT NULL,
        "stopareacode"  VARCHAR(10)   NOT NULL,
        "stopareaname"  VARCHAR(50)   NOT NULL,
         PRIMARY KEY ("dataownercode", "stopareacode")
);
CREATE TABLE "localservicegrouppasstime" (
        "dataownercode"         VARCHAR(10)   NOT NULL,
        "localservicelevelcode" VARCHAR(10)   NOT NULL,
        "lineplanningnumber"    VARCHAR(10)   NOT NULL,
        "journeynumber"         DECIMAL(6)    NOT NULL,
        "fortifyordernumber"    DECIMAL(2)    NOT NULL,
        "userstopcode"          VARCHAR(10)   NOT NULL,
        "journeypatterncode"    VARCHAR(10)   NOT NULL,
        "userstopordernumber"   DECIMAL(3)    NOT NULL,
        "linedirection"         DECIMAL(1)    NOT NULL,
        "destinationcode"       VARCHAR(10)   NOT NULL,
        "targetarrivaltime"     VARCHAR(8)    NOT NULL,
        "targetdeparturetime"   VARCHAR(8)    NOT NULL,
        "sidecode"              VARCHAR(10),
        "wheelchairaccessible"  VARCHAR(13)   NOT NULL,
        "journeystoptype"       VARCHAR(12)   NOT NULL,
        "istimingstop"          BOOLEAN       NOT NULL,
        "productformulatype"    VARCHAR(10),
        "getin"                 BOOLEAN,
        "getout"                BOOLEAN,
        "showflexibletrip"      VARCHAR(8),
        "linedesticon"          INTEGER,
        "linedestcolor"         VARCHAR(6),
        "linedesttextcolor"     VARCHAR(6),
        "blockcode"             VARCHAR(30),
        "sequenceinblock"       VARCHAR(30),
        "vehiclejourneytype"    VARCHAR(255),
         PRIMARY KEY ("dataownercode", "localservicelevelcode", "lineplanningnumber", "journeynumber", "fortifyordernumber", "userstopcode", "userstopordernumber")
);
CREATE TABLE "localservicegroup" (
        "dataownercode"         VARCHAR(10)   NOT NULL,
        "localservicelevelcode" VARCHAR(10)   NOT NULL,
         PRIMARY KEY ("dataownercode", "localservicelevelcode")
);
CREATE TABLE "localservicegroupvalidity" (
        "dataownercode"         VARCHAR(10)   NOT NULL,
        "localservicelevelcode" VARCHAR(10)   NOT NULL,
        "operationdate"         DATE          NOT NULL,
         PRIMARY KEY ("dataownercode", "localservicelevelcode", "operationdate")
);

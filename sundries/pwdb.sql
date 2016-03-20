--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: pwdb; Type: DATABASE; Schema: -; Owner: root
--

CREATE DATABASE pwdb WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_GB.UTF-8' LC_CTYPE = 'en_GB.UTF-8';


ALTER DATABASE pwdb OWNER TO root;

\connect pwdb

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: crackedlm; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE crackedlm (
    cryptolm character varying(16),
    plain character varying(7)
);


ALTER TABLE public.crackedlm OWNER TO root;

--
-- Name: crackednt; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE crackednt (
    cryptont character varying(250),
    plain character varying(250)
);


ALTER TABLE public.crackednt OWNER TO root;

--
-- Name: currentclient; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE currentclient (
    username character varying(255),
    cryptont character varying(32),
    cryptolm1 character varying(16),
    cryptolm2 character varying(16)
);


ALTER TABLE public.currentclient OWNER TO root;

--
-- Name: currentclientdomainadmins; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE currentclientdomainadmins (
    username character varying(255)
);


ALTER TABLE public.currentclientdomainadmins OWNER TO root;

--
-- Name: currentclientliveusers; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE currentclientliveusers (
    username character varying(255)
);


ALTER TABLE public.currentclientliveusers OWNER TO root;

--
-- Name: importcrackedlm; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE importcrackedlm (
    plain character varying(7),
    cryptolm character varying(16)
);


ALTER TABLE public.importcrackedlm OWNER TO root;

--
-- Name: importcrackednt; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE importcrackednt (
    plain character varying(255),
    cryptont character varying(48)
);


ALTER TABLE public.importcrackednt OWNER TO root;

--
-- Name: listadminswithcrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listadminswithcrackednt AS
 SELECT currentclient.username,
    crackednt.cryptont,
    crackednt.plain
   FROM currentclient,
    crackednt,
    currentclientdomainadmins
  WHERE (((currentclient.cryptont)::text = (crackednt.cryptont)::text) AND ((currentclient.username)::text = (currentclientdomainadmins.username)::text));


ALTER TABLE public.listadminswithcrackednt OWNER TO root;

--
-- Name: listallcrackedpasswords; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listallcrackedpasswords AS
 SELECT crackednt.plain
   FROM crackednt;


ALTER TABLE public.listallcrackedpasswords OWNER TO root;

--
-- Name: listliveadminswithcrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listliveadminswithcrackednt AS
 SELECT currentclient.username,
    crackednt.cryptont,
    crackednt.plain
   FROM currentclient,
    currentclientliveusers,
    crackednt,
    currentclientdomainadmins
  WHERE ((((currentclient.username)::text = (currentclientliveusers.username)::text) AND ((currentclient.cryptont)::text = (crackednt.cryptont)::text)) AND ((currentclient.username)::text = (currentclientdomainadmins.username)::text));


ALTER TABLE public.listliveadminswithcrackednt OWNER TO root;

--
-- Name: listliveadminswithuncrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listliveadminswithuncrackednt AS
 SELECT currentclient.username,
    currentclient.cryptont
   FROM currentclient,
    currentclientliveusers,
    currentclientdomainadmins
  WHERE (((((currentclient.username)::text = (currentclientliveusers.username)::text) AND ((currentclient.username)::text = (currentclientdomainadmins.username)::text)) AND (NOT ((currentclient.cryptont)::text IN ( SELECT crackednt.cryptont
           FROM crackednt)))) AND ((currentclient.cryptont)::text <> '31d6cfe0d16ae931b73c59d7e0c089c0'::text));


ALTER TABLE public.listliveadminswithuncrackednt OWNER TO root;

--
-- Name: listliveuserswithcrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listliveuserswithcrackednt AS
 SELECT currentclient.username,
    crackednt.cryptont,
    crackednt.plain
   FROM currentclient,
    currentclientliveusers,
    crackednt
  WHERE ((((currentclient.username)::text = (currentclientliveusers.username)::text) AND ((currentclient.cryptont)::text = (crackednt.cryptont)::text)) AND ((crackednt.cryptont)::text <> '31d6cfe0d16ae931b73c59d7e0c089c0'::text));


ALTER TABLE public.listliveuserswithcrackednt OWNER TO root;

--
-- Name: listliveuserswithnonblanklm; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listliveuserswithnonblanklm AS
 SELECT currentclient.username,
    currentclient.cryptolm1,
    currentclient.cryptolm2
   FROM currentclient
  WHERE ((currentclient.cryptolm1)::text <> 'aad3b435b51404ee'::text)
  ORDER BY currentclient.username;


ALTER TABLE public.listliveuserswithnonblanklm OWNER TO root;

--
-- Name: listliveuserswithpasswordasuser; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listliveuserswithpasswordasuser AS
 SELECT listliveuserswithcrackednt.username,
    listliveuserswithcrackednt.plain
   FROM listliveuserswithcrackednt
  WHERE (((listliveuserswithcrackednt.username)::text ~~* (listliveuserswithcrackednt.plain)::text) OR ((listliveuserswithcrackednt.plain)::text ~~* (listliveuserswithcrackednt.username)::text))
  ORDER BY listliveuserswithcrackednt.plain;


ALTER TABLE public.listliveuserswithpasswordasuser OWNER TO root;

--
-- Name: listliveuserswithuncrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listliveuserswithuncrackednt AS
 SELECT currentclient.username,
    currentclient.cryptont
   FROM currentclient,
    currentclientliveusers
  WHERE ((((currentclient.username)::text = (currentclientliveusers.username)::text) AND (NOT ((currentclient.cryptont)::text IN ( SELECT crackednt.cryptont
           FROM crackednt)))) AND ((currentclient.cryptont)::text <> '31d6cfe0d16ae931b73c59d7e0c089c0'::text));


ALTER TABLE public.listliveuserswithuncrackednt OWNER TO root;

--
-- Name: verypoorplaintexts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE verypoorplaintexts (
    plain character varying(250)
);


ALTER TABLE public.verypoorplaintexts OWNER TO root;

--
-- Name: listliveuserswithverypoorpassword; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listliveuserswithverypoorpassword AS
 SELECT listliveuserswithcrackednt.username,
    listliveuserswithcrackednt.plain
   FROM listliveuserswithcrackednt,
    verypoorplaintexts
  WHERE ((listliveuserswithcrackednt.plain)::text ~~ concat('%', verypoorplaintexts.plain, '%'))
  ORDER BY listliveuserswithcrackednt.plain;


ALTER TABLE public.listliveuserswithverypoorpassword OWNER TO root;

--
-- Name: listlmdictionary; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listlmdictionary AS
 SELECT DISTINCT ((( SELECT crackedlm.plain
           FROM crackedlm
          WHERE ((currentclient.cryptolm1)::text = (crackedlm.cryptolm)::text)))::text || (( SELECT crackedlm.plain
           FROM crackedlm
          WHERE ((currentclient.cryptolm2)::text = (crackedlm.cryptolm)::text)))::text) AS plain
   FROM currentclient
  WHERE ((currentclient.cryptolm1)::text <> 'aad3b435b51404ee'::text);


ALTER TABLE public.listlmdictionary OWNER TO root;

--
-- Name: listntdictionary; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listntdictionary AS
 SELECT DISTINCT crackednt.plain
   FROM currentclient,
    crackednt
  WHERE (((currentclient.cryptont)::text = (crackednt.cryptont)::text) AND ((currentclient.cryptont)::text <> '31d6cfe0d16ae931b73c59d7e0c089c0'::text));


ALTER TABLE public.listntdictionary OWNER TO root;

--
-- Name: listuncrackedlmhalf1; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuncrackedlmhalf1 AS
 SELECT currentclient.cryptolm1
   FROM currentclient
  WHERE (NOT ((currentclient.cryptolm1)::text IN ( SELECT crackedlm.cryptolm
           FROM crackedlm
          WHERE ((crackedlm.cryptolm)::text = (currentclient.cryptolm1)::text))));


ALTER TABLE public.listuncrackedlmhalf1 OWNER TO root;

--
-- Name: listuncrackedlmhalf2; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuncrackedlmhalf2 AS
 SELECT currentclient.cryptolm2
   FROM currentclient
  WHERE (NOT ((currentclient.cryptolm2)::text IN ( SELECT crackedlm.cryptolm
           FROM crackedlm
          WHERE ((crackedlm.cryptolm)::text = (currentclient.cryptolm2)::text))));


ALTER TABLE public.listuncrackedlmhalf2 OWNER TO root;

--
-- Name: listuserswherepasswordisusername; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswherepasswordisusername AS
 SELECT currentclient.username,
    currentclient.cryptont,
    crackednt.plain
   FROM crackednt,
    currentclient
  WHERE (((currentclient.cryptont)::text = (crackednt.cryptont)::text) AND ((crackednt.plain)::text = (currentclient.username)::text));


ALTER TABLE public.listuserswherepasswordisusername OWNER TO root;

--
-- Name: listuserswithblanknt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithblanknt AS
 SELECT currentclient.username,
    currentclient.cryptont
   FROM currentclient
  WHERE ((currentclient.cryptont)::text = '31d6cfe0d16ae931b73c59d7e0c089c0'::text);


ALTER TABLE public.listuserswithblanknt OWNER TO root;

--
-- Name: listuserswithcrackedlm; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithcrackedlm AS
 SELECT currentclient.username,
    currentclient.cryptolm1,
    currentclient.cryptolm2,
    ( SELECT crackedlm.plain
           FROM crackedlm
          WHERE ((currentclient.cryptolm1)::text = (crackedlm.cryptolm)::text)) AS plain1,
    ( SELECT crackedlm.plain
           FROM crackedlm
          WHERE ((currentclient.cryptolm2)::text = (crackedlm.cryptolm)::text)) AS plain2
   FROM currentclient
  WHERE ((currentclient.cryptolm1)::text <> 'aad3b435b51404ee'::text)
  ORDER BY currentclient.username;


ALTER TABLE public.listuserswithcrackedlm OWNER TO root;

--
-- Name: listuserswithcrackedlmbutuncrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithcrackedlmbutuncrackednt AS
 SELECT currentclient.username,
    currentclient.cryptont,
    ((( SELECT crackedlm.plain
           FROM crackedlm
          WHERE ((currentclient.cryptolm1)::text = (crackedlm.cryptolm)::text)))::text || (( SELECT crackedlm.plain
           FROM crackedlm
          WHERE ((currentclient.cryptolm2)::text = (crackedlm.cryptolm)::text)))::text) AS plainlm
   FROM currentclient
  WHERE (((currentclient.cryptolm1)::text <> 'aad3b435b51404ee'::text) AND (NOT ((currentclient.cryptont)::text IN ( SELECT crackednt.cryptont
           FROM crackednt
          WHERE ((currentclient.cryptont)::text = (crackednt.cryptont)::text)))))
  ORDER BY currentclient.username;


ALTER TABLE public.listuserswithcrackedlmbutuncrackednt OWNER TO root;

--
-- Name: listuserswithcrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithcrackednt AS
 SELECT currentclient.username,
    currentclient.cryptont,
    crackednt.plain
   FROM currentclient,
    crackednt
  WHERE (((currentclient.cryptont)::text = (crackednt.cryptont)::text) AND ((currentclient.cryptont)::text <> '31d6cfe0d16ae931b73c59d7e0c089c0'::text))
  ORDER BY currentclient.username;


ALTER TABLE public.listuserswithcrackednt OWNER TO root;

--
-- Name: listuserswithcrackedntincblank; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithcrackedntincblank AS
 SELECT currentclient.username,
    currentclient.cryptont,
    crackednt.plain
   FROM currentclient,
    crackednt
  WHERE ((currentclient.cryptont)::text = (crackednt.cryptont)::text)
  ORDER BY currentclient.username;


ALTER TABLE public.listuserswithcrackedntincblank OWNER TO root;

--
-- Name: listuserswithnonblanklm; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithnonblanklm AS
 SELECT currentclient.username,
    currentclient.cryptolm1,
    currentclient.cryptolm2
   FROM currentclient
  WHERE ((currentclient.cryptolm1)::text <> 'aad3b435b51404ee'::text)
  ORDER BY currentclient.username;


ALTER TABLE public.listuserswithnonblanklm OWNER TO root;

--
-- Name: listuserswithpasswordasuser; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithpasswordasuser AS
 SELECT listuserswithcrackednt.username,
    listuserswithcrackednt.plain
   FROM listuserswithcrackednt
  WHERE (((listuserswithcrackednt.username)::text ~~* (listuserswithcrackednt.plain)::text) OR ((listuserswithcrackednt.plain)::text ~~* (listuserswithcrackednt.username)::text))
  ORDER BY listuserswithcrackednt.plain;


ALTER TABLE public.listuserswithpasswordasuser OWNER TO root;

--
-- Name: listuserswithuncrackedlm; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithuncrackedlm AS
 SELECT currentclient.username,
    currentclient.cryptolm1,
    currentclient.cryptolm2
   FROM currentclient
  WHERE ((NOT ((currentclient.cryptolm1)::text IN ( SELECT crackedlm.cryptolm
           FROM crackedlm
          WHERE ((crackedlm.cryptolm)::text = (currentclient.cryptolm1)::text)))) OR (NOT ((currentclient.cryptolm2)::text IN ( SELECT crackedlm.cryptolm
           FROM crackedlm
          WHERE ((crackedlm.cryptolm)::text = (currentclient.cryptolm2)::text)))));


ALTER TABLE public.listuserswithuncrackedlm OWNER TO root;

--
-- Name: listuserswithuncrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithuncrackednt AS
 SELECT currentclient.username,
    currentclient.cryptont
   FROM currentclient
  WHERE (NOT ((currentclient.cryptont)::text IN ( SELECT crackednt.cryptont
           FROM crackednt
          WHERE ((crackednt.cryptont)::text = (currentclient.cryptont)::text))));


ALTER TABLE public.listuserswithuncrackednt OWNER TO root;

--
-- Name: listuserswithverypoorpassword; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listuserswithverypoorpassword AS
 SELECT DISTINCT listuserswithcrackednt.username,
    listuserswithcrackednt.plain
   FROM listuserswithcrackednt,
    verypoorplaintexts
  WHERE ((listuserswithcrackednt.plain)::text ~~ concat('%', verypoorplaintexts.plain, '%'))
  ORDER BY listuserswithcrackednt.plain;


ALTER TABLE public.listuserswithverypoorpassword OWNER TO root;

--
-- Name: newcrackedlm; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW newcrackedlm AS
 SELECT importcrackedlm.plain,
    importcrackedlm.cryptolm
   FROM importcrackedlm
  WHERE (NOT ((importcrackedlm.plain)::text IN ( SELECT crackedlm.plain
           FROM crackedlm)));


ALTER TABLE public.newcrackedlm OWNER TO root;

--
-- Name: newcrackednt; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW newcrackednt AS
 SELECT importcrackednt.plain,
    importcrackednt.cryptont
   FROM importcrackednt
  WHERE (NOT ((importcrackednt.plain)::text IN ( SELECT crackednt.plain
           FROM crackednt)));


ALTER TABLE public.newcrackednt OWNER TO root;

--
-- Name: numcrackedusers; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW numcrackedusers AS
 SELECT count(currentclient.username) AS numaccountscracked
   FROM currentclient,
    crackednt
  WHERE ((currentclient.cryptont)::text = (crackednt.cryptont)::text);


ALTER TABLE public.numcrackedusers OWNER TO root;

--
-- Name: numdistinctcrackedpasswords; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW numdistinctcrackedpasswords AS
 SELECT count(DISTINCT crackednt.plain) AS num
   FROM currentclient,
    crackednt
  WHERE ((currentclient.cryptont)::text = (crackednt.cryptont)::text);


ALTER TABLE public.numdistinctcrackedpasswords OWNER TO root;

--
-- Name: numdistinctpasswords; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW numdistinctpasswords AS
 SELECT count(DISTINCT currentclient.cryptont) AS num
   FROM currentclient;


ALTER TABLE public.numdistinctpasswords OWNER TO root;

--
-- Name: numlivecrackedusers; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW numlivecrackedusers AS
 SELECT count(currentclient.username) AS count
   FROM currentclient,
    currentclientliveusers,
    crackednt
  WHERE ((((currentclient.username)::text = (currentclientliveusers.username)::text) AND ((currentclient.cryptont)::text = (crackednt.cryptont)::text)) AND ((crackednt.cryptont)::text <> '31d6cfe0d16ae931b73c59d7e0c089c0'::text));


ALTER TABLE public.numlivecrackedusers OWNER TO root;

--
-- Name: numliveusers; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW numliveusers AS
 SELECT count(currentclient.username) AS count
   FROM currentclient,
    currentclientliveusers
  WHERE ((currentclient.username)::text = (currentclientliveusers.username)::text);


ALTER TABLE public.numliveusers OWNER TO root;

--
-- Name: numusers; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW numusers AS
 SELECT count(currentclient.username) AS num
   FROM currentclient;


ALTER TABLE public.numusers OWNER TO root;

--
-- Name: passwordlengthanalysis; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW passwordlengthanalysis AS
 SELECT char_length((crackednt.plain)::text) AS plainlength,
    count(char_length((crackednt.plain)::text)) AS plainlengthcount
   FROM currentclient,
    crackednt
  WHERE ((currentclient.cryptont)::text = (crackednt.cryptont)::text)
  GROUP BY char_length((crackednt.plain)::text)
  ORDER BY char_length((crackednt.plain)::text);


ALTER TABLE public.passwordlengthanalysis OWNER TO root;

--
-- Name: passwordlengthanalysislive; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW passwordlengthanalysislive AS
 SELECT char_length((crackednt.plain)::text) AS plainlength,
    count(char_length((crackednt.plain)::text)) AS plainlengthcount
   FROM currentclient,
    crackednt,
    currentclientliveusers
  WHERE (((currentclient.cryptont)::text = (crackednt.cryptont)::text) AND ((currentclient.username)::text = (currentclientliveusers.username)::text))
  GROUP BY char_length((crackednt.plain)::text)
  ORDER BY char_length((crackednt.plain)::text);


ALTER TABLE public.passwordlengthanalysislive OWNER TO root;

--
-- Name: listlivetoppasswords; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listlivetoppasswords AS
 SELECT plain, count(plain) AS usagecount
 FROM currentclient,
 crackednt,
 currentclientliveusers
 WHERE currentclient.cryptont = crackednt.cryptont AND currentclient.username =
currentclientliveusers.username
GROUP BY plain
ORDER BY usagecount DESC;

--
-- Name: listtoppasswords; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW listtoppasswords AS
 SELECT plain, count(plain) AS usagecount
 FROM currentclient,
 crackednt
 WHERE currentclient.cryptont = crackednt.cryptont
 GROUP BY plain
 ORDER BY usagecount DESC;

--
-- Data for Name: crackednt; Type: TABLE DATA; Schema: public; Owner: root
--

COPY crackednt (cryptont, plain) FROM stdin;
a5127cb510cdddca3453226359f64534	Pa55w0rd
8846f7eaee8fb117ad06bdd830b7586c	password
0c61039f010b2fbb88fe449fbf262477	Pa55word
a4f49c406510bdcab6824ee7c30fd852	Password
a87f3a337d73085c45f9416be5787d86	Passw0rd
92937945b518814341de3f726500d4ff	Pa$$w0rd
dcd25a439cd39daa6baeb6c02e88a9e6	Letmein1
\.

--
-- Data for Name: verypoorplaintexts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY verypoorplaintexts (plain) FROM stdin;
April
August
Autumn
Blue
December
February
Friday
Green
January
July
June
March
Monday
November
October
Orange
P@55w0rd
P@55word
Pa55w0rd
Pa55word
Passw0rd
Password
Purple
Saturday
September
Spring
Summer
Sunday
Thursday
Tuesday
Wednesday
Winter
Yellow
autumn
blue
december
england
green
ireland
november
october
orange
pa55w0rd
passw0rd
password
purple
red
scotland
september
spring
summer
wales
winter
yellow
letmein
P4ssword
p4ssword
P@ssw0rd
passw0rd
\.


--
-- Name: crackedntcryptolm; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX crackedntcryptolm ON crackedlm USING btree (cryptolm);


--
-- Name: crackedntcryptont; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX crackedntcryptont ON crackednt USING btree (cryptont);


--
-- Name: cryptont_index; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cryptont_index ON importcrackednt USING btree (cryptont);


--
-- Name: currentclientcryptolm1; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX currentclientcryptolm1 ON currentclient USING btree (cryptolm1);


--
-- Name: currentclientcryptolm2; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX currentclientcryptolm2 ON currentclient USING btree (cryptolm2);


--
-- Name: currentclientcryptont; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX currentclientcryptont ON currentclient USING btree (cryptont);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--


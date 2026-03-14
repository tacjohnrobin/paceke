--
-- PostgreSQL database dump
--

\restrict jkdEGnqRZha66DXU63WacjH5kdiZd6d5PxINAKtu6vdR7kzpzF8eGHp7HuQaiMF

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: activity; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA activity;


ALTER SCHEMA activity OWNER TO postgres;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA auth;


ALTER SCHEMA auth OWNER TO postgres;

--
-- Name: territory; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA territory;


ALTER SCHEMA territory OWNER TO postgres;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: run_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.run_status AS ENUM (
    'in_progress',
    'completed',
    'invalid'
);


ALTER TYPE public.run_status OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: global_tiles; Type: TABLE; Schema: activity; Owner: postgres
--

CREATE TABLE activity.global_tiles (
    geohash text NOT NULL,
    "precision" integer NOT NULL,
    owner_user_id integer NOT NULL,
    claimed_at timestamp with time zone DEFAULT now() NOT NULL,
    last_run_id integer NOT NULL
);


ALTER TABLE activity.global_tiles OWNER TO postgres;

--
-- Name: run_points; Type: TABLE; Schema: activity; Owner: postgres
--

CREATE TABLE activity.run_points (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    "position" public.geography(Point,4326) NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    accuracy_m double precision
);


ALTER TABLE activity.run_points OWNER TO postgres;

--
-- Name: run_points_id_seq; Type: SEQUENCE; Schema: activity; Owner: postgres
--

ALTER TABLE activity.run_points ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME activity.run_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: run_tiles; Type: TABLE; Schema: activity; Owner: postgres
--

CREATE TABLE activity.run_tiles (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    geohash text NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    "precision" smallint DEFAULT 5 NOT NULL
);


ALTER TABLE activity.run_tiles OWNER TO postgres;

--
-- Name: run_tiles_id_seq; Type: SEQUENCE; Schema: activity; Owner: postgres
--

CREATE SEQUENCE activity.run_tiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE activity.run_tiles_id_seq OWNER TO postgres;

--
-- Name: run_tiles_id_seq; Type: SEQUENCE OWNED BY; Schema: activity; Owner: postgres
--

ALTER SEQUENCE activity.run_tiles_id_seq OWNED BY activity.run_tiles.id;


--
-- Name: runs; Type: TABLE; Schema: activity; Owner: postgres
--

CREATE TABLE activity.runs (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone,
    status public.run_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_distance_m double precision DEFAULT 0,
    duration_s integer,
    run_area_m2 double precision
);


ALTER TABLE activity.runs OWNER TO postgres;

--
-- Name: runs_id_seq; Type: SEQUENCE; Schema: activity; Owner: postgres
--

ALTER TABLE activity.runs ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME activity.runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.users (
    id bigint NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: auth; Owner: postgres
--

ALTER TABLE auth.users ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME auth.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: territory_tiles; Type: TABLE; Schema: territory; Owner: postgres
--

CREATE TABLE territory.territory_tiles (
    tile_geohash character varying(20) NOT NULL,
    "precision" integer NOT NULL,
    owner_user_id integer NOT NULL,
    strength_distance_m numeric(10,2) NOT NULL,
    last_claimed_at timestamp without time zone NOT NULL
);


ALTER TABLE territory.territory_tiles OWNER TO postgres;

--
-- Name: tile_attempt_events; Type: TABLE; Schema: territory; Owner: postgres
--

CREATE TABLE territory.tile_attempt_events (
    id integer NOT NULL,
    tile_geohash character varying(20) NOT NULL,
    "precision" integer NOT NULL,
    user_id integer NOT NULL,
    run_id integer NOT NULL,
    attempt_strength_m numeric(10,2) NOT NULL,
    attempted_at timestamp without time zone DEFAULT now()
);


ALTER TABLE territory.tile_attempt_events OWNER TO postgres;

--
-- Name: tile_attempt_events_id_seq; Type: SEQUENCE; Schema: territory; Owner: postgres
--

CREATE SEQUENCE territory.tile_attempt_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE territory.tile_attempt_events_id_seq OWNER TO postgres;

--
-- Name: tile_attempt_events_id_seq; Type: SEQUENCE OWNED BY; Schema: territory; Owner: postgres
--

ALTER SEQUENCE territory.tile_attempt_events_id_seq OWNED BY territory.tile_attempt_events.id;


--
-- Name: tile_claim_events; Type: TABLE; Schema: territory; Owner: postgres
--

CREATE TABLE territory.tile_claim_events (
    id integer NOT NULL,
    tile_geohash character varying(20) NOT NULL,
    "precision" integer NOT NULL,
    user_id integer NOT NULL,
    run_id integer NOT NULL,
    strength_distance_m numeric(10,2) NOT NULL,
    claimed_at timestamp without time zone DEFAULT now()
);


ALTER TABLE territory.tile_claim_events OWNER TO postgres;

--
-- Name: tile_claim_events_id_seq; Type: SEQUENCE; Schema: territory; Owner: postgres
--

CREATE SEQUENCE territory.tile_claim_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE territory.tile_claim_events_id_seq OWNER TO postgres;

--
-- Name: tile_claim_events_id_seq; Type: SEQUENCE OWNED BY; Schema: territory; Owner: postgres
--

ALTER SEQUENCE territory.tile_claim_events_id_seq OWNED BY territory.tile_claim_events.id;


--
-- Name: tile_ownership; Type: TABLE; Schema: territory; Owner: postgres
--

CREATE TABLE territory.tile_ownership (
    tile_id bigint NOT NULL,
    owner_user_id bigint NOT NULL,
    claimed_at timestamp with time zone NOT NULL,
    avg_speed_mps double precision NOT NULL
);


ALTER TABLE territory.tile_ownership OWNER TO postgres;

--
-- Name: tiles; Type: TABLE; Schema: territory; Owner: postgres
--

CREATE TABLE territory.tiles (
    id bigint NOT NULL,
    geohash character varying(12) NOT NULL,
    geom public.geography(Polygon,4326) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE territory.tiles OWNER TO postgres;

--
-- Name: tiles_id_seq; Type: SEQUENCE; Schema: territory; Owner: postgres
--

ALTER TABLE territory.tiles ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME territory.tiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: run_tiles id; Type: DEFAULT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.run_tiles ALTER COLUMN id SET DEFAULT nextval('activity.run_tiles_id_seq'::regclass);


--
-- Name: tile_attempt_events id; Type: DEFAULT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tile_attempt_events ALTER COLUMN id SET DEFAULT nextval('territory.tile_attempt_events_id_seq'::regclass);


--
-- Name: tile_claim_events id; Type: DEFAULT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tile_claim_events ALTER COLUMN id SET DEFAULT nextval('territory.tile_claim_events_id_seq'::regclass);


--
-- Data for Name: global_tiles; Type: TABLE DATA; Schema: activity; Owner: postgres
--

COPY activity.global_tiles (geohash, "precision", owner_user_id, claimed_at, last_run_id) FROM stdin;
kzf0tuu	7	1	2026-02-01 23:48:09.742402+03	7
\.


--
-- Data for Name: run_points; Type: TABLE DATA; Schema: activity; Owner: postgres
--

COPY activity.run_points (id, run_id, "position", recorded_at, accuracy_m) FROM stdin;
2	5	0101000020E61000008C4AEA0434694240EA95B20C71ACF4BF	2026-01-23 11:01:12.123+03	5.2
3	5	0101000020E6100000F0A7C64B376942405B423EE8D9ACF4BF	2026-01-23 11:01:14.123+03	4.8
12	6	0101000020E61000008C4AEA0434694240EA95B20C71ACF4BF	2026-01-30 12:00:00+03	5
13	6	0101000020E6100000D3F6AFAC34694240CD1E680586ACF4BF	2026-01-30 12:00:05+03	5
14	6	0101000020E61000003E7958A835694240226C787AA5ACF4BF	2026-01-30 12:00:10+03	5
29	7	0101000020E61000008C4AEA0434694240EA95B20C71ACF4BF	2026-01-30 19:21:10+03	5
30	7	0101000020E6100000F7CC920035694240CD1E680586ACF4BF	2026-01-30 19:21:12+03	5
31	7	0101000020E6100000614F3BFC35694240226C787AA5ACF4BF	2026-01-30 19:21:16+03	6
40	8	0101000020E61000008C4AEA0434694240EA95B20C71ACF4BF	2026-01-30 10:00:00+03	5
41	8	0101000020E61000007E1D386744694240EA95B20C71ACF4BF	2026-01-30 10:00:10+03	5
42	8	0101000020E61000006FF085C954694240EA95B20C71ACF4BF	2026-01-30 10:00:20+03	5
43	8	0101000020E610000061C3D32B65694240EA95B20C71ACF4BF	2026-01-30 10:00:30+03	5
44	9	0101000020E61000008C4AEA0434694240EA95B20C71ACF4BF	2026-02-14 13:00:00+03	5
45	9	0101000020E61000003E7958A835694240B1BFEC9E3CACF4BF	2026-02-14 13:00:05+03	5
46	9	0101000020E6100000F0A7C64B3769424079E9263108ACF4BF	2026-02-14 13:00:10+03	5
47	9	0101000020E6100000A1D634EF38694240401361C3D3ABF4BF	2026-02-14 13:00:15+03	5
48	9	0101000020E61000005305A3923A694240083D9B559FABF4BF	2026-02-14 13:00:20+03	5
49	10	0101000020E61000008C4AEA0434694240EA95B20C71ACF4BF	2026-02-14 13:00:00+03	5
50	10	0101000020E61000003E7958A835694240B1BFEC9E3CACF4BF	2026-02-14 13:00:05+03	5
51	10	0101000020E6100000F0A7C64B3769424079E9263108ACF4BF	2026-02-14 13:00:10+03	5
52	10	0101000020E6100000A1D634EF38694240401361C3D3ABF4BF	2026-02-14 13:00:15+03	5
53	10	0101000020E61000005305A3923A694240083D9B559FABF4BF	2026-02-14 13:00:20+03	5
\.


--
-- Data for Name: run_tiles; Type: TABLE DATA; Schema: activity; Owner: postgres
--

COPY activity.run_tiles (id, run_id, geohash, first_seen_at, "precision") FROM stdin;
1	6	kzf0tuu	2026-01-30 11:36:01.09914+03	5
2	7	kzf0tuu	2026-02-01 23:04:03.014987+03	7
5	9	kzf0tuu	2026-02-15 23:20:12.528188+03	7
9	9	kzf0tuv	2026-02-15 23:20:12.528188+03	7
10	10	kzf0tuu	2026-02-15 23:44:49.816883+03	7
14	10	kzf0tuv	2026-02-15 23:44:49.816883+03	7
\.


--
-- Data for Name: runs; Type: TABLE DATA; Schema: activity; Owner: postgres
--

COPY activity.runs (id, user_id, started_at, ended_at, status, created_at, total_distance_m, duration_s, run_area_m2) FROM stdin;
3	1	2026-01-23 00:46:07.908746+03	2026-01-23 12:53:22.631+03	completed	2026-01-23 00:46:07.908746+03	0	43634	\N
4	1	2026-01-24 09:46:17.782701+03	2026-01-24 23:14:30.213502+03	completed	2026-01-24 09:46:17.782701+03	0	\N	\N
5	1	2026-01-24 23:16:08.427109+03	2026-01-26 23:12:00.015701+03	completed	2026-01-24 23:16:08.427109+03	0	\N	\N
2	1	2026-01-22 23:39:43.746203+03	2026-01-24 10:08:42.972976+03	completed	2026-01-22 23:39:43.746203+03	0	\N	\N
6	1	2026-01-30 10:50:34.011702+03	\N	completed	2026-01-30 10:50:34.011702+03	1100	\N	\N
7	1	2026-02-01 22:26:19.81379+03	\N	completed	2026-02-01 22:26:19.81379+03	1400	\N	\N
8	1	2026-01-30 10:00:00+03	\N	completed	2026-02-06 09:23:14.325482+03	0	\N	\N
9	1	2026-02-15 23:18:58.954176+03	2026-02-15 23:20:41.191+03	completed	2026-02-15 23:18:58.954176+03	31.37678529114745	102	\N
10	1	2026-02-15 23:44:12.604398+03	2026-02-15 23:45:05.524+03	completed	2026-02-15 23:44:12.604398+03	31.37678529114745	52	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.users (id, username, email, password_hash, is_active, created_at, updated_at) FROM stdin;
1	testuser	test@paceke.dev	hashed-password	t	2026-01-22 23:35:54.719896+03	2026-01-22 23:35:54.719896+03
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: territory_tiles; Type: TABLE DATA; Schema: territory; Owner: postgres
--

COPY territory.territory_tiles (tile_geohash, "precision", owner_user_id, strength_distance_m, last_claimed_at) FROM stdin;
\.


--
-- Data for Name: tile_attempt_events; Type: TABLE DATA; Schema: territory; Owner: postgres
--

COPY territory.tile_attempt_events (id, tile_geohash, "precision", user_id, run_id, attempt_strength_m, attempted_at) FROM stdin;
\.


--
-- Data for Name: tile_claim_events; Type: TABLE DATA; Schema: territory; Owner: postgres
--

COPY territory.tile_claim_events (id, tile_geohash, "precision", user_id, run_id, strength_distance_m, claimed_at) FROM stdin;
\.


--
-- Data for Name: tile_ownership; Type: TABLE DATA; Schema: territory; Owner: postgres
--

COPY territory.tile_ownership (tile_id, owner_user_id, claimed_at, avg_speed_mps) FROM stdin;
\.


--
-- Data for Name: tiles; Type: TABLE DATA; Schema: territory; Owner: postgres
--

COPY territory.tiles (id, geohash, geom, created_at) FROM stdin;
\.


--
-- Name: run_points_id_seq; Type: SEQUENCE SET; Schema: activity; Owner: postgres
--

SELECT pg_catalog.setval('activity.run_points_id_seq', 53, true);


--
-- Name: run_tiles_id_seq; Type: SEQUENCE SET; Schema: activity; Owner: postgres
--

SELECT pg_catalog.setval('activity.run_tiles_id_seq', 14, true);


--
-- Name: runs_id_seq; Type: SEQUENCE SET; Schema: activity; Owner: postgres
--

SELECT pg_catalog.setval('activity.runs_id_seq', 10, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: postgres
--

SELECT pg_catalog.setval('auth.users_id_seq', 2, true);


--
-- Name: tile_attempt_events_id_seq; Type: SEQUENCE SET; Schema: territory; Owner: postgres
--

SELECT pg_catalog.setval('territory.tile_attempt_events_id_seq', 1, false);


--
-- Name: tile_claim_events_id_seq; Type: SEQUENCE SET; Schema: territory; Owner: postgres
--

SELECT pg_catalog.setval('territory.tile_claim_events_id_seq', 1, false);


--
-- Name: tiles_id_seq; Type: SEQUENCE SET; Schema: territory; Owner: postgres
--

SELECT pg_catalog.setval('territory.tiles_id_seq', 1, false);


--
-- Name: global_tiles global_tiles_geohash_precision_unique; Type: CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.global_tiles
    ADD CONSTRAINT global_tiles_geohash_precision_unique UNIQUE (geohash, "precision");


--
-- Name: global_tiles global_tiles_pkey; Type: CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.global_tiles
    ADD CONSTRAINT global_tiles_pkey PRIMARY KEY (geohash);


--
-- Name: run_points run_points_pkey; Type: CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.run_points
    ADD CONSTRAINT run_points_pkey PRIMARY KEY (id);


--
-- Name: run_tiles run_tiles_pkey; Type: CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.run_tiles
    ADD CONSTRAINT run_tiles_pkey PRIMARY KEY (id);


--
-- Name: run_tiles run_tiles_run_id_geohash_key; Type: CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.run_tiles
    ADD CONSTRAINT run_tiles_run_id_geohash_key UNIQUE (run_id, geohash);


--
-- Name: runs runs_pkey; Type: CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.runs
    ADD CONSTRAINT runs_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: territory_tiles territory_tiles_pkey; Type: CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.territory_tiles
    ADD CONSTRAINT territory_tiles_pkey PRIMARY KEY (tile_geohash);


--
-- Name: tile_attempt_events tile_attempt_events_pkey; Type: CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tile_attempt_events
    ADD CONSTRAINT tile_attempt_events_pkey PRIMARY KEY (id);


--
-- Name: tile_claim_events tile_claim_events_pkey; Type: CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tile_claim_events
    ADD CONSTRAINT tile_claim_events_pkey PRIMARY KEY (id);


--
-- Name: tile_ownership tile_ownership_pkey; Type: CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tile_ownership
    ADD CONSTRAINT tile_ownership_pkey PRIMARY KEY (tile_id);


--
-- Name: tiles tiles_geohash_key; Type: CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tiles
    ADD CONSTRAINT tiles_geohash_key UNIQUE (geohash);


--
-- Name: tiles tiles_pkey; Type: CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tiles
    ADD CONSTRAINT tiles_pkey PRIMARY KEY (id);


--
-- Name: idx_global_tiles_claimed_at; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE INDEX idx_global_tiles_claimed_at ON activity.global_tiles USING btree (claimed_at);


--
-- Name: idx_global_tiles_owner; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE INDEX idx_global_tiles_owner ON activity.global_tiles USING btree (owner_user_id);


--
-- Name: idx_run_tiles_geohash; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE INDEX idx_run_tiles_geohash ON activity.run_tiles USING btree (geohash);


--
-- Name: one_active_run_per_user; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE UNIQUE INDEX one_active_run_per_user ON activity.runs USING btree (user_id) WHERE (status = 'in_progress'::public.run_status);


--
-- Name: run_points_position_idx; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE INDEX run_points_position_idx ON activity.run_points USING gist ("position");


--
-- Name: run_points_run_id_idx; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE INDEX run_points_run_id_idx ON activity.run_points USING btree (run_id);


--
-- Name: run_tiles_geohash_idx; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE INDEX run_tiles_geohash_idx ON activity.run_tiles USING btree (geohash);


--
-- Name: run_tiles_run_geohash_uq; Type: INDEX; Schema: activity; Owner: postgres
--

CREATE UNIQUE INDEX run_tiles_run_geohash_uq ON activity.run_tiles USING btree (run_id, geohash);


--
-- Name: global_tiles global_tiles_last_run_id_fkey; Type: FK CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.global_tiles
    ADD CONSTRAINT global_tiles_last_run_id_fkey FOREIGN KEY (last_run_id) REFERENCES activity.runs(id);


--
-- Name: run_points run_points_run_id_fkey; Type: FK CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.run_points
    ADD CONSTRAINT run_points_run_id_fkey FOREIGN KEY (run_id) REFERENCES activity.runs(id);


--
-- Name: run_tiles run_tiles_run_id_fkey; Type: FK CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.run_tiles
    ADD CONSTRAINT run_tiles_run_id_fkey FOREIGN KEY (run_id) REFERENCES activity.runs(id) ON DELETE CASCADE;


--
-- Name: runs runs_user_id_fkey; Type: FK CONSTRAINT; Schema: activity; Owner: postgres
--

ALTER TABLE ONLY activity.runs
    ADD CONSTRAINT runs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: tile_ownership tile_ownership_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tile_ownership
    ADD CONSTRAINT tile_ownership_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id);


--
-- Name: tile_ownership tile_ownership_tile_id_fkey; Type: FK CONSTRAINT; Schema: territory; Owner: postgres
--

ALTER TABLE ONLY territory.tile_ownership
    ADD CONSTRAINT tile_ownership_tile_id_fkey FOREIGN KEY (tile_id) REFERENCES territory.tiles(id);


--
-- Name: SCHEMA activity; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA activity TO paceke;


--
-- Name: SCHEMA auth; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA auth TO paceke;


--
-- Name: SCHEMA territory; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA territory TO paceke;


--
-- Name: TABLE global_tiles; Type: ACL; Schema: activity; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE activity.global_tiles TO paceke;


--
-- Name: TABLE run_points; Type: ACL; Schema: activity; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE activity.run_points TO paceke;


--
-- Name: SEQUENCE run_points_id_seq; Type: ACL; Schema: activity; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE activity.run_points_id_seq TO paceke;


--
-- Name: TABLE run_tiles; Type: ACL; Schema: activity; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE activity.run_tiles TO paceke;


--
-- Name: SEQUENCE run_tiles_id_seq; Type: ACL; Schema: activity; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE activity.run_tiles_id_seq TO paceke;


--
-- Name: TABLE runs; Type: ACL; Schema: activity; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE activity.runs TO paceke;


--
-- Name: SEQUENCE runs_id_seq; Type: ACL; Schema: activity; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE activity.runs_id_seq TO paceke;


--
-- Name: TABLE users; Type: ACL; Schema: auth; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE auth.users TO paceke;


--
-- Name: SEQUENCE users_id_seq; Type: ACL; Schema: auth; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE auth.users_id_seq TO paceke;


--
-- Name: TABLE territory_tiles; Type: ACL; Schema: territory; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE territory.territory_tiles TO paceke;


--
-- Name: TABLE tile_attempt_events; Type: ACL; Schema: territory; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE territory.tile_attempt_events TO paceke;


--
-- Name: TABLE tile_claim_events; Type: ACL; Schema: territory; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE territory.tile_claim_events TO paceke;


--
-- Name: TABLE tile_ownership; Type: ACL; Schema: territory; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE territory.tile_ownership TO paceke;


--
-- Name: TABLE tiles; Type: ACL; Schema: territory; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE territory.tiles TO paceke;


--
-- Name: SEQUENCE tiles_id_seq; Type: ACL; Schema: territory; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE territory.tiles_id_seq TO paceke;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: activity; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA activity GRANT SELECT,USAGE ON SEQUENCES TO paceke;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: activity; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA activity GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO paceke;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: auth; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA auth GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO paceke;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: territory; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA territory GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO paceke;


--
-- PostgreSQL database dump complete
--

\unrestrict jkdEGnqRZha66DXU63WacjH5kdiZd6d5PxINAKtu6vdR7kzpzF8eGHp7HuQaiMF


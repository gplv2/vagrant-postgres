CREATE ROLE super_test WITH SUPERUSER CREATEROLE CREATEDB LOGIN PASSWORD 'Snowball1' VALID UNTIL 'infinity';
CREATE ROLE test WITH SUPERUSER CREATEROLE CREATEDB LOGIN PASSWORD 'Iceball1' VALID UNTIL 'infinity';

CREATE ROLE pgc;
ALTER ROLE pgc WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS;

CREATE ROLE pgbouncer LOGIN PASSWORD 'GedOydNi1Swik' VALID UNTIL 'infinity';
-- CREATE ROLE pgbouncer LOGIN PASSWORD 'md54cf2e80a8a9921c588dfe9644fc6a076' VALID UNTIL 'infinity';

\c template1
CREATE FUNCTION pg_catalog.user_search (
   INOUT p_user name,
   OUT   p_password text
) RETURNS record
   LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS
$$SELECT usename, passwd FROM pg_shadow WHERE usename = p_user$$;

-- make sure only "pgbouncer" can use the function
REVOKE EXECUTE ON FUNCTION pg_catalog.user_search(name) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_catalog.user_search(name) TO pgbouncer;

CREATE DATABASE powa WITH TEMPLATE = template1 OWNER = postgres;
\c powa
CREATE EXTENSION pg_stat_statements;
CREATE EXTENSION btree_gist;
-- CREATE EXTENSION powa;
CREATE EXTENSION pg_qualstats;
-- CREATE EXTENSION pg_stat_kcache;

\c template1

CREATE DATABASE testdb WITH TEMPLATE = template1 OWNER = test;
\c test
CREATE EXTENSION IF NOT EXISTS pg_repack WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS hostname WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS hypopg WITH SCHEMA public;
-- CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
-- CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
-- CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
-- CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;
-- CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;




CREATE OR REPLACE FUNCTION atsort( a text[])
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE  STRICT
AS $function$
  select array(select unnest($1) order by 1)
$function$

;



create server localredis foreign data wrapper redis_fdw;

create user mapping for public server localredis;

-- tables for all 5 data types (4 structured plus scalar)

create foreign table db15(key text, value text) 
       server localredis 
       options (database '15');

create foreign table db15h(key text, value text) 
       server localredis 
       options (database '15', tabletype 'hash');

create foreign table db15s(key text, value text) 
       server localredis 
       options (database '15', tabletype 'set');

create foreign table db15l(key text, value text) 
       server localredis 
       options (database '15', tabletype 'list');

create foreign table db15z(key text, value text) 
       server localredis 
       options (database '15', tabletype 'zset');

-- make sure they are all empty - if any are not stop the script right now

\set ON_ERROR_STOP 
do $$
  declare
    rows bigint;
  begin 
    select into rows 
        (select count(*) from db15) +
        (select count(*) from db15h) +
        (select count(*) from db15s) +
        (select count(*) from db15l) +
        (select count(*) from db15z);
    if rows > 0
    then
       raise EXCEPTION 'db 15 not empty';
    end if;
  end;
$$;
\unset ON_ERROR_STOP


-- ok, empty, so now run the setup script

\! redis-cli < test/sql/redis_setup

select * from db15 order by key;

select * from db15 where key = 'foo';

-- hash

create foreign table db15hp(key text, value text) 
       server localredis 
       options (tabletype 'hash', tablekeyprefix 'hash', database '15');

create foreign table db15hpa(key text, value text[]) 
       server localredis 
       options (tabletype 'hash', tablekeyprefix 'hash', database '15');

create foreign table db15hsa(key text, value text[]) 
       server localredis 
       options (tabletype 'hash', tablekeyset 'hkeys', database '15');

select * from db15hp order by key;
select * from db15hp where key = 'hash1';

select * from db15hpa order by key;
select * from db15hpa where key = 'hash1';

select * from db15hsa order by key;
select * from db15hsa where key = 'hash1';

-- a couple of nifty things we an do with hash tables

select key, hstore(value) from db15hpa order by key;

create type atab as (k1 text, k2 text, k3 text);

select key, (populate_record(null::atab, hstore(value))).* 
from db15hpa
order by key;

-- set

create foreign table db15sp(key text, value text) 
       server localredis 
       options (tabletype 'set', tablekeyprefix 'set', database '15');

create foreign table db15spa(key text, value text[]) 
       server localredis 
       options (tabletype 'set', tablekeyprefix 'set', database '15');

create foreign table db15ssa(key text, value text[]) 
       server localredis 
       options (tabletype 'set', tablekeyset 'skeys', database '15');

-- need to use atsort() on set results to get predicable output
-- since redis will give them back in arbitrary order
-- means we can't show the actual value for db15sp which has it as a 
-- single text field

select key, atsort(value::text[]) as value from db15sp order by key;
select key, atsort(value::text[]) as value from db15sp where key = 'set1';

select key, atsort(value) as value from db15spa order by key;
select key, atsort(value) as value from db15spa where key = 'set1';

select key, atsort(value) as value from db15ssa order by key;
select key, atsort(value) as value from db15ssa where key = 'set1';

-- list

create foreign table db15lp(key text, value text) 
       server localredis 
       options (tabletype 'list', tablekeyprefix 'list', database '15');

create foreign table db15lpa(key text, value text[]) 
       server localredis 
       options (tabletype 'list', tablekeyprefix 'list', database '15');

create foreign table db15lsa(key text, value text[]) 
       server localredis 
       options (tabletype 'list', tablekeyset 'lkeys', database '15');

select * from db15lp order by key;
select * from db15lp where key = 'list1';

select * from db15lpa order by key;
select * from db15lpa where key = 'list1';

select * from db15lsa order by key;
select * from db15lsa where key = 'list1';

-- zset

create foreign table db15zp(key text, value text) 
       server localredis 
       options (tabletype 'zset', tablekeyprefix 'zset', database '15');

create foreign table db15zpa(key text, value text[]) 
       server localredis 
       options (tabletype 'zset', tablekeyprefix 'zset', database '15');

create foreign table db15zsa(key text, value text[]) 
       server localredis 
       options (tabletype 'zset', tablekeyset 'zkeys', database '15');

select * from db15zp order by key;
select * from db15zp where key = 'zset1';

select * from db15zpa order by key;
select * from db15zpa where key = 'zset1';

select * from db15zsa order by key;
select * from db15zsa where key = 'zset1';

-- singleton scalar

create foreign table db15g(value text) 
       server localredis 
       options (singleton_key 'foo', database '15');

select * from db15g;

-- singleton hash

create foreign table db15gh(key text, value text) 
       server localredis 
       options (tabletype 'hash', singleton_key 'hash1', database '15');

select * from db15gh order by key;


-- singleton set

create foreign table db15gs(value text) 
       server localredis 
       options (tabletype 'set', singleton_key 'set1', database '15');

select * from db15gs order by value;


-- singleton list

create foreign table db15gl(value text) 
       server localredis 
       options (tabletype 'list', singleton_key 'list1', database '15');

select * from db15gl order by value;


-- singleton zset

create foreign table db15gz(value text) 
       server localredis 
       options (tabletype 'zset', singleton_key 'zset1', database '15');

select * from db15gz order by value;


-- singleton zset with scores

create foreign table db15gzs(value text, score numeric) 
       server localredis 
       options (tabletype 'zset', singleton_key 'zset1', database '15');

select * from db15gzs order by score desc;





-- all done,so now blow everything in the db away agan

\! redis-cli < test/sql/redis_clean


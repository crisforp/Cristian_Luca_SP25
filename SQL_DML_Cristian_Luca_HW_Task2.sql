/*Task2
Note: 
Make sure to turn autocommit on in connection settings before attempting the following tasks.
Otherwise you might get an error at some point.*/


-- Task 2.1 
-- Create table ‘table_to_delete’ and fill it 

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;

-- 10000000 rows updated - 15,362s

--Task 2.2 
-- Lookup how much space this table consumes 

SELECT *, 
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS INDEX,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS TABLE
FROM ( 
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes,0) AS table_bytes
    FROM (
        SELECT c.oid, nspname AS table_schema, relname AS table_name, 
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

/*total space used     index        toast           table
   575MB                 0 bytes      8192 bytes   575MB*/

-- Task 2.3
-- Issue the following DELETE operation on ‘table_to_delete’


DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;

-- 3333333 rows updated - 11,376s

VACUUM FULL VERBOSE table_to_delete;

-- vacuuming "public.table_to_delete"
-- "table_to_delete": found 0 removable, 6666667 nonremovable row versions in 73530 pages

-- 0 rows updated - 22ms

-- remove about 1/3 of the rows

-- rrepeat Task 2.2 

/*total space used      index        toast            table
   383MB                  0 bytes       8192 bytes   383MB*/

DROP TABLE table_to_delete;

-- 0 rows updated - 5ms

-- repeat Task 2.1


-- Task 2.4 
--  Issue the following TRUNCATE operation:

TRUNCATE table_to_delete;

--  0 rows updated - 1,54s

-- repeat Task 2.2 

/*Total           index     toast           table
8192 bytes   0 bytes    8192 bytes  0 bytes*/

-- the space is freed immediately without needing VACUUM FULL


-- Task 2.5 
/*Hand over your investigation's results to your trainer. The results must include:
      a) Space consumption of ‘table_to_delete’ table before and after each operation;
      b) Duration of each operation (DELETE, TRUNCATE)*/

/*
Comparison 

Step                             Space usage         Time (seconds)            Comments
After create table            575MB                15,362s                       full table with 10 milions rows
After DELETE               575MB               11,376s                       deleted 1/3 rows; space stays the same
After VACUUM FULL   383MB                5,157s                        space psihically reduced
After TRUNCATE         8192bytes            1,54s                          space freed immediately 

TRUNCATE is the fastest  because drops the entire table content immediately and resets its storage without processing individual rows.
*/



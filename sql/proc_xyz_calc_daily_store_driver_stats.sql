xyz_calc_daily_store_driver_stats	NO_ENGINE_SUBSTITUTION	CREATE DEFINER=`lextech`@`%` PROCEDURE `xyz_calc_daily_store_driver_stats`(IN currentDate date, IN cleanerId int)
BEGIN

DECLARE errorcode char (5);
DECLARE msg TEXT;
DECLARE recordCount int(11);

DECLARE exit handler for SQLEXCEPTION
	Begin		
		/* drop all temp tables if they already exist - here for precaustion only*/
        GET DIAGNOSTICS CONDITION 1
			errorcode = RETURNED_SQLSTATE, msg = MESSAGE_TEXT;
		SELECT errorcode, msg;
		DROP TEMPORARY table IF EXISTS tempCleanerIDS;
		DROP TEMPORARY table IF EXISTS tempSubCleanerIDS;
        DROP TEMPORARY table IF EXISTS tempCleanerDriverStats;
	End;

DROP TEMPORARY table IF EXISTS tempCleanerIDS;
DROP TEMPORARY table IF EXISTS tempSubCleanerIDS;
DROP TEMPORARY table IF EXISTS tempCleanerDriverStats;


IF currentDate IS NULL then
	SET currentDate = CURDATE();
end if;

CREATE TEMPORARY TABLE tempCleanerIDS (cleaner_id int(11)) ENGINE=MEMORY;
CREATE TEMPORARY TABLE tempSubCleanerIDS (cleaner_id int(11)) ENGINE=MEMORY;

IF cleanerId IS NULL then
	insert into tempCleanerIDS
    select distinct cleaner_id 
      from orders o JOIN exchanges exch on exch.order_id = o.id
                JOIN trips ON exch.trip_id = trips.id
                JOIN users u ON trips.dryver_id = u.id
            WHERE exch.type in ('DELIVERY', 'PICKUP')
				 AND DATE_FORMAT(cast(trips.scheduled as date), '%Y-%m-%d') = currentDate;
else
	insert into tempCleanerIDS values (cleanerId);
end if;

set recordCount = (select count(*) from tempCleanerIDS);

/* if no orders and transactions for the current date then still insert records into cleaner_daily_stats for each cleaner with zero values */
IF recordCount = 0 THEN
		insert into cleaner_daily_driver_stats_1902
		(cleaner_id, cleaner_date, driver_id)
		select distinct id, currentDate, 0
			from cleaners c
			where c.status = 'Active' and c.name <> 'Production Test Cleaners'
              and not exists (select * from cleaners c2 join cleaner_daily_driver_stats_1902 cdds on c2.id = cdds.cleaner_id and cdds.cleaner_date = currentDate);
END IF;

CREATE TEMPORARY TABLE tempCleanerDriverStats (
	cleaner_id int(11) NOT NULL,
	cleaner_date date  NULL,
	driver_id int(11) NOT NULL,
	record_exists int(11) NULL default 0, 
	driver_name varchar(256) NOT NULL,
	actual_pickup_stops_cnt int(11) DEFAULT '0',
	actual_dropoff_stops_cnt int(11) DEFAULT '0',
	actual_skipped_by_driver_cnt int(11) DEFAULT '0'
) ENGINE=MEMORY;


insert into tempCleanerDriverStats (cleaner_id, cleaner_date, driver_id, driver_name)
SELECT distinct o.cleaner_id, currentDate, trips.dryver_id, CONCAT(u.first_name,' ',u.last_name)
            FROM  tempCleanerIDS tci join orders o on tci.cleaner_id = o.cleaner_id 
				JOIN exchanges exch on exch.order_id = o.id
                JOIN trips ON exch.trip_id = trips.id
                JOIN users u ON trips.dryver_id = u.id
            WHERE exch.type in ('DELIVERY', 'PICKUP')
             and  DATE_FORMAT(cast(trips.scheduled as date), '%Y-%m-%d') = currentDate;
                          
/* actual_pickup_stops_cnt */
UPDATE tempCleanerDriverStats tcds 
SET 
    actual_pickup_stops_cnt = (SELECT 
            COUNT(*)
        FROM
            orders o
                JOIN
            exchanges exch ON exch.order_id = o.id
                JOIN
            trips ON exch.trip_id = trips.id
                JOIN
            users u ON trips.dryver_id = u.id
        WHERE
            exch.type = 'PICKUP'
                /* AND exch.status NOT IN ('NO SHOW') || Client asked to change*/
                AND exch.status in ('COMPLETE')
                AND DATE_FORMAT(CAST(trips.scheduled AS DATE),
                    '%Y-%m-%d') = currentDate
                AND o.cleaner_id = tcds.cleaner_id
                AND trips.dryver_id = tcds.driver_id);
             

/* actual_dropoff_stops_cnt */
UPDATE tempCleanerDriverStats tcds 
SET 
    actual_dropoff_stops_cnt = (SELECT 
            COUNT(*)
        FROM
            orders o
                JOIN
            exchanges exch ON exch.order_id = o.id
                JOIN
            trips ON exch.trip_id = trips.id
                JOIN
            users u ON trips.dryver_id = u.id
        WHERE
            exch.type = 'DELIVERY'
                /* AND exch.status NOT IN ('NO SHOW') || Client asked to change*/
                AND exch.status in ('COMPLETE')
                AND DATE_FORMAT(CAST(trips.scheduled AS DATE),
                    '%Y-%m-%d') = currentDate
                AND o.cleaner_id = tcds.cleaner_id
                AND trips.dryver_id = tcds.driver_id);



/* actual_skipped_by_driver_cnt */
UPDATE tempCleanerDriverStats tcds 
SET 
    actual_skipped_by_driver_cnt = (SELECT 
            COUNT(*)
        FROM
            orders o
                JOIN
            exchanges exch ON exch.order_id = o.id
                JOIN
            trips ON exch.trip_id = trips.id
        WHERE
            exch.type IN ('DELIVERY' , 'PICKUP')
                AND exch.status IN ('NO SHOW')
                AND DATE_FORMAT(CAST(trips.scheduled AS DATE),
                    '%Y-%m-%d') = currentDate
                AND o.cleaner_id = tcds.cleaner_id
                AND trips.dryver_id = tcds.driver_id);

UPDATE tempCleanerDriverStats tcds 
SET 
    record_exists = (SELECT 
            COUNT(*)
        FROM
            cleaner_daily_driver_stats_1902 cdds
        WHERE
            tcds.cleaner_id = cdds.cleaner_id
                AND tcds.cleaner_date = cdds.cleaner_date
                AND tcds.driver_id = cdds.driver_id);

    
    
insert into cleaner_daily_driver_stats_1902
(cleaner_id, cleaner_date, driver_id, driver_name,
	actual_pickup_stops_cnt, actual_dropoff_stops_cnt, actual_skipped_by_driver_cnt)
select cleaner_id, cleaner_date,  driver_id, driver_name,
			IFNULL(actual_pickup_stops_cnt, 0), IFNULL(actual_dropoff_stops_cnt, 0), IFNULL(actual_skipped_by_driver_cnt, 0)
    from tempCleanerDriverStats 
    where record_exists = 0;
    
UPDATE cleaner_daily_driver_stats_1902 cdds,
    tempCleanerDriverStats tcds 
SET 
    cdds.driver_name = IFNULL(tcds.driver_name, 0),
    cdds.actual_pickup_stops_cnt = IFNULL(tcds.actual_pickup_stops_cnt, 0),
    cdds.actual_dropoff_stops_cnt = IFNULL(tcds.actual_dropoff_stops_cnt, 0),
    cdds.actual_skipped_by_driver_cnt = IFNULL(tcds.actual_skipped_by_driver_cnt, 0)
WHERE
    cdds.cleaner_id = tcds.cleaner_id
        AND cdds.cleaner_date = tcds.cleaner_date
        AND cdds.driver_id = tcds.driver_id
        AND tcds.record_exists = 1;
        

drop TEMPORARY table IF EXISTS tempCleanerIDS;
drop TEMPORARY table IF EXISTS tempSubCleanerIDS;
drop TEMPORARY table IF EXISTS tempCleanerDriverStats;

SELECT 0;


END	utf8	utf8_general_ci	latin1_swedish_ci

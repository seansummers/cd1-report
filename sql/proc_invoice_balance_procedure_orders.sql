invoice_balance_procedure_orders	STRICT_TRANS_TABLES	CREATE DEFINER=`lextech`@`%` PROCEDURE `invoice_balance_procedure_orders`(IN currentDate date, IN cleanerId int)
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
        DROP TEMPORARY TABLE IF EXISTS tempProcedureOrders;
	End;
    
DROP TEMPORARY TABLE IF EXISTS tempProcedureOrders;

IF currentDate IS NULL then
	SET currentDate = CURDATE();
end if;


CREATE TEMPORARY TABLE tempProcedureOrders (
	cleanerId int(11),
    user_name varchar(255),
    order_id int(11),
	delivery_date varchar(12),
    transaction_status varchar(30),
    billing_amount decimal(10, 2),
    collected_amount decimal(10, 2),
    difference decimal(10, 2),
    refund decimal(10, 2),
    refund_comment varchar(256),
    promo_amount decimal(10, 2),
    payout_id int(11),
    payout_date varchar(12),
    is_order_placed_under_subs_plan_id varchar(10),
	record_exists int(2)
) ENGINE=MEMORY;

CREATE TABLE IF NOT EXISTS invoice_balance_orders_report(
	id int(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    cleanerId int(11),
    user_name varchar(255),
    order_id int(11),
	delivery_date varchar(12),
    transaction_status varchar(30),
    billing_amount decimal(10, 2),
    collected_amount decimal(10, 2),
    difference decimal(10, 2),
    refund decimal(10, 2),
    refund_comment varchar(256),
    promo_amount decimal(10, 2),
    payout_id int(11),
    payout_date varchar(12),
    is_order_placed_under_subs_plan_id varchar(10)
);

INSERT INTO tempProcedureOrders (
    cleanerId,
    user_name,
    order_id,
	delivery_date,
    transaction_status,
    billing_amount,
    collected_amount,
    difference,
    promo_amount,
    payout_id,
    payout_date,
    is_order_placed_under_subs_plan_id
)
SELECT
		`o`.`cleaner_id`,
		CONCAT(`u`.`first_name`, ' ', `u`.`last_name`),
		`o`.`id`,
        DATE_FORMAT(cast(CONVERT_TZ(`t`.`actual`, 'UTC', 'CST6CDT') as date), '%Y-%m-%d'),
        IFNULL(`tr`.`status`, 'misbilled'),
        `vor`.`DeliveredAmount`,
        `vor`.`ChargedAmount`,
        `vor`.`DeliveredAmount` - `vor`.`ChargedAmount`,
        `vor`.`CouponApplied`,
        `tr`.`payout_id`,
        DATE_FORMAT(CAST(`tr`.`payout_date` as DATE), '%Y-%m-%d'),
        CASE
			WHEN `p`.`programId` IN (1, 2) THEN 'YES'
            ELSE 'NO'
		END
	FROM `orders` `o`
	JOIN `transactions` `tr` ON `tr`.`order_id` = `o`.`id`
	JOIN `user_plan` `up` ON `up`.`customerId` = `o`.`user_id`
	JOIN `plans` `p` ON `p`.`id` = `up`.`planId`
	JOIN `users` `u` ON `u`.`id` = `o`.`user_id`
    JOIN `order_report` `vor` ON `vor`.`OrderId` = `o`.`id`
    JOIN `exchanges` `ex` ON `ex`.`order_id` = `o`.`id`
    JOIN `trips` `t` ON `ex`.`trip_id` = `t`.`id`
	WHERE `tr`.`parent_id` IS NULL
		AND `tr`.`amount` > '0'
        AND `o`.`cleaner_id` = cleanerId
        AND `o`.`status` = 'DELIVERED'
        AND DATE_FORMAT(cast(CONVERT_TZ(`t`.`actual`, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') BETWEEN DATE_ADD(currentDate, INTERVAL -10 DAY) AND DATE_FORMAT(cast(CONVERT_TZ(currentDate, 'UTC', 'CST6CDT') as date), '%Y-%m-%d')
	GROUP BY `o`.`id`;
    
UPDATE tempProcedureOrders tpo
SET refund = (SELECT 
            IFNULL(SUM(`tran`.`amount` / 100), 0) - IFNULL(SUM(`tran`.`tax` / 100), 0)
        FROM
            `orders` `o`
                JOIN
            `transactions` `tran` ON `o`.`id` = `tran`.`order_id`
        WHERE
            `o`.`cleaner_id` = cleanerId
				AND `tpo`.`order_id` = `o`.`id`
                AND `tran`.`type` LIKE '%Refund%'
                AND `tran`.`status` IN ('COMPLETE')
                AND DATE_FORMAT(cast(CONVERT_TZ(`tran`.`created`, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = `tpo`.`delivery_date`
);

UPDATE tempProcedureOrders tpo
SET refund_comment = (SELECT 
          `tran`.`notes`
        FROM
            `orders` `o`
                JOIN
            `transactions` `tran` ON `o`.`id` = `tran`.`order_id`
        WHERE
            `o`.`cleaner_id` = cleanerId
				AND `tpo`.`order_id` = `o`.`id`
                AND `tran`.`type` LIKE '%Refund%'
                AND `tran`.`status` IN ('COMPLETE')
                AND DATE_FORMAT(cast(CONVERT_TZ(`tran`.`created`, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = `tpo`.`delivery_date`
);

UPDATE tempProcedureOrders tpo
SET
    record_exists = (SELECT
            COUNT(*)
        FROM
            `invoice_balance_orders_report` `ibor`
        WHERE
            `tpo`.`cleanerId` = `ibor`.`cleanerId`
                AND `tpo`.`order_id` = `ibor`.`order_id`);
                
UPDATE invoice_balance_orders_report ibor,
		tempProcedureOrders tpo
SET 
	ibor.cleanerId = tpo.cleanerId,
    ibor.user_name = tpo.user_name,
    ibor.order_id = tpo.order_id,
	ibor.delivery_date = tpo.delivery_date,
    ibor.transaction_status = tpo.transaction_status,
    ibor.billing_amount = tpo.billing_amount,
    ibor.collected_amount = tpo.collected_amount,
    ibor.difference = tpo.difference,
    ibor.refund = tpo.refund,
    ibor.refund_comment = tpo.refund_comment,
    ibor.promo_amount = tpo.promo_amount,
    ibor.payout_id = tpo.payout_id,
    ibor.payout_date = tpo.payout_date,
    ibor.is_order_placed_under_subs_plan_id = tpo.is_order_placed_under_subs_plan_id
WHERE
    ibor.cleanerId = tpo.cleanerId
        AND ibor.order_id = tpo.order_id
        AND tpo.record_exists = 1;

INSERT INTO invoice_balance_orders_report(
    cleanerId,
    user_name,
    order_id,
	delivery_date,
    transaction_status,
    billing_amount,
    collected_amount,
    difference,
    refund,
    refund_comment,
    promo_amount,
    payout_id,
    payout_date,
    is_order_placed_under_subs_plan_id
) SELECT
    cleanerId,
    user_name,
    order_id,
	delivery_date,
    transaction_status,
    billing_amount,
    collected_amount,
    difference,
    refund,
    refund_comment,
    promo_amount,
    payout_id,
    payout_date,
    is_order_placed_under_subs_plan_id
FROM tempProcedureOrders WHERE record_exists = 0;
    
drop TEMPORARY table IF EXISTS tempProcedureOrders;

SELECT 0;

END	utf8mb4	utf8mb4_general_ci	latin1_swedish_ci

invoice_balance_procedure_subscriptions		CREATE DEFINER=`lextech`@`%` PROCEDURE `invoice_balance_procedure_subscriptions`(IN currentDate date, IN cleanerId int)
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
        DROP TEMPORARY TABLE IF EXISTS tempProcedureSubscriptions;
        DROP TEMPORARY TABLE IF EXISTS tempBillingAmounts;
	End;
    
DROP TEMPORARY TABLE IF EXISTS tempProcedureSubscriptions;
DROP TEMPORARY TABLE IF EXISTS tempBillingAmounts;

IF currentDate IS NULL then
	SET currentDate = CURDATE();
end if;

CREATE TEMPORARY TABLE tempProcedureSubscriptions (
	id int(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
	cleanerId int(11),
	customerId int(11),
	transaction_id int(11),
	user_plan_used int(11),
    user_name varchar(255),
    billing_date varchar(12),
    transaction_status varchar(30),
    billing_amount decimal(10, 2),
    collected_amount decimal(10, 2),
    difference decimal(10, 2),
    refund decimal(10, 2),
    refund_comment varchar(256),
    promo_amount decimal(10, 2),
    payout_id int(11),
    payout_date varchar(12),
    status_on_first_day varchar(10),
    status_on_last_day varchar(10),
    subscription_during_month varchar(10),
    new_subscription varchar(5),
    lost_subscription varchar(5),
	record_exists int(2)
);

CREATE TEMPORARY TABLE tempBillingAmounts (
	id int(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    customerId int(11),
    billing_amount decimal(10, 2)
);

CREATE TABLE IF NOT EXISTS invoice_balance_subscriptions_report(
	id int(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
	cleanerId int(11),
    customerId int(11),
    transaction_id int(11),
    user_plan_used int(11),
    user_name varchar(255),
    billing_date varchar(12),
    transaction_status varchar(30),
    billing_amount decimal(10, 2),
    collected_amount decimal(10, 2),
    difference decimal(10, 2),
    refund decimal(10, 2),
    refund_comment varchar(256),
    promo_amount decimal(10, 2),
    payout_id int(11),
    payout_date varchar(12),
    status_on_first_day varchar(10),
    status_on_last_day varchar(10),
    subscription_during_month varchar(10),
    new_subscription varchar(5),
    lost_subscription varchar(5)
);

INSERT INTO tempProcedureSubscriptions(
    cleanerId,
    customerId,
    user_plan_used,
    transaction_id,
    user_name,
	billing_date,
    transaction_status,
    promo_amount,
    payout_id,
    payout_date
)
SELECT * FROM (SELECT
		`p`.`storeId`,
        `up`.`customerId`,
        `up`.`id`,
        `st`.`id` as transaction_id,
		CONCAT(`u`.`first_name`, ' ', `u`.`last_name`),
        DATE_FORMAT(CAST(`st`.`created` AS DATE), '%Y-%m-%d'),
		IFNULL(`st`.`status`, 'misbilled'),
		IFNULL((`st`.`promo_amount`) / 100, 0),
        `st`.`payout_id`,
        DATE_FORMAT(CAST(`st`.`payout_date` AS DATE), '%Y-%m-%d')
		FROM `user_plan` `up`
	JOIN `user_plan` `up2` ON `up`.`customerId` = `up2`.`customerId`
	LEFT JOIN `subscription_transactions` `st` ON (`st`.`user_plan_id` = `up`.`id`)
	JOIN `users` `u` ON `u`.`id` = `up`.`customerId`
    JOIN `plans` `p` ON `p`.`id` = `up`.`planId`
	JOIN `plans` `p2` ON `p2`.`id` = `up2`.`planId`
	WHERE `st`.`parent_id` IS NULL
		AND `up`.`deleted_at` IS NULL
		AND ((`st`.`user_plan_id` = `up`.`id`) OR (`up`.`enabled` = '1'))
		AND ((`up`.`effectiveDate` <`up2`.`effectiveDate`) OR (`up2`.`enabled` = '1'))
		AND `p`.`programId` IN (1,2)
        AND `p`.`storeId` = cleanerId
        AND `p2`.`storeId` = cleanerId
        AND CONCAT(SUBSTRING_INDEX(currentDate,'-',2)) = CONCAT(SUBSTRING_INDEX(`st`.`created`,'-',2))
		AND currentDate BETWEEN `up`.`effectiveDate` AND (CASE WHEN `up2`.`effectiveDate` <= `up`.`effectiveDate` THEN DATE_FORMAT(NOW(), '%Y-%m-%d') ELSE `up2`.`effectiveDate` END)
	GROUP BY `up`.`id` ORDER BY `up`.`effectiveDate` DESC, `up2`.`effectiveDate` DESC) as myGroup Group By `customerId`;
    


UPDATE tempProcedureSubscriptions tps
    SET collected_amount = (
        SELECT IFNULL(ROUND((st.amount / 100), 2), 0)
            FROM 
            	subscription_transactions st
            WHERE
         		st.id = tps.transaction_id
        );
        
UPDATE tempProcedureSubscriptions tps
SET
    billing_amount = (
    SELECT IFNULL(ROUND(SUM(pp1.totalSumPerBags / 100), 2), 0) - tps.promo_amount  FROM user_plan up1 
 JOIN plans p1 ON p1.id = up1.planId
 JOIN planPrices pp1 ON p1.programId = pp1.programId
 WHERE  up1.customerId = tps.customerId
        AND (up1.planTotes = pp1.bagsAmount)
		AND up1.id = tps.user_plan_used
		AND (p1.programId IN (1, 2))
);
        
UPDATE tempProcedureSubscriptions tps
SET difference = tps.billing_amount - tps.collected_amount;
    
UPDATE tempProcedureSubscriptions tps
SET refund = (SELECT 
            IFNULL(SUM(`st`.`amount` / 100), 0) - IFNULL(SUM(`st`.`tax` / 100), 0)
        FROM
            `subscription_transactions` `st`
        WHERE
            `tps`.`transaction_id` = (CASE WHEN `st`.`parent_id` THEN (SELECT `st2`.`id` FROM `subscription_transactions` `st2` WHERE `st2`.`id` = `st`.`parent_id`) ELSE `st`.`id` END)
                AND `st`.`type` LIKE '%REFUND%'
                AND `st`.`status` IN ('COMPLETE')
);

UPDATE tempProcedureSubscriptions tps
SET refund_comment = (SELECT 
          `st`.`user_notes`
          FROM
            `subscription_transactions` `st` 
       WHERE
            `tps`.`transaction_id` = (CASE WHEN `st`.`parent_id` THEN (SELECT `st2`.`id` FROM `subscription_transactions` `st2` WHERE `st2`.`id` = `st`.`parent_id`) ELSE `st`.`id` END)
                AND `st`.`type` LIKE '%REFUND%'
                AND `st`.`status` IN ('COMPLETE')
);

UPDATE tempProcedureSubscriptions tps
SET status_on_first_day = (CASE
			WHEN (SELECT `up`.`id` 
					FROM `user_plan` `up` 
                    WHERE 
						`tps`.`user_plan_used` = `up`.`id`
					AND 
						`up`.`effectiveDate` BETWEEN `up`.`effectiveDate` AND CONCAT(SUBSTRING_INDEX(currentDate,'-',2),'-','01')
					) IS NOT NULL
					THEN 'YES'
            ELSE 'NO'
		END);
   
UPDATE tempProcedureSubscriptions tps
SET status_on_last_day = (CASE
			WHEN (SELECT `up`.`id`
					FROM `user_plan` `up` 
                    WHERE 
						`tps`.`user_plan_used` = `up`.`id`
					AND 
						`up`.`effectiveDate` BETWEEN `up`.`effectiveDate` AND LAST_DAY(currentDate)
                       ) IS NOT NULL
					THEN 'YES'
            ELSE 'NO'
		END);
        
UPDATE tempProcedureSubscriptions tps
SET subscription_during_month = (CASE
			WHEN (SELECT `up`.`id` 
					FROM `user_plan` `up` 
                    WHERE 
						`tps`.`user_plan_used` = `up`.`id`
					AND 
						`up`.`effectiveDate` BETWEEN CAST(CONCAT(SUBSTRING_INDEX(currentDate,'-',2),'-','2') AS DATE) AND LAST_DAY(currentDate) - INTERVAL 1 day
                        LIMIT 1) IS NOT NULL
					THEN 'YES'
            ELSE 'NO'
		END
);

UPDATE tempProcedureSubscriptions tps
SET
    record_exists = (SELECT
            COUNT(*)
        FROM
            `invoice_balance_subscriptions_report` `ibsr`
        WHERE
				`ibsr`.`user_plan_used` = `tps`.`user_plan_used`
                AND CONCAT(SUBSTRING_INDEX(`tps`.`billing_date`,'-',2)) = CONCAT(SUBSTRING_INDEX(`ibsr`.`billing_date`,'-',2)) );
                
                
UPDATE invoice_balance_subscriptions_report ibsr,
		tempProcedureSubscriptions tps
SET 
	ibsr.cleanerId = tps.cleanerId, 
    ibsr.customerId = tps.customerId,
    ibsr.user_plan_used = tps.user_plan_used,
    ibsr.transaction_id = tps.transaction_id,
    ibsr.user_name = tps.user_name,
	ibsr.billing_date = tps.billing_date,
    ibsr.transaction_status = tps.transaction_status,
    ibsr.billing_amount = tps.billing_amount,
    ibsr.collected_amount = tps.collected_amount,
    ibsr.difference = tps.difference,
    ibsr.refund = tps.refund,
    ibsr.refund_comment = tps.refund_comment,
    ibsr.promo_amount = tps.promo_amount,
    ibsr.payout_id = tps.payout_id,
    ibsr.payout_date = tps.payout_date,
	ibsr.status_on_first_day = tps.status_on_first_day,
	ibsr.status_on_last_day = tps.status_on_last_day,
	ibsr.subscription_during_month = tps.subscription_during_month,
	ibsr.new_subscription = tps.new_subscription,
	ibsr.lost_subscription = tps.lost_subscription
WHERE
    ibsr.cleanerId = tps.cleanerId
        AND ibsr.customerId = tps.customerId
        AND CONCAT(SUBSTRING_INDEX(tps.billing_date,'-',2)) = CONCAT(SUBSTRING_INDEX(ibsr.billing_date,'-',2))
        AND tps.record_exists = 1;

INSERT INTO invoice_balance_subscriptions_report(
	cleanerId,
    customerId,
	transaction_id,
    user_plan_used,
    user_name,
    billing_date,
    transaction_status,
    billing_amount,
    collected_amount,
    difference,
    refund,
    refund_comment,
    promo_amount,
    payout_id,
    payout_date,
    status_on_first_day,
    status_on_last_day,
    subscription_during_month,
    new_subscription,
    lost_subscription
) SELECT
	cleanerId,
    customerId,
	transaction_id,
    user_plan_used,
    user_name,
    billing_date,
    transaction_status,
    billing_amount,
    collected_amount,
    difference,
    refund,
    refund_comment,
    promo_amount,
    payout_id,
    payout_date,
    status_on_first_day,
    status_on_last_day,
    subscription_during_month,
    new_subscription,
    lost_subscription
FROM tempProcedureSubscriptions WHERE record_exists = 0;

UPDATE invoice_balance_subscriptions_report ibsr,
	tempProcedureSubscriptions tps
SET ibsr.new_subscription = (CASE 
								WHEN (
						`tps`.`status_on_first_day` = 'YES'
						AND `tps`.`status_on_last_day` = 'NO'
                        ) IS TRUE
                                THEN 'NO' 
                                ELSE 
									CASE
									WHEN (
										`tps`.`status_on_first_day` = 'NO'
										AND `tps`.`status_on_last_day` = 'YES'
										) IS TRUE
											THEN 'YES'
                                            ELSE 
                                            CASE
											WHEN (
												`tps`.`status_on_first_day` = 'YES'
												AND `tps`.`status_on_last_day` = 'YES'
												) IS TRUE
                                                THEN 'NO'
                                                ELSE CASE
													WHEN ( 
														`tps`.`status_on_first_day` = 'NO'
														AND `tps`.`status_on_last_day` = 'NO'
														) IS TRUE
															THEN `tps`.`subscription_during_month`
															ELSE 'NO'
														END
                                                END
                                            END
                                END)
 WHERE `ibsr`.`user_plan_used` = `tps`.`user_plan_used`;
 
 
 UPDATE invoice_balance_subscriptions_report ibsr,
	tempProcedureSubscriptions tps
SET ibsr.lost_subscription = (CASE 
								WHEN (
						`tps`.`status_on_first_day` = 'YES'
						AND `tps`.`status_on_last_day` = 'NO'
                        ) IS TRUE
                                THEN 'YES' 
                                ELSE 
									CASE
									WHEN (
										`tps`.`status_on_first_day` = 'NO'
										AND `tps`.`status_on_last_day` = 'YES'
										) IS TRUE
											THEN 'NO'
                                            ELSE 
                                            CASE
											WHEN (
												`tps`.`status_on_first_day` = 'YES'
												AND `tps`.`status_on_last_day` = 'YES'
												) IS TRUE
                                                THEN 'NO'
                                                ELSE 
                                                CASE
                                                WHEN ( 
														`tps`.`status_on_first_day` = 'NO'
														AND `tps`.`status_on_last_day` = 'NO'
														) IS TRUE
															THEN `tps`.`subscription_during_month`
															ELSE 'NO'
														END
                                                END
                                            END
									END)
 WHERE `ibsr`.`user_plan_used` = `tps`.`user_plan_used`;
		

drop TEMPORARY table IF EXISTS tempProcedureSubscriptions;
DROP TEMPORARY TABLE IF EXISTS tempBillingAmounts;

SELECT 0;

END	utf8mb4	utf8mb4_general_ci	latin1_swedish_ci

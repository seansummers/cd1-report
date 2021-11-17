abc_calc_daily_store_stats	STRICT_TRANS_TABLES	CREATE DEFINER=`lextech`@`%` PROCEDURE `abc_calc_daily_store_stats`(IN currentDate date, IN cleanerId int)
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
		DROP TEMPORARY table IF EXISTS tempCleanerOrders;
		DROP TEMPORARY table IF EXISTS tempCleanerTotals;
		DROP TEMPORARY table IF EXISTS tempCleanerStats;
        DROP TEMPORARY table IF EXISTS tempUserOrders;
		DROP TEMPORARY table if EXISTS tempOrderReport;

	End;

DROP TEMPORARY table IF EXISTS tempCleanerIDS;
DROP TEMPORARY table IF EXISTS tempSubCleanerIDS;
DROP TEMPORARY table IF EXISTS tempCleanerOrders;
DROP TEMPORARY table IF EXISTS tempCleanerTotals;
DROP TEMPORARY table IF EXISTS tempCleanerStats;
DROP TEMPORARY table IF EXISTS tempUserOrders;
DROP TEMPORARY table if EXISTS tempOrderReport;

/* if the date parm is empty, then assign the current date to it. */
IF currentDate IS NULL then
	SET currentDate = CURDATE();
end if;

/* create temp tables that will be needed for processing of the metrics */
CREATE TEMPORARY TABLE tempCleanerIDS (cleaner_id int(11)) ENGINE=MEMORY;
CREATE TEMPORARY TABLE tempSubCleanerIDS (cleaner_id int(11)) ENGINE=MEMORY;
CREATE TEMPORARY TABLE tempCleanerOrders (cleaner_id int(11), order_id int(11)) ENGINE=MEMORY;
CREATE TEMPORARY TABLE tempCleanerTotals (cleaner_id int(11), cleaner_date Date, Total Decimal(10,2), totalOrdersCnt int(11)) ENGINE=MEMORY;

/* if cleaner ID parm is null then get the list of unique cleaner ids that had orders for the current date. */
IF cleanerId IS NULL then
	insert into tempCleanerIDS
    select distinct cleaner_id
      from orders o join transactions t on t.order_id = o.id
      where DATE_FORMAT(cast(CONVERT_TZ(t.created, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = currentDate;

    insert into tempSubCleanerIDS
    select * from tempCleanerIDS;

	insert into tempCleanerIDS
    select distinct cleaner_id
      from subscription_transactions t
      where DATE_FORMAT(cast(CONVERT_TZ(t.created, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = currentDate and cleaner_id not in (select cleaner_id from tempSubCleanerIDS);
else
	insert into tempCleanerIDS values (cleanerId);
end if;

/* DATE_FORMAT(cast(t.created as date), '%Y-%m-%d') = currentDate */

set recordCount = (select count(*) from tempCleanerIDS);

/* if no orders and transactions for the current date then still insert records into cleaner_daily_stats for each cleaner with zero values */
IF recordCount = 0 THEN
        insert into tempCleanerIDS
			(cleaner_id)
		select distinct id
			from cleaners c
			where c.status = 'Active' and c.name <> 'Production Test Cleaners';
END IF;


/* get the universe of orders tied to transactions for the current date */
insert into tempCleanerOrders
select  distinct o.cleaner_id, o.id
from trips tr
join exchanges ex on ex.trip_id = tr.id
join orders o on o.id = ex.order_id
join tempCleanerIDS tci on tci.cleaner_id = o.cleaner_id
WHERE ((DATE_FORMAT(cast(CONVERT_TZ(tr.actual, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = currentDate)) AND o.status='DELIVERED' AND ex.type='DELIVERY';

CREATE TEMPORARY TABLE tempOrderReport (
    orderid int(11) NOT NULL,
    washAndPressTotal decimal(10, 2) DEFAULT '0.00',
    dryCleanTotal decimal(10, 2) DEFAULT '0.00',
    householdTotal decimal(10, 2) DEFAULT '0.00',
    deliveryFee decimal(10, 2) DEFAULT '0.00',
    couponApplied decimal(10, 2) DEFAULT '0.00',
    creditsUsed decimal(10, 2) DEFAULT '0.00',
    deliveredAmount decimal(10, 2) DEFAULT '0.00',
    chargedAmount decimal(10, 2) DEFAULT '0.00',
    washAndFoldPoundsSubscriber decimal(10, 2),
    washAndFoldPoundsOverflow decimal(10, 2),
    washAndFoldPoundsNonSubscription decimal(10, 2) DEFAULT '0.00',
    dryCleanCounts int(11) DEFAULT '0',
    washAndPressCounts decimal(10, 2) DEFAULT '0.00',
    householdCounts int(11) DEFAULT '0'
) ENGINE=MEMORY;

insert into tempOrderReport(
    orderId,
    washAndPressTotal,
    dryCleanTotal,
    householdTotal,
    deliveryFee,
    couponApplied,
    creditsUsed,
    deliveredAmount,
    chargedAmount,
    washAndFoldPoundsSubscriber,
    washAndFoldPoundsOverflow,
    washAndFoldPoundsNonSubscription,
    dryCleanCounts,
    washAndPressCounts,
    householdCounts
)
select
    orderId,
    WashandPressTotal,
    DryCleanTotal,
    HouseholdTotal,
    deliveryFee,
    CouponApplied,
    CreditsUsed,
    DeliveredAmount,
    ChargedAmount,
    WashandFoldPoundsSubscriber,
    WashandFoldPoundsOverflow,
    WashandFoldPoundsNonSubscription,
    DryCleanCounts,
    WashandPressCounts,
    HouseholdCounts
from order_report;


/* create new temp table to hold the metrics while processing. This data will be inserted into cleaning_daily_stats at the end of the procedure. */

CREATE TEMPORARY TABLE tempCleanerStats (
	cleaner_id int(11) NOT NULL,
	cleaner_date date  NULL,
    record_exists int(11) NULL default 0,
	wash_fold_nonsubscriber_amt decimal(10,2) DEFAULT '0.00',
	wash_press_nonsubscriber_amt decimal(10,2) DEFAULT '0.00',
	dry_clean_nonsubscriber_amt decimal(10,2) DEFAULT '0.00',
	household_amt decimal(10,2) DEFAULT '0.00',
    wash_fold_non_subs_overflow_amt decimal(10,2) DEFAULT '0.00',
	wash_fold_overflow_amt decimal(10,2) DEFAULT '0.00',
	wash_fold_subscription_amt decimal(10,2) DEFAULT '0.00',
    any_garment_dry_clean_amt decimal(10, 2) DEFAULT '0.00',
	delivery_fee_amt decimal(10,2) DEFAULT '0.00',
	coupon_applied_amt decimal(10,2) DEFAULT '0.00',
	credit_applied_amt decimal(10,2) DEFAULT '0.00',
	refund_amt decimal(10,2) DEFAULT '0.00',
	net_sales_amt decimal(10,2) DEFAULT '0.00',
	total_orders_cnt int(11) DEFAULT '0',
    delivered_charged_cnt decimal(10,2) DEFAULT '0.00',
	uncollected_charge_cnt decimal(10,2) DEFAULT '0.00',
    total_current_day_subs_amt decimal(10, 2) DEFAULT '0.00',
    completed_current_day_subs_amt decimal(10, 2) DEFAULT '0.00',
	avg_order_amt decimal(10,2) DEFAULT '0.00',
	new_registered_user_cnt int(11) DEFAULT '0',
	total_registered_user_cnt int(11) DEFAULT '0',
	new_active_user_cnt int(11) DEFAULT '0',
	total_active_user_cnt int(11) DEFAULT '0',
    cc_stripe_fee_amt decimal(10,2) DEFAULT '0.00',
	wash_fold_nonsubscriber_pct decimal(6,2) DEFAULT '0.00',
	wash_press_nonsubscriber_pct decimal(6,2) DEFAULT '0.00',
	dry_clean_nonsubscriber_pct decimal(6,2) DEFAULT '0.00',
	household_pct decimal(6,2) DEFAULT '0.00',
	wash_fold_overflow_nonsubscription_pct decimal(6,2) DEFAULT '0.00',
	wash_fold_subscription_pct decimal(6,2) DEFAULT '0.00',
	delivery_fee_pct decimal(6,2) DEFAULT '0.00',
	coupon_applied_pct decimal(6,2) DEFAULT '0.00',
	refund_pct decimal(6,2) DEFAULT '0.00',
    total_actual_pickup_stops_cnt int(11) DEFAULT '0',
    total_actual_dropoff_stops_cnt int(11) DEFAULT '0',
    total_actual_skipped_by_driver_cnt int(11) DEFAULT '0',
    wash_fold_pounds decimal(10,2) DEFAULT '0.00',
    wash_fold_overflow_pounds decimal(10,2) DEFAULT '0.00',
	wash_fold_non_subscription_pounds decimal(10,2) DEFAULT '0.00',
    dry_clean_cnt int DEFAULT '0',
    wash_press_cnt int DEFAULT '0',
    household_cnt int DEFAULT '0',
    -- Added on 11th March 2020
	sales_tax decimal(10,2) DEFAULT '0.00'
) ENGINE=MEMORY;



/* seec the tempCleanerStats temp table with all the cleaner IDS that had transactions for the current date */
insert into tempCleanerStats (cleaner_id)
select cleaner_id from tempCleanerIDS;

UPDATE tempCleanerStats
SET
    cleaner_date = currentDate;

/* begin section to calculate each metric */

/*
UPDATE tempCleanerStats tcs
SET
    wash_fold_nonsubscriber_amt = (SELECT
            SUM(vor.LaundryByPoundTrans)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            v_OrderReport vor ON o.id = vor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);
*/

UPDATE tempCleanerStats tcs
SET
    wash_fold_nonsubscriber_amt = (SELECT
            IFNULL(SUM(op.quantity * (op.amount / 100)),0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            order_products op ON o.id = op.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id AND
            op.product_id = '5' AND
            op.deleted_at IS NULL AND
            op.status = 'Applied' AND NOT EXISTS (SELECT DISTINCT order_products.order_id FROM order_products WHERE order_products.`name` IN ('Subscription Tote','Non-Subscription Tote') AND order_products.status = 'Applied' AND order_products.order_id=o.id));


UPDATE tempCleanerStats tcs
SET
    wash_fold_nonsubscriber_amt =  wash_fold_nonsubscriber_amt + (SELECT
            IFNULL(SUM(op.quantity * (op.amount / 100)),0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            order_products op ON o.id = op.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id AND
            op.deleted_at IS NULL AND
            op.name = 'Non-Subscription Tote' AND
            op.status = 'Applied' );
            
UPDATE tempCleanerStats tcs
SET
    any_garment_dry_clean_amt = (SELECT
            IFNULL((SUM(op.amount / 100) * -1),0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            order_products op ON o.id = op.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id AND
            op.deleted_at IS NULL AND
            op.product_id = '2' AND
            op.status = 'Applied' );

/* Update washPressNonSubscriberAmt */
UPDATE tempCleanerStats tcs
SET
    wash_press_nonsubscriber_amt = (SELECT
            SUM(tor.WashandPressTotal)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);


/* dryCleanNonSubscriberAmt */
UPDATE tempCleanerStats tcs
SET
    dry_clean_nonsubscriber_amt = (SELECT
            SUM(tor.DryCleanTotal)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);


/* Update houseHoldAmt */
UPDATE tempCleanerStats tcs
SET
    household_amt = (SELECT
            SUM(tor.HouseholdTotal)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);


/* Update wash_fold_subscription_amt */
UPDATE tempCleanerStats tcs
SET
    wash_fold_subscription_amt = (SELECT
            SUM((IFNULL(st.amount, 0) / 100) /*+ (IFNULL(st.tax, 0) / 100)*/)
        FROM
            subscription_transactions st
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(st.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
                AND st.cleaner_id = tcs.cleaner_id
                AND st.status = 'Complete'
                AND st.type = 'Charge');

/*washFoldOverflowNonSubscriptionAmt */
/*UPDATE tempCleanerStats tcs
        JOIN
    orders o ON tcs.cleaner_id = o.cleaner_id
        JOIN
    tempCleanerOrders t ON o.id = t.order_id
SET
    wash_fold_overflow_amt = (SELECT
            SUM(op.quantity * (op.amount / 100))
        FROM
            order_products op
        WHERE
            op.product_id = '5' AND
            op.status = 'Applied' AND
            op.order_id = o.id AND EXISTS (SELECT DISTINCT order_products.order_id FROM order_products WHERE order_products.`name`='Subscription Tote' AND order_products.status = 'Applied' AND order_products.order_id=o.id));*/

UPDATE tempCleanerStats tcs
SET
    wash_fold_overflow_amt = (SELECT
            SUM(op.quantity * (op.amount / 100))
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            order_products op ON o.id = op.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id AND
            op.deleted_at IS NULL AND
            op.product_id = '5' AND
            op.status = 'Applied' AND EXISTS (SELECT DISTINCT order_products.order_id FROM order_products WHERE order_products.`name`='Subscription Tote' AND order_products.status = 'Applied' AND order_products.order_id=o.id));


UPDATE tempCleanerStats tcs
SET
    wash_fold_non_subs_overflow_amt = (SELECT
            SUM(op.quantity * (op.amount / 100))
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            order_products op ON o.id = op.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id AND
            op.deleted_at IS NULL AND
            op.product_id = '5' AND
            op.status = 'Applied' AND EXISTS (SELECT DISTINCT order_products.order_id FROM order_products WHERE order_products.`name`='Non-Subscription Tote' AND order_products.status = 'Applied' AND order_products.order_id=o.id));

/* Update deliveryFeeAmt */
UPDATE tempCleanerStats tcs
SET
    delivery_fee_amt = (SELECT
            SUM(tor.deliveryFee)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);

  /* Update couponAppliedAmt */
UPDATE tempCleanerStats tcs
SET
    coupon_applied_amt = (SELECT
            IFNULL(SUM(tor.CouponApplied), 0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);

/* UPDATE tempCleanerStats tcs
SET
    coupon_applied_amt = coupon_applied_amt + (SELECT
            IFNULL(SUM((st.promo_amount / 100) * - 1), 0)
        FROM
            subscription_transactions st
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(st.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
				AND ISNULL(st.parent_id)
                AND st.cleaner_id = tcs.cleaner_id
                AND st.status = 'Complete'
                AND st.type = 'Charge'); */

 /* Update creditAppliedAmt */
UPDATE tempCleanerStats tcs
SET
    credit_applied_amt = (SELECT
            IFNULL(SUM(tor.CreditsUsed), 0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);

/*
UPDATE tempCleanerStats tcs
SET
    credit_applied_amt = credit_applied_amt + (SELECT
            IFNULL(SUM(opm.amount/100),0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            transactions tran ON o.id = tran.order_id
            	JOIN
			order_price_modifiers opm ON tran.order_id = opm.target_id
        WHERE
            o.cleaner_id = tcs.cleaner_id
                AND tran.type = 'Charge'
                AND tran.status IN ('COMPLETE')
                AND tran.payment_type = 'Credit');
*/

UPDATE tempCleanerStats tcs
SET
    credit_applied_amt = credit_applied_amt + (SELECT
            IFNULL(SUM((st.amount / 100) * - 1), 0)
        FROM
            subscription_transactions st
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(st.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
                AND st.cleaner_id = tcs.cleaner_id
                AND st.status = 'Complete'
                AND st.type = 'Charge'
                AND st.payment_type = 'Credit');

 /* Update refundAmt */
/*UPDATE tempCleanerStats tcs
SET
    refund_amt = (SELECT
            IFNULL(SUM(tran.amount / 100), 0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            transactions tran ON o.id = tran.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id
                AND tran.type LIKE '%Refund%'
                AND tran.status IN ('COMPLETE'));
*/

UPDATE tempCleanerStats tcs
SET
    refund_amt = (SELECT
            IFNULL(SUM(tran.amount / 100), 0) - IFNULL(SUM(tran.tax / 100), 0)
        FROM
            orders o
                JOIN
            transactions tran ON o.id = tran.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id
                AND tran.type LIKE '%Refund%'
                AND tran.status IN ('COMPLETE')
                AND DATE_FORMAT(cast(CONVERT_TZ(tran.created, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = currentDate);

/* in test the refunds are postive values and in prod they are negative values - need to show negative values so I'm not forcing negatives in DEV */
UPDATE tempCleanerStats tcs
SET
    refund_amt = refund_amt + (SELECT
            IFNULL(SUM(st.amount / 100), 0) /*- IFNULL(SUM(st.tax / 100), 0)*/
        FROM
            subscription_transactions st
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(st.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
                AND st.cleaner_id = tcs.cleaner_id
                AND st.status = 'COMPLETE'
                AND st.type LIKE '%Refund%');

/* totalOrdersCnt */
UPDATE tempCleanerStats tcs
SET
    total_orders_cnt = (SELECT
            COUNT(*)
        FROM
            tempCleanerOrders o
        WHERE
            o.cleaner_id = tcs.cleaner_id);


	/* total_current_day_subs_amt */
UPDATE tempCleanerStats tcs
SET
    total_current_day_subs_amt = (
    
    SELECT SUM(totesSum) from (SELECT ROUND(SUM((pp1.totalSumPerBags / 100)), 2) as totesSum FROM user_plan up1 
 JOIN plans p1 ON p1.id = up1.planId
 JOIN planPrices pp1 ON p1.programId = pp1.programId
 WHERE up1.enabled = '1'
		AND (p1.storeId = cleanerId)
        AND (up1.planTotes = pp1.bagsAmount)
		AND EXTRACT(DAY from currentdate) = up1.billingDayOfMonth
		AND (p1.programId = '1')
	UNION
    
SELECT ROUND(SUM((pp2.totalSumPerBags / 100)), 2) as totesSum FROM user_plan up2
	JOIN plans p2 ON p2.id = up2.planId
	JOIN planPrices pp2 ON p2.programId = pp2.programId
	WHERE (up2.enabled = '1'
		AND (p2.storeId = cleanerId)
        AND (up2.planTotes = pp2.bagsAmount)
		AND EXTRACT(DAY from currentdate) = up2.billingDayOfMonth
		AND (p2.programId = '2'))
	) as MyGroup
);
        
/* completed_subs_trans_cnt */
UPDATE tempCleanerStats tcs
    SET completed_current_day_subs_amt = (
        SELECT ROUND(SUM((st.amount / 100)), 2)
            FROM subscription_transactions st
            WHERE
                DATE_FORMAT(CAST(st.created AS DATE), '%Y-%m-%d') = currentDate
            AND
                st.parent_id IS NULL
            AND
                st.status = 'COMPLETE'
			AND 
				st.cleaner_id = tcs.cleaner_id
        );

/* uncollectedChargeCnt */


UPDATE tempCleanerStats tcs
SET
    delivered_charged_cnt = (SELECT
            (SUM(tor.DeliveredAmount) - SUM(tor.ChargedAmount))
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);



/* netSalesAmt */
insert into tempCleanerTotals
select cleaner_id, cleaner_date, (IFNULL(wash_fold_nonsubscriber_amt, 0)  + IFNULL(wash_press_nonsubscriber_amt, 0) + IFNULL(dry_clean_nonsubscriber_amt, 0) + IFNULL(household_amt, 0) +
										IFNULL(wash_fold_subscription_amt, 0) + IFNULL(wash_fold_overflow_amt, 0) + IFNULL(wash_fold_non_subs_overflow_amt, 0) +
                                         IFNULL(delivery_fee_amt, 0) + /*IFNULL(credit_applied_amt, 0) +*/ IFNULL(refund_amt, 0) + IFNULL(coupon_applied_amt, 0)) as 'Total', total_orders_cnt
from tempCleanerStats;

/*IFNULL(credit_applied_amt, 0) +*/

UPDATE tempCleanerStats tcs
SET
    net_sales_amt = (SELECT
            total
        FROM
            tempCleanerTotals tct
        WHERE
            tct.cleaner_id = tcs.cleaner_id
                AND tct.cleaner_date = tcs.cleaner_date);

UPDATE tempCleanerStats tcs
SET
    avg_order_amt = (SELECT
            (IFNULL(net_sales_amt, 0) - IFNULL(wash_fold_subscription_amt, 0)) / IFNULL(total_orders_cnt, 1)
        FROM
            tempCleanerTotals tct
        WHERE
            tct.cleaner_id = tcs.cleaner_id
                AND tct.cleaner_date = tcs.cleaner_date);

/* update temp cleaner stats to calculate % of net sales */
UPDATE tempCleanerStats tcs
SET
		uncollected_charge_cnt =  ( ((IFNULL(delivered_charged_cnt, 0)) + ((IFNULL(total_current_day_subs_amt, 0)) - ((IFNULL(completed_current_day_subs_amt, 0))))) + ((IFNULL((SELECT
            IFNULL(SUM((st.promo_amount / 100) * - 1), 0)
        FROM
            subscription_transactions st
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(st.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
				AND ISNULL(st.parent_id)
                AND st.cleaner_id = tcs.cleaner_id
                AND st.status = 'Complete'
                AND st.type = 'Charge'), 0)) ) ),
    wash_fold_nonsubscriber_pct = ROUND((IFNULL(wash_fold_nonsubscriber_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    wash_press_nonsubscriber_pct = ROUND((IFNULL(wash_press_nonsubscriber_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    dry_clean_nonsubscriber_pct = ROUND((IFNULL(dry_clean_nonsubscriber_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    household_pct = ROUND((IFNULL(household_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    wash_fold_overflow_nonsubscription_pct = ROUND((IFNULL(wash_fold_overflow_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    wash_fold_subscription_pct = ROUND((IFNULL(wash_fold_subscription_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    delivery_fee_pct = ROUND((IFNULL(delivery_fee_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    coupon_applied_pct = ROUND((IFNULL(coupon_applied_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1),
    refund_pct = ROUND((IFNULL(refund_amt, 0) / IFNULL(tcs.net_sales_amt, 1)) * 100,
            1);


/* new_registered_user_cnt */
/* Commented as we din't wanted dependency on promotions
UPDATE tempCleanerStats tcs
SET
    new_registered_user_cnt = (SELECT
            COUNT(*)
        FROM
            users u
                JOIN
            promotions p ON u.referral_promotion_id = p.id
                AND u.referrer_type = p.owner_type
        WHERE
            u.referrer_code IS NOT NULL
                AND p.status = 'Active'
                AND p.owner_id = tcs.cleaner_id
                AND DATE_FORMAT(CAST(u.created AS DATE), '%Y-%m-%d') = currentDate
                AND u.id NOT IN (SELECT
                    user_id
                FROM
                    orders
                WHERE
                    DATE_FORMAT(CAST(created AS DATE), '%Y-%m-%d') = currentDate
                    AND status <> 'DELIVERED'));
*/

UPDATE tempCleanerStats tcs
SET
    new_registered_user_cnt =  (SELECT
             COUNT(*)
        FROM
            users,user_primary_cleaners
        WHERE
            user_primary_cleaners.user_id=users.id AND
            user_primary_cleaners.cleaner_id= tcs.cleaner_id AND
            DATE_FORMAT(CAST(users.created AS DATE), '%Y-%m-%d') = currentdate);

/* total_registered_user_cnt */
/* Commented as we din't wanted dependency on promotions
UPDATE tempCleanerStats tcs
SET
    total_registered_user_cnt = (SELECT
            COUNT(*)
        FROM
            users u
                JOIN
            promotions p ON u.referral_promotion_id = p.id
                AND u.referrer_type = p.owner_type
        WHERE
            u.referrer_code IS NOT NULL
                AND p.status = 'Active'
                AND p.owner_id = tcs.cleaner_id
                AND DATE_FORMAT(CAST(u.created AS DATE), '%Y-%m-%d') <= currentdate
                AND u.id NOT IN (SELECT
                    user_id
                FROM
                    orders
                WHERE
                    DATE_FORMAT(CAST(created AS DATE), '%Y-%m-%d') = currentdate
                        AND status <> 'DELIVERED'));
*/

UPDATE tempCleanerStats tcs
SET
    total_registered_user_cnt =  (SELECT
             COUNT(*)
        FROM
            users,user_primary_cleaners
        WHERE
            user_primary_cleaners.user_id=users.id AND
            user_primary_cleaners.cleaner_id= tcs.cleaner_id AND
            DATE_FORMAT(CAST(users.created AS DATE), '%Y-%m-%d') <= currentdate);

/* new_active_user_cnt */

/* if created date of first order in the system for a user is the same as the date we are processing for then include in new_active_user_cnt */

CREATE TEMPORARY TABLE tempUserOrders (cleaner_id int(11), user_id int(11), created_date date, first_date date) ENGINE=MEMORY;

/* on 10/31 - David requested to switch to use the transaction record created date instead of using the orders created date - commenting out code here.  Do not include the subscription transactions per David

insert into tempUserOrders
select o.cleaner_id, o.user_id, currentDate, null
from orders o
where DATE_FORMAT(cast(o.created as date), '%Y-%m-%d') = currentDate;

update tempUserOrders tuo
	 set first_date = (SELECT MIN(DATE_FORMAT(cast(o.created as date), '%Y-%m-%d'))
            FROM orders o
            WHERE  o.cleaner_id = tuo.cleaner_id
				AND o.user_id = tuo.user_id);
*/

/* Start - new code to use the transaction records to determine new_active_user_cnt */

insert into tempUserOrders
select o.cleaner_id, o.user_id, currentDate, null
from orders o join transactions t on o.id = t.order_id
where DATE_FORMAT(cast(CONVERT_TZ(t.created, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = currentDate AND t.status = 'COMPLETE';

UPDATE tempUserOrders tuo
SET
    first_date = (SELECT
            MIN(DATE_FORMAT(CAST(CONVERT_TZ(t.created, 'UTC', 'CST6CDT') AS DATE),
                        '%Y-%m-%d'))
        FROM
            orders o
                JOIN
            transactions t ON o.id = t.order_id
        WHERE
            o.cleaner_id = tuo.cleaner_id
                AND o.user_id = tuo.user_id);
/* End - new code to use the transaction records to determine new_active_user_cnt */


UPDATE tempCleanerStats tcs
SET
    new_active_user_cnt = (SELECT
            COUNT(DISTINCT tuo.user_id)
        FROM
            tempUserOrders tuo
        WHERE
            tuo.cleaner_id = tcs.cleaner_id
                AND tuo.created_date = tuo.first_date);



/* totalActiveUserCnt */

UPDATE tempCleanerStats tcs
SET
    total_active_user_cnt = (SELECT
            COUNT(DISTINCT o.user_id)
        FROM
            orders o
                JOIN
            transactions t ON o.id = t.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id
                AND DATE_FORMAT(CAST(CONVERT_TZ(t.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') <= currentDate
                AND t.status = 'COMPLETE'
                AND o.status='DELIVERED');

/* End - new code to use the transaction records to determine total_active_user_cnt */


UPDATE tempCleanerStats tcs
SET
    cc_stripe_fee_amt = (SELECT
            IFNULL(SUM(st.stripe_fee / 100), 0)
        FROM
            subscription_transactions st
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(st.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
                AND st.cleaner_id = tcs.cleaner_id
                AND st.status = 'Complete') + (SELECT
            IFNULL(SUM(t.stripe_fee / 100), 0)
        FROM
            transactions t
                JOIN
            orders o ON t.order_id = o.id
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(t.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
                AND o.cleaner_id = tcs.cleaner_id
                AND t.status = 'Complete');



/* actual_pickup_stops_cnt */
UPDATE tempCleanerStats tcds
SET
    total_actual_pickup_stops_cnt = (SELECT
            SUM(cdds.actual_pickup_stops_cnt)
        FROM
            cleaner_daily_driver_stats_1902 cdds
        WHERE
            DATE_FORMAT(CAST(cdds.cleaner_date AS DATE),
                    '%Y-%m-%d') = currentDate
                AND cdds.cleaner_id = tcds.cleaner_id);


/* actual_dropoff_stops_cnt */
UPDATE tempCleanerStats tcds
SET
    total_actual_dropoff_stops_cnt = (SELECT
            SUM(cdds.actual_dropoff_stops_cnt)
        FROM
            cleaner_daily_driver_stats_1902 cdds
        WHERE
            DATE_FORMAT(CAST(cdds.cleaner_date AS DATE),
                    '%Y-%m-%d') = currentDate
                AND cdds.cleaner_id = tcds.cleaner_id);



/* actual_skipped_by_driver_cnt */
UPDATE tempCleanerStats tcds
SET
    total_actual_skipped_by_driver_cnt = (SELECT
            SUM(cdds.actual_skipped_by_driver_cnt)
        FROM
            cleaner_daily_driver_stats_1902 cdds
        WHERE
            DATE_FORMAT(CAST(cdds.cleaner_date AS DATE),
                    '%Y-%m-%d') = currentDate
                AND cdds.cleaner_id = tcds.cleaner_id);

/* wash_fold_pounds */
UPDATE tempCleanerStats tcs
SET
    wash_fold_pounds = (SELECT
            SUM(tor.WashandFoldPoundsSubscriber)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);

/* wash_fold_pounds */
UPDATE tempCleanerStats tcs
SET
    wash_fold_pounds = (SELECT
            SUM(tor.WashandFoldPoundsSubscriber)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);

/* wash_fold_overflow_pounds */
UPDATE tempCleanerStats tcs
SET
    wash_fold_overflow_pounds = (SELECT
            SUM(tor.WashandFoldPoundsOverflow)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);

/* wash_fold_non_subscription_pounds */
UPDATE tempCleanerStats tcs
SET
    wash_fold_non_subscription_pounds = (SELECT
            SUM(tor.WashandFoldPoundsNonSubscription)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);


/* dry_clean_cnt */
UPDATE tempCleanerStats tcs
SET
    dry_clean_cnt = (SELECT
            SUM(tor.DryCleanCounts)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);


/* wash_press_cnt*/
UPDATE tempCleanerStats tcs
SET
    wash_press_cnt = (SELECT
            SUM(tor.WashandPressCounts)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);


/* household_cnt*/
UPDATE tempCleanerStats tcs
SET
    household_cnt = (SELECT
            SUM(tor.HouseholdCounts)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
                JOIN
            tempOrderReport tor ON o.id = tor.orderid
        WHERE
            o.cleaner_id = tcs.cleaner_id);


-- Added on 11th March 2020
/* sales_tax */
UPDATE tempCleanerStats tcs
SET
    sales_tax = (SELECT
            IFNULL(SUM(st.tax / 100), 0)
        FROM
            subscription_transactions st
        WHERE
            DATE_FORMAT(CAST(CONVERT_TZ(st.created, 'UTC', 'CST6CDT') AS DATE),
                    '%Y-%m-%d') = currentDate
                AND st.cleaner_id = tcs.cleaner_id
                AND st.status = 'Complete') + (SELECT
            IFNULL(SUM(opm.amount/100),0)
        FROM
            orders o
                JOIN
            tempCleanerOrders t ON o.id = t.order_id
            	JOIN
			order_price_modifiers opm ON t.order_id = opm.target_id
        WHERE
            o.cleaner_id = tcs.cleaner_id
                AND (opm.modifier_type = 'Dryv\\Billing\\Tax' OR opm.modifier_type = 'Dryv\\Taxes\\TaxCounty')
                AND opm.target_type = 'Dryv\\Orders\\Order'
                AND opm.status = 'APPLIED');

UPDATE tempCleanerStats tcs
SET
    sales_tax = sales_tax + (SELECT
            IFNULL(SUM(tran.tax / 100), 0)
        FROM
            orders o
                JOIN
            transactions tran ON o.id = tran.order_id
        WHERE
            o.cleaner_id = tcs.cleaner_id
                AND tran.type LIKE '%Refund%'
                AND tran.status IN ('COMPLETE')
                AND DATE_FORMAT(cast(CONVERT_TZ(tran.created, 'UTC', 'CST6CDT') as date), '%Y-%m-%d') = currentDate);

/* determine if the new data exists in cleaner_daily_stats yet. if not then it will get inserted. If it exists, then up*/
UPDATE tempCleanerStats tcs
SET
    record_exists = (SELECT
            COUNT(*)
        FROM
            abc_cleaner_daily_stats_1902 cds
        WHERE
            tcs.cleaner_id = cds.cleaner_id
                AND tcs.cleaner_date = cds.cleaner_date);


/* insert new records into cleaner_daily_stats */
insert into abc_cleaner_daily_stats_1902
(cleaner_id, cleaner_date, wash_fold_nonsubscriber_amt, wash_press_nonsubscriber_amt, dry_clean_nonsubscriber_amt,
	household_amt , wash_fold_non_subs_overflow_amt, wash_fold_overflow_amt, wash_fold_subscription_amt,
	delivery_fee_amt , coupon_applied_amt ,
	credit_applied_amt, refund_amt, net_sales_amt, total_orders_cnt, uncollected_charge_cnt, avg_order_amt,
	new_registered_user_cnt, total_registered_user_cnt, new_active_user_cnt, total_active_user_cnt, cc_stripe_fee_amt,
	wash_fold_nonsubscriber_pct, wash_press_nonsubscriber_pct, dry_clean_nonsubscriber_pct,
	household_pct,wash_fold_overflow_nonsubscription_pct, wash_fold_subscription_pct,
	delivery_fee_pct, coupon_applied_pct, refund_pct,
    total_actual_pickup_stops_cnt, total_actual_dropoff_stops_cnt, total_actual_skipped_by_driver_cnt,
    wash_fold_pounds, wash_fold_overflow_pounds, wash_fold_non_subscription_pounds, dry_clean_cnt, wash_press_cnt, household_cnt,
    -- Added on 11th March 2020
    sales_tax)
select cleaner_id, cleaner_date,  IFNULL(wash_fold_nonsubscriber_amt, 0), IFNULL(wash_press_nonsubscriber_amt, 0), IFNULL(dry_clean_nonsubscriber_amt, 0),
	IFNULL(household_amt, 0), IFNULL(wash_fold_non_subs_overflow_amt, 0), IFNULL(wash_fold_overflow_amt, 0), IFNULL(wash_fold_subscription_amt, 0),
	IFNULL(delivery_fee_amt, 0),  IFNULL(coupon_applied_amt, 0),
	IFNULL(credit_applied_amt, 0), IFNULL(refund_amt, 0), IFNULL(net_sales_amt, 0),  IFNULL(total_orders_cnt, 0), IFNULL(uncollected_charge_cnt, 0), IFNULL(avg_order_amt, 0),
	IFNULL(new_registered_user_cnt, 0),  IFNULL(total_registered_user_cnt, 0), IFNULL(new_active_user_cnt, 0),  IFNULL(total_active_user_cnt, 0), IFNULL(cc_stripe_fee_amt, 0),
    IFNULL(wash_fold_nonsubscriber_pct, 0), IFNULL(wash_press_nonsubscriber_pct , 0), IFNULL(dry_clean_nonsubscriber_pct, 0),
	IFNULL(household_pct , 0), IFNULL(wash_fold_overflow_nonsubscription_pct, 0), IFNULL(wash_fold_subscription_pct, 0),
	IFNULL(delivery_fee_pct, 0), IFNULL(coupon_applied_pct, 0), IFNULL(refund_pct, 0),
    IFNULL(total_actual_pickup_stops_cnt, 0), IFNULL(total_actual_dropoff_stops_cnt, 0), IFNULL(total_actual_skipped_by_driver_cnt, 0),
    IFNULL(wash_fold_pounds, 0), IFNULL(wash_fold_overflow_pounds, 0), IFNULL(wash_fold_non_subscription_pounds, 0), IFNULL(dry_clean_cnt, 0) ,
    IFNULL(wash_press_cnt, 0), IFNULL(household_cnt, 0),
    -- Added on 11th March 2020
    IFNULL(sales_tax, 0)
    from tempCleanerStats where record_exists = 0;

/* update cleaner_daily_stats if the record already exists */
UPDATE abc_cleaner_daily_stats_1902 cds,
    tempCleanerStats tcs
SET
    cds.wash_fold_nonsubscriber_amt = IFNULL(tcs.wash_fold_nonsubscriber_amt, 0),
    cds.wash_press_nonsubscriber_amt = IFNULL(tcs.wash_press_nonsubscriber_amt, 0),
    cds.dry_clean_nonsubscriber_amt = IFNULL(tcs.dry_clean_nonsubscriber_amt, 0),
    cds.household_amt = IFNULL(tcs.household_amt, 0),
    cds.wash_fold_non_subs_overflow_amt = IFNULL(tcs.wash_fold_non_subs_overflow_amt, 0),
    cds.wash_fold_overflow_amt = IFNULL(tcs.wash_fold_overflow_amt, 0),
    cds.wash_fold_subscription_amt = IFNULL(tcs.wash_fold_subscription_amt, 0),
    cds.delivery_fee_amt = IFNULL(tcs.delivery_fee_amt, 0),
    cds.coupon_applied_amt = IFNULL(tcs.coupon_applied_amt, 0),
    cds.credit_applied_amt = IFNULL(tcs.credit_applied_amt, 0),
    cds.refund_amt = IFNULL(tcs.refund_amt, 0),
    cds.net_sales_amt = IFNULL(tcs.net_sales_amt, 0),
    cds.total_orders_cnt = IFNULL(tcs.total_orders_cnt, 0),
    cds.uncollected_charge_cnt = IFNULL(tcs.uncollected_charge_cnt, 0),
    cds.avg_order_amt = IFNULL(tcs.avg_order_amt, 0),
    cds.new_registered_user_cnt = IFNULL(tcs.new_registered_user_cnt, 0),
    cds.total_registered_user_cnt = IFNULL(tcs.total_registered_user_cnt, 0),
    cds.new_active_user_cnt = IFNULL(tcs.new_active_user_cnt, 0),
    cds.total_active_user_cnt = IFNULL(tcs.total_active_user_cnt, 0),
    cds.cc_stripe_fee_amt = IFNULL(tcs.cc_stripe_fee_amt, 0),
    cds.wash_fold_nonsubscriber_pct = IFNULL(tcs.wash_fold_nonsubscriber_pct, 0),
    cds.wash_press_nonsubscriber_pct = IFNULL(tcs.wash_press_nonsubscriber_pct, 0),
    cds.dry_clean_nonsubscriber_pct = IFNULL(tcs.dry_clean_nonsubscriber_pct, 0),
    cds.household_pct = IFNULL(tcs.household_pct, 0),
    cds.wash_fold_overflow_nonsubscription_pct = IFNULL(tcs.wash_fold_overflow_nonsubscription_pct,
            0),
    cds.wash_fold_subscription_pct = IFNULL(tcs.wash_fold_subscription_pct, 0),
    cds.delivery_fee_pct = IFNULL(tcs.delivery_fee_pct, 0),
    cds.coupon_applied_pct = IFNULL(tcs.coupon_applied_pct, 0),
    cds.refund_pct = IFNULL(tcs.refund_pct, 0),
    cds.total_actual_pickup_stops_cnt = IFNULL(tcs.total_actual_pickup_stops_cnt, 0),
    cds.total_actual_dropoff_stops_cnt = IFNULL(tcs.total_actual_dropoff_stops_cnt, 0),
    cds.total_actual_skipped_by_driver_cnt = IFNULL(tcs.total_actual_skipped_by_driver_cnt,
            0),
    cds.wash_fold_pounds = IFNULL(tcs.wash_fold_pounds, 0),
    cds.wash_fold_overflow_pounds = IFNULL(tcs.wash_fold_overflow_pounds, 0),
    cds.wash_fold_non_subscription_pounds = IFNULL(tcs.wash_fold_non_subscription_pounds, 0),
    cds.dry_clean_cnt = IFNULL(tcs.dry_clean_cnt, 0),
    cds.wash_press_cnt = IFNULL(tcs.wash_press_cnt, 0),
    cds.household_cnt = IFNULL(tcs.household_cnt, 0),
    -- Added on 11th March 2020
    cds.sales_tax = IFNULL(tcs.sales_tax, 0)
WHERE
    cds.cleaner_id = tcs.cleaner_id
        AND cds.cleaner_date = tcs.cleaner_date
        AND tcs.record_exists = 1;





/* drop all temp tables before ending the stored proc */
drop TEMPORARY table IF EXISTS tempCleanerOrders;
drop TEMPORARY table IF EXISTS tempCleanerIDS;
drop TEMPORARY table IF EXISTS tempSubCleanerIDS;
drop TEMPORARY table IF EXISTS tempCleanerStats;
drop TEMPORARY table IF EXISTS tempCleanerTotals;
drop TEMPORARY table IF EXISTS tempUserOrders;
drop TEMPORARY table if EXISTS tempOrderReport;

SELECT 0;

END	utf8mb4	utf8mb4_general_ci	latin1_swedish_ci

customer_order_transaction_report_procedure	NO_ENGINE_SUBSTITUTION	CREATE DEFINER=`lextech`@`%` PROCEDURE `customer_order_transaction_report_procedure`()
BEGIN

DECLARE errorcode char (5);
DECLARE msg TEXT;
DECLARE recordCount int(11);

DROP TABLE IF EXISTS customer_order_transaction_report;

CREATE TABLE customer_order_transaction_report(
	trans_source varchar(12),
store varchar(256),
customer_id int(11) unsigned,
first_name varchar(256),
last_name varchar(256),
order_id int(10) unsigned,
transaction_id int(11) unsigned,
transaction_type varchar(14),
payment_type varchar(6),
parent_transaction_id int(11) unsigned,
currency_type varchar(3),
transaction_amount decimal(15, 4),
transaction_notes varchar(255),
transaction_date varchar(10),
transaction_time time,
transaction_day varchar(9),
payout_date varchar(10),
payout_time time,
payout_day varchar(9),
item_total decimal(14, 4),
credits_used binary(0),
promo_amount decimal(14, 4),
tax decimal(14, 4),
application_fee decimal(14, 4),
franchise_payout decimal(14, 4),
stripe_fee decimal(14, 4)
);

insert into customer_order_transaction_report
(
trans_source,
store,
customer_id,
first_name,
last_name,
order_id,
transaction_id,
transaction_type,
payment_type,
parent_transaction_id,
currency_type,
transaction_amount,
transaction_notes,
transaction_date,
transaction_time,
transaction_day,
payout_date,
payout_time,
payout_day,
item_total,
credits_used,
promo_amount,
tax,
application_fee,
franchise_payout,
stripe_fee
)
select 
TransSource,
Store,
CustomerId,
FirstName,
LastName,
OrderId,
TransactionId,
TransactionType,
PaymentType,
ParentTransactionId,
CurrencyType,
TransactionAmount,
TransactionNotes,
DATE_FORMAT(STR_TO_DATE(TransactionDate, '%m/%d/%Y'), '%Y/%m/%d'),
TransactionTime,
TransactionDay,
DATE_FORMAT(STR_TO_DATE(PayoutDate, '%m/%d/%Y'), '%Y/%m/%d'),
PayoutTime,
PayoutDay,
ItemTotal,
CreditsUsed,
PromoAmount,
Tax,
ApplicationFee,
FranchisePayout,
StripeFee
 from v_CustomerOrderTransactionReport;

SELECT 0;

END	utf8mb4	utf8mb4_general_ci	latin1_swedish_ci

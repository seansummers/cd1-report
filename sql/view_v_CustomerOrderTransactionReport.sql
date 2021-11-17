v_CustomerOrderTransactionReport	CREATE ALGORITHM=UNDEFINED DEFINER=`lextech`@`%` SQL SECURITY DEFINER VIEW `v_CustomerOrderTransactionReport` AS select 'Transaction' AS `TransSource`,`clean`.`name` AS `Store`,`user`.`id` AS `CustomerId`,`user`.`first_name` AS `FirstName`,`user`.`last_name` AS `LastName`,`trans`.`order_id` AS `OrderId`,`trans`.`id` AS `TransactionId`,`trans`.`type` AS `TransactionType`,`trans`.`payment_type` AS `PaymentType`,`trans`.`parent_id` AS `ParentTransactionId`,`trans`.`status` AS `TransactionStatus`,`trans`.`external_transaction_id` AS `ExternalTransactionId`,`trans`.`currency` AS `CurrencyType`,(case when (`trans`.`payment_type` = 'Credit') then round(((`trans`.`amount` / 100) * -(1)),2) else round((`trans`.`amount` / 100),2) end) AS `TransactionAmount`,`trans`.`notes` AS `TransactionNotes`,date_format(cast(`trans`.`created` as date),'%m/%d/%Y') AS `TransactionDate`,cast(`trans`.`created` as time) AS `TransactionTime`,dayname(`trans`.`created`) AS `TransactionDay`,date_format(cast(`trans`.`payout_date` as date),'%m/%d/%Y') AS `PayoutDate`,cast(`trans`.`payout_date` as time) AS `PayoutTime`,dayname(`trans`.`payout_date`) AS `PayoutDay`,NULL AS `ItemTotal`,NULL AS `CreditsUsed`,NULL AS `PromoAmount`,NULL AS `Tax`,round((`trans`.`application_fee` / 100),2) AS `ApplicationFee`,round((`trans`.`payout` / 100),2) AS `FranchisePayout`,round((`trans`.`stripe_fee` / 100),2) AS `StripeFee` from (((`users` `user` join `orders` `ord` on((`user`.`id` = `ord`.`user_id`))) join `transactions` `trans` on((`ord`.`id` = `trans`.`order_id`))) left join `cleaners` `clean` on((`ord`.`cleaner_id` = `clean`.`id`))) union select 'Subscription' AS `TransSource`,`clean`.`name` AS `Store`,`user`.`id` AS `CustomerId`,`user`.`first_name` AS `FirstName`,`user`.`last_name` AS `LastName`,NULL AS `OrderId`,`subtrans`.`id` AS `TransactionId`,`subtrans`.`type` AS `TransactionType`,`subtrans`.`payment_type` AS `PaymentType`,`subtrans`.`parent_id` AS `ParentTransactionId`,`subtrans`.`status` AS `TransactionStatus`,`subtrans`.`external_transaction_id` AS `ExternalTransactionId`,`subtrans`.`currency` AS `CurrencyType`,(case when (`subtrans`.`payment_type` = 'Credit') then round(((`subtrans`.`amount` / 100) * -(1)),2) else round(((`subtrans`.`amount` / 100) - (`subtrans`.`stripe_credit_amount` / 100)),2) end) AS `TransactionAmount`,`subtrans`.`notes` AS `TransactionNotes`,date_format(cast(`subtrans`.`created` as date),'%m/%d/%Y') AS `TransactionDate`,cast(`subtrans`.`created` as time) AS `TransactionTime`,dayname(`subtrans`.`created`) AS `TransactionDay`,date_format(cast(`subtrans`.`payout_date` as date),'%m/%d/%Y') AS `PayoutDate`,cast(`subtrans`.`payout_date` as time) AS `PayoutTime`,dayname(`subtrans`.`payout_date`) AS `PayoutDay`,round((`subtrans`.`amount` / 100),2) AS `ItemTotal`,round((`subtrans`.`stripe_credit_amount` / 100),2) AS `CreditsUsed`,round(((`subtrans`.`promo_amount` / 100) * -(1)),2) AS `PromoAmount`,round((`subtrans`.`tax` / 100),2) AS `Tax`,round((`subtrans`.`application_fee` / 100),2) AS `ApplicationFee`,round((`subtrans`.`payout` / 100),2) AS `FranchisePayout`,round((`subtrans`.`stripe_fee` / 100),2) AS `StripeFee` from ((`users` `user` join `subscription_transactions` `subtrans` on((`user`.`id` = `subtrans`.`user_id`))) left join `cleaners` `clean` on((`subtrans`.`cleaner_id` = `clean`.`id`)))	utf8mb4	utf8mb4_general_ci
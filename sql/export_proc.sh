#! /bin/bash -xe

mysql -Nrs --delimiter='//' -e 'show create procedure order_report_procedure//' scamperlaundry >proc_order_report_procedure.sql
mysql -Nrs --delimiter='//' -e 'show create procedure customer_report_procedure//' scamperlaundry >proc_customer_report_procedure.sql
mysql -Nrs --delimiter='//' -e 'show create procedure customer_order_transaction_report_procedure//' scamperlaundry >proc_customer_order_transaction_report_procedure.sql
mysql -Nrs --delimiter='//' -e 'show create procedure invoice_balance_procedure_orders//' scamperlaundry >proc_invoice_balance_procedure_orders.sql
mysql -Nrs --delimiter='//' -e 'show create procedure invoice_balance_procedure_subscriptions//' scamperlaundry >proc_invoice_balance_procedure_subscriptions.sql
mysql -Nrs --delimiter='//' -e 'show create procedure xyz_calc_daily_store_driver_stats//' scamperlaundry >proc_xyz_calc_daily_store_driver_stats.sql
mysql -Nrs --delimiter='//' -e 'show create procedure abc_calc_daily_store_stats//' scamperlaundry >proc_abc_calc_daily_store_stats.sql


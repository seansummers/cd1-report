#! /bin/bash -xe

mysql -Nrs --delimiter='//' -e 'show create view v_OrderReport//' scamperlaundry >view_v_OrderReport.sql
mysql -Nrs --delimiter='//' -e 'show create view v_CustomerReport//' scamperlaundry >view_v_CustomerReport.sql
mysql -Nrs --delimiter='//' -e 'show create view v_CustomerOrderTransactionReport//' scamperlaundry >view_v_CustomerOrderTransactionReport.sql

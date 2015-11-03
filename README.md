# GnuCash Statement Table

This is a [GnuCash](http://www.gnucash.org) report which generates a
table of periods and accounts based on a single assets account (the
base account), showing the cash flow to/from the base account in the
periods, and averages and totals. Clicking cells will show/hide a list
of the relevant transactions.

The report is based on the current needs of my personal finances,
which is why the report currently is based on the supposition that you
have a single(!) bank account for your daily income and expenses and
some savings accounts from which you move money back to your base
account when you use them. Flexibility will be added as I need it or
feel like it.

This is my first Scheme project ever. This means that:

1. You may want to double check against the similar standard reports
   Cash Flow and Income Statement.

2. If you read the code, beware that I use syntax extensions just for
   fun.


## Installation

### Step 1

Run `make` or use [lessc](http://lesscss.org/#using-less-installation)
manually to generate statement-table.css from statement-table.less.

### Step 2

Cf. the instructions for your operation system for loading custom
reports from your
[user account](http://wiki.gnucash.org/wiki/Custom_Reports#Load_the_report_from_a_user_account)
or your
[installed reports directory](http://wiki.gnucash.org/wiki/Custom_Reports#Load_the_report_from_the_installed_report_directory).

The file statement-table.scm is the report file. Copy all .scm, .js
and .css files to the directory.

The report will be found in Reports > Sample & Custom > Statement
table after restarting GnuCash.


## License

[GPLv2](https://www.gnu.org/licenses/gpl-2.0.html), like GnuCash.


## No warranty

There is absolutely no warranty that this report generates correct
results! Use at your own risk! Cf. the NO WARRANTY section of the
GPLv2.

# -*- perl -*-

use strict;
use DBI;

use lib ".";
use lib "t";
require "lib.pl";


use vars qw($dbdriver $test_dsn $test_user $test_password $state);


if ($dbdriver ne 'CSV') {
    print "1..0\n";
    exit 0;
}

# Extract the directory from the dsn
my $dir;
if ($test_dsn =~ /(.*)\;?f_dir=([^\;]*)\;?(.*)/) {
    $dir = $2;
    $test_dsn = $1 . (length($3) ? ";$3" : '');
} else {
    $dir = "output";
}
if (! -d $dir  &&  !mkdir $dir, 0755) {
    die "Cannot create directory $dir: $!";
}

while (Testing()) {
    #
    #   Connect to the database
    my $dbh;
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
                                        $test_password)))
	or die "Cannot connect";

    #
    #   Check, whether the f_dir attribute works
    #
    my $table = '';
    my $tableb = '';
    if (!$state) {
	$dbh->{f_dir} = $dir;
	print "Trying to create file $table in directory $dir.\n";
    }
    Test($state or (($table = FindNewTable($dbh))
		    and  !(-f "$dir/$table")))
	or print("Cannot determine a legal table name: Error ",
		 $dbh->errstr);
    Test($state or (($tableb = FindNewTable($dbh))
		    and  !(-f "$dir/$tableb")))
	or print("Cannot determine a legal table name: Error ",
		 $dbh->errstr);
    Test($state or ($table ne $tableb))
	or print("Second table name same as first.\n");

    my $query;
    Test($state or (($query = TableDefinition($table,
					  ["id", "INTEGER", 4, 0],
					  ["name", "CHAR", 64, 0]))
		    and $dbh->do($query)))
	or print("Cannot create table $table in directory $dir: ",
		 $dbh->errstr);
    Test($state or (-f "$dir/$table"))
	or print("No such file in directory $dir: $table");
    Test($state or ($dbh->do("DROP TABLE $table")  and  !(-f "$dir/$table")))
	or print("Cannot drop table $table in directory $dir: ",
		 $dbh->errstr());


    #
    #   Check, whether the csv_tables->{$table}->{file} attribute works
    #
    if (!$state) {
	$dbh->{csv_tables}->{$table}->{file} = $tableb;
	print "Trying to create file $tableb in directory $dir.\n";
    }
    Test($state or $dbh->do($query))
	or print("Cannot create table $table in directory $dir: ",
		 $dbh->errstr);
    Test($state or (-f "$dir/$tableb"))
	or print("No such file in directory $dir: $tableb");
    Test($state or ($dbh->do("DROP TABLE $table")  and  !(-f "$dir/$tableb")))
	or print("Cannot drop table $table in directory $dir: ",
		 $dbh->errstr());
}

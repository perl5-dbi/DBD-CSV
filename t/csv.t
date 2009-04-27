#/usr/bin/perl

use strict;
use DBI;

use lib ".";
use lib "t";
require "lib.pl";


use vars qw($test_dsn $test_user $test_password $state
            $haveFileSpec);

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
    Test($state
	 or (($table = FindNewTable($dbh))
	  and  !(-f ($haveFileSpec ?
		     File::Spec->catfile($dir, $table) : "$dir/$table"))))
	or print("Cannot determine a legal table name: Error ",
		 $dbh->errstr);
    Test($state
	 or (($tableb = FindNewTable($dbh))
	     and  !(-f ($haveFileSpec ?
			File::Spec->catfile($dir, $tableb) : "$dir/$tableb"))))
	or print("Cannot determine a legal table name: Error ",
		 $dbh->errstr);
    Test($state or ($table ne $tableb))
	or print("Second table name same as first.\n");

    my $cquery;
    Test($state or (($cquery = TableDefinition($table,
					       ["id", "INTEGER", 4, 0],
					       ["name", "CHAR", 64, 0]))
		    and $dbh->do($cquery)))
	or print("Cannot create table $table in directory $dir: ",
		 $dbh->errstr);
    Test($state
	 or (-f ($haveFileSpec ?
		 File::Spec->catfile($dir, $table) : "$dir/$table")))
	or print("No such file in directory $dir: $table");
    Test($state
	 or ($dbh->do("DROP TABLE $table")
	     and  !(-f ($haveFileSpec ?
			File::Spec->catfile($dir, $table) : "$dir/$table"))))
	or print("Cannot drop table $table in directory $dir: ",
		 $dbh->errstr());
    Test($state or $dbh->disconnect());


    #
    #   Try to read a semicolon separated file.
    #

    my $dsn = "DBI:CSV:f_dir=$dir;csv_eol=\015\012;csv_sep_char=\\;;";
    Test($state or ($dbh = DBI->connect($dsn)))
	or print "Cannot connect to DSN $dsn: $DBI::errstr\n";
    my $tablec;
    Test($state
	 or (($tablec = FindNewTable($dbh))
	     and  !(-f ($haveFileSpec ?
			File::Spec->catfile($dir, $tablec) : "$dir/$tablec"))))
	or print("Cannot determine a legal table name: Error ",
		 $dbh->errstr);
    if (!$state) {
	print "Trying to create file $tablec in directory $dir.\n";
    }
    Test($state or
	 $dbh->do("CREATE TABLE $tablec (id INTEGER, name CHAR(64))"))
	or print("Cannot create table $tablec: ", $dbh->errstr(), "\n");
    Test($state or
	 $dbh->do("INSERT INTO $tablec VALUES (1, ?)", undef, "joe"))
	or print("Cannot insert data into $tablec: ", $dbh->errstr(), "\n");
    Test($state or
	 $dbh->do("INSERT INTO $tablec VALUES (2, ?)", undef, "Jochen;"))
	or print("Cannot insert data into $tablec: ", $dbh->errstr(), "\n");
    my($sth, $ref);
    Test($state or
	 ($sth = $dbh->prepare("SELECT * FROM $tablec")))
	or print("Cannot prepare: ", $dbh->errstr(), "\n");
    Test($state or $sth->execute())
	or print("Cannot execute: ", $sth->errstr(), "\n");
    Test($state or (($ref = $sth->fetchrow_arrayref()) and
		    $ref->[0] eq "1" and $ref->[1] eq "joe"))
	or printf("Expected 1,joe, got %s,%s\n", ($ref->[0] || "undef"),
		  ($ref->[1] || "undef"));
    Test($state or (($ref = $sth->fetchrow_arrayref()) and
		    $ref->[0] eq "2" and $ref->[1] eq "Jochen;"))
	or printf("Expected 2,Jochen;, got %s,%s\n", ($ref->[0] || "undef"),
		  ($ref->[1] || "undef"));
    Test($state
	 or ($dbh->do("DROP TABLE $tablec")
	     and  !(-f ($haveFileSpec ?
			File::Spec->catfile($dir, $table) : "$dir/$tablec"))))
	or print("Cannot drop table $tablec in directory $dir: ",
		 $dbh->errstr());
    Test($state or $dbh->disconnect());

    #
    #   Check, whether the csv_tables->{$table}->{file} attribute works
    #
    $dsn = "DBI:CSV:";
    Test($state or ($dbh = DBI->connect($dsn)));
    if (!$state) {
	$dbh->{csv_tables}->{$table}->{file} =
	    $haveFileSpec ? File::Spec->catfile($dir, $tableb)
		: "$dir/$tableb";
	print "Trying to create file $tableb in directory $dir.\n";
    }
    Test($state or $dbh->do($cquery))
	or print("Cannot create table $table in directory $dir: ",
		 $dbh->errstr);
    Test($state
	 or (-f ($haveFileSpec ? File::Spec->catfile($dir, $tableb)
		 : "$dir/$tableb")))
	or print("No such file in directory $dir: $tableb");
    Test($state
	 or ($dbh->do("DROP TABLE $table")
	     and  !(-f ($haveFileSpec ?
			File::Spec->catfile($dir, $table) : "$dir/$tableb"))))
	or print("Cannot drop table $table in directory $dir: ",
		 $dbh->errstr());

}


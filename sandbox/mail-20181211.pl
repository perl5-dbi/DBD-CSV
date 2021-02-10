#!/pro/bin/perl

use strict;
use warnings;
use DBI;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_ext      => ".csv/r", 
    RaiseError => 1,
    }) or die "Cannot connect: $DBI::errstr";

unlink "sample.csv";
$dbh->do ("CREATE TABLE sample (field1 CHAR (10), field2 CHAR (10))");
$dbh->do ("INSERT INTO sample (field1, field2) VALUES ('sample1', 'text1')");
$dbh->do ("INSERT INTO sample (field1, field2) VALUES ('sample2', 'text2')");

{   print "TEST 1\n";
    my $query = $dbh->prepare ("select field1 from sample order by field2 desc");
    $query->execute;
    $query->bind_columns (\my ($field1));
    my $row = 1;
    while ($query->fetch) {
	print $row++, " field1 - $field1\n";
	}
    }

{   print "TEST 2\n";
    my $query = $dbh->prepare ("select field1, field2 from sample order by field2 desc");
    $query->execute;
    $query->bind_columns (\my ($field1, $field2));
    my $row = 1;
    while ($query->fetch) {
	print $row++, " field1 - $field1\n";
	}
    # Wrong result here
    }

$dbh->disconnect;

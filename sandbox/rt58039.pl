#!/pro/bin/perl

use strict;
use warnings;
use autodie;

use DBI;

# perl rt58039.pl 0 <- original code = FAIL
# perl rt58039.pl 1 <- modified code = PASS
my $ext = $ARGV[0] ? ".csv" : "";

my $dir = "rt58039";
-d $dir or mkdir $dir, 0777;
my @leftovers = glob "$dir/*";
   @leftovers and unlink @leftovers;
END { unlink glob "$dir/*"; rmdir $dir; }

my $file1 = "$dir/test_1$ext";    # with test_1.csv and test_2.csv it
my $file2 = "$dir/test_2$ext";

open my $fh, ">", $file1 or die $!;
print $fh join "\n",
    "id,name",
    "1,Brown",
    "2,Smith",
    "5,Green",
    "";
close $fh;
open $fh, ">", $file2 or die $!;
print $fh join "\n",
    "id,city",
    "1,Greenville",
    "2,Watertown",
    "8,Springville",
    "";
close $fh;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    RaiseError => 1,
    PrintError => 1,
    f_dir      => $dir,
    f_ext      => ".csv",
    });

my $table_1 = "test_1";
my $table_2 = "test_2";
eval {
    my $sth_old = $dbh->prepare (
	"SELECT a.id, a.name, b.city " .
	"FROM   $table_1 AS a NATURAL JOIN $table_2 AS b"
	);
    $sth_old->execute ();

    my $table = "new";
    $dbh->do ("DROP TABLE IF EXISTS $table");
    $dbh->do ("CREATE TABLE $table (id INT, name CHAR (64), city CHAR (64))");
    my $sth_new = $dbh->prepare (
	"INSERT INTO $table (id, name, city) VALUES (?, ?, ?)");

    print "id,name,city\n";
    my $count = 1;
    while (my $hash_ref = $sth_old->fetchrow_hashref ()) {
	print $count++, ",", $hash_ref->{"a.name"}, ",", $hash_ref->{"b.city"}, "\n";
	$sth_new->execute ($count++, $hash_ref->{"a.name"}, $hash_ref->{"b.city"});
	}
    };

$@ and warn $@;

$dbh->disconnect ();

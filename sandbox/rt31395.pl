#!/pro/bin/perl

use strict;
use warnings;

use Test::LeakTrace;

use DBI;

my $csvf = "sandbox/rt31395.csv";
unlink $csvf;

my $z = "z" x 10;
my $c = 10;

open  my $fh, ">", $csvf;
print $fh "id\n";
print $fh "$_$z\n" for 0 .. $c;
close $fh;

my $dbh = DBI->connect ("dbi:CSV:", "", "", {
    f_dir	=> "sandbox",
    f_ext	=> ".csv",
    RaiseError	=> 1,
    });

leaktrace {
    my $sth = $dbh->prepare (q;
	select count (*)
	from   rt31395
	where  id = ?
	limit  1
	;);
    my $n = 0;
    while ($n++ < $c) {
	$sth->execute ("$n$z") and printf STDERR "%7d %s\r", $n, $z;
	system "ps -lf $$";
	}

    $sth->finish;
    undef $sth;
    } -verbose;

print "DBI: $DBI::VERSION\n";
print "Text::CSV_XS: $Text::CSV_XS::VERSION\n";
print "SQL::Statement: $SQL::Statement::VERSION\n";

$dbh->disconnect;
unlink $csvf;

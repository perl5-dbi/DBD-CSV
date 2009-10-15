use strict;
use warnings;
use DBI;
use Test;

plan tests => 6;

my $table = "table$$";
unlink($table) if -f $table;

my $dbh = DBI->connect("DBI:CSV:");
ok(defined $dbh);

$dbh->do("CREATE TABLE $table (id INTEGER, name CHAR(64))");
$dbh->do("INSERT INTO $table VALUES (?, ?)", undef, 2, "foo");

my $sth = $dbh->prepare("SELECT * FROM $table WHERE id > 1 ORDER BY id");
$sth->execute();

my $row = $sth->fetchrow_hashref;
ok(defined $row);
ok(ref($row), "HASH");

ok($row->{id}, 2);
ok($row->{name}, "foo");

$row = $sth->fetchrow_hashref;
ok(!$row);

$sth = $dbh->prepare ("select id, count (*) from $table group by id");
$sth->execute;
use Data::Peek; DDumper $sth->{NAME_lc};

$sth->finish();
$dbh->disconnect();

unlink($table);

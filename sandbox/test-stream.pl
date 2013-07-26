#!/pro/bin/perl

use 5.14.1;
use warnings;

use DBI;
use DBD::File "0.43";
use Data::Peek;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    PrintError	=> 1,
    RaiseError	=> 1,
    });

my $foo = <<EOCSV;
c_foo,foo,desc
1,Mars,Chocolate bar
2,Tsaziki,Greek yoghurt with garlic and cucumber
3,Kaïpa,Some real great music
EOCSV
open my $fh_foo, "<", \$foo;

$dbh->{csv_tables}{foo} = { file => $fh_foo };

my $sth = $dbh->prepare ("select * from foo");
$sth->execute;
while (my $row = $sth->fetchrow_hashref) {
    DDumper ($row);
    }

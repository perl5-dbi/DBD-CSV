#!/pro/bin/perl

use strict;
use warnings;

use Data::Dumper;
use PROCURA::DBD;
use PROCURA::DBD_create;

my $dbh = DBDlogon (1);

{   local $dbh->{RaiseError} = 0;
    local $dbh->{PrintError} = 0;
    $dbh->drop_table ("b_test_null");
    $dbh->commit;
    }

$dbh->do (q;
    create table b_test_null (
	c_foo integer,
	chr   char (4),
	vch   varchar (4)
	););
$dbh->commit;

my @v = (
    undef,
    undef,
    "",
    " ",
    pack ("C",  13),
    pack ("CC", 32, 13),
    );
{   my $sth = prepar ("insert into b_test_null values (?, ?, ?)");
    for (1 .. 5) {
	$sth->execute ($_, $v[$_], $v[$_]);
	}
    $dbh->commit;
    }

my %v;
foreach my $cb (0, 1) {
    $dbh->{ChopBlanks} = $cb;
    my $sth = $dbh->prepare ("select chr, vch from b_test_null where c_foo = ?");
    for (1 .. 5) {
	$sth->execute ($_);
	my ($chr, $vch) = $sth->fetchrow_array;
	($v{c}{$cb}{$_} = defined $chr ? "'$chr'" : "NULL") =~ s/\r/\\r/g;
	($v{v}{$cb}{$_} = defined $vch ? "'$vch'" : "NULL") =~ s/\r/\\r/g;
	}
    }

$dbh->drop_table ("b_test_null");
$dbh->commit;

foreach my $t ("c", "v") {
    print "$t\t{ChopBlanks} = 0\t{ChopBlanks} = 1\n";
    foreach my $cb (0, 1) {
	for (1, 2, 3, 4, 5) {
	    printf " %-6s", "$v{$t}{$cb}{$_}";
	    }
	}
    print "\n";
    }

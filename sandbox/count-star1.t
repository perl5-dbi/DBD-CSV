#!/pro/bin/perl

use strict;
use warnings;
use DBI;

open my $fh, ">", "foo.csv";
print $fh "c_foo,foo,bar\n";
for (1 .. 40000) {
    print $fh join ",", $_, ("a".."f")[int rand 6], int rand 10, "\n";
    }
close $fh;

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_dir	=> ".",
    f_ext	=> ".csv/r",
    f_schema	=> "undef",

    RaiseError	=> 1,
    PrintError	=> 1,
    });

my ($foo, $cnt);
my $sth = $dbh->prepare (qq;
    select   foo, count (*)
    from     foo
    group by foo;);
$sth->execute;
#$sth->bind_columns (\$foo, \$cnt);
while (my $row = $sth->fetch) {
    printf "%-5s %6d\n", @$row;
    }

unlink "foo.csv";

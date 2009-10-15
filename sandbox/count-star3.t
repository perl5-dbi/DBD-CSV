#!/pro/bin/perl

use strict;
use warnings;

use Data::Peek;
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

my %foo;
my $sth = $dbh->prepare (qq;
    select   foo, count (*)
    from     foo
    group by foo;);
$sth->execute;
my @foo = @{$sth->{NAME_lc}};
DDumper \@foo;
$sth->bind_columns (\@foo{@foo});
while ($sth->fetch) {
    printf "%-5s %6d %4s %4s\n", @foo{@foo};
    }

unlink "foo.csv";

#!/pro/bin/perl

use strict;
use warnings;
use PROCURA::DBD;

open my $fh, ">", "foo.csv";
print $fh "c_foo,foo,bar\n";
for (1 .. 40000) {
    print $fh join ",", $_, ("a".."f")[int rand 6], int rand 10, "\n";
    }
close $fh;

my $dbh = DBDlogon (0);

my ($foo, $cnt);
my $sth = prepex (qq;
    select   foo, count (*)
    from     foo
    group by foo;);
print STDERR join "," => @{$sth->{NAME_lc}}, "\n";
while (my $row = $sth->fetch) {
    printf "%-5s %6d\n", @$row;
    }

unlink "foo.csv";

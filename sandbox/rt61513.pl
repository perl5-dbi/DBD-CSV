#!/pro/bin/perl

use warnings;
use strict;

use DBI;

my $new = shift || 0;
my $dinges = {
    col_names => [qw( login password uid gid realname directory shell )],
    file      => "/etc/passwd",
    };
my @csvt = $new ? ( csv_tables => { dinges => $dinges } ) : ();
my $dbh = DBI->connect ( "dbi:CSV:", undef, undef, {
    csv_sep_char    => ":",
    csv_quote_char  => undef,
    csv_escape_char => undef,
    csv_eol         => "\n",
    @csvt,
    });

# does *not* work with the csv_tables entry uncommented

$new or $dbh->{csv_tables} = { dinges => $dinges };

# now it *does* work

my $sth = $dbh->prepare ("select * from dinges where uid < 5 order by uid") or
    die "prepare failed: ", DBI::errstr, "\n";

$sth->execute or
    die "execute failed: ", DBI::errstr, "\n";

while (my $r = $sth->fetchrow_arrayref) {
    printf "%6d %6d %s\n", $r->[2], $r->[3], $r->[0];
    }

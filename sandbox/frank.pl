use strict;
use warnings;

use DBI;

my $dsn = q{DBI:CSV:f_dir=//cavcan01/E$/work/Frank/tasks/RMS-v9-events;csv_sep_char=   };
   $dsn = "dbi:CSV:";
my $dbh = DBI->connect ($dsn, undef, undef, {
    f_dir        => ".",
    csv_sep_char => "\t",
    RaiseError   => 1,
    AutoCommit   => 1,
    PrintError   => 1,
    }) or die "Database connection not made: $DBI::errstr";

foreach my $rg ("RMS9_adjusted_payoff_rg") {
    my $file = "20100323-RMS9-adjusted-payoff-rg.txt";
    $dbh->{csv_tables}{$rg} = {
	file		=> $file,
	eol		=> "\n",
	sep_char	=> "\t",
	col_names	=> [ qw( id rg )],
	skip_first_row	=> 0,
	};
    my $sql = "select * from $rg";
    my $sth = $dbh->prepare ($sql);
    $sth->execute;
    }

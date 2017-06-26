#!/pro/bin/perl

use 5.18.2;
use warnings;

use DBI;
use Test::More;

use lib ".";
use Record;
use VariableColumns qw{after_parse_combine_cols};

my $options = {
    csv_eol         => "\n",
    csv_sep_char    => " ",
    csv_escape_char => "\\",
    csv_callbacks   => {
        after_parse => \&after_parse_combine_cols,
        },
    };

my @cols = qw{a b how_many observations comment};

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_schema     => undef,
    f_dir        => ".",
    f_dir_search => [],
    f_ext        => ".csv/r",
    f_lock       => 2,
    f_encoding   => "utf8",

    %$options,

    csv_tables => {
	input => {
	    f_file    => "input.csv",
	    col_names => \@cols,
	    },
	},

    RaiseError       => 1,
    PrintError       => 1,
    FetchHashKeyName => "NAME_lc",
    }) or die $DBI::errstr;

ok ($dbh, "connect");

#$dbh->{csv_tables}{input} = { col_names => \@cols };

my $sth = $dbh->prepare ("select * from input");

$sth->execute;
my @rows;

while (my $row = $sth->fetchrow_hashref) {
    is (keys (%$row), @cols, "correct column count");
    push @rows, Record->new (%$row);
    }

$sth->finish;

diag "Records";
diag $_->to_string for @rows;

done_testing ();

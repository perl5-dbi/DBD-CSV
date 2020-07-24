#!/usr/bin/perl

use 5.18.2;
use warnings;

use DP;
use DBI;
use lib "/pro/3gl/CPAN/DBD-CSV/lib";
use lib "/pro/3gl/CPAN/DBD-CSV/blib/arch";
use lib "/pro/3gl/CPAN/DBD-CSV/blib/lib";

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_schema		=> undef,
    f_dir		=> ".",
    f_ext		=> ".csv/r",

    RaiseError		=> 1,
    PrintError		=> 1,
    }) or die "$DBI::errstr\n" || $DBI::errstr;

$dbh->{csv_tables}{tst} = {
    file		=> "test.csv",		# alias to f_file
    eol			=> "\n",		# alias to csv_eol
    sep_char		=> ";",			# alias to csv_sep_char
    always_quote	=> 1,			# alias to csv_always_quote
    col_names		=> [qw( c_tst s_tst )],
    };

#$dbh->{TraceLevel} = 99;

say for $dbh->tables (undef, undef, undef, undef);

$dbh->{csv_tables}{tools}{sep_char} = ";";	# should work

foreach my $t (qw( tools fruit )) {
    say $t;
    my $sth = $dbh->prepare ("select * from $t");
    $sth->execute;
    while (my @r = $sth->fetchrow_array) {
	printf "%4d %s\n", @r;
	}
    }

open my $fh, ">", "test.csv";close $fh;
# If empty should insert "c_tst";"s_tst"
$dbh->do ("insert into tst values (42, 'Test')");		# "42";"Test"
$dbh->do ("update tst set s_tst = 'Done' where c_tst = 42");	# "42";"Done"

$dbh->disconnect;

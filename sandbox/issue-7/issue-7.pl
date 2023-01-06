#!/pro/bin/perl

use 5.018002;
use warnings;

our $VERSION = "0.02 - 20200727";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD [--devel]";
    exit $err;
    } # usage

use CSV;
use DBI;
use Test::More;
use Getopt::Long qw(:config bundling);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "d|devel!"		=> \ my $opt_d,

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

if ($opt_d) {
    unshift @INC => "/pro/3gl/CPAN/DBD-CSV/lib";
    unshift @INC => "/pro/3gl/CPAN/DBD-CSV/blib/arch";
    unshift @INC => "/pro/3gl/CPAN/DBD-CSV/blib/lib";
    }

my $tfn = "test.csv";
foreach my $x (0, 1) {
    my ($fpfx, $cpfx) = $x ? ("f_", "csv_") : ("", "");
    my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
	"${fpfx}schema"		=> undef,
	"${fpfx}dir"		=> "files",
	"${fpfx}ext"		=> ".csv/r",

	"${cpfx}eol"		=> "\n",		# alias to csv_eol
	"${cpfx}always_quote"	=> 1,			# alias to csv_always_quote
	"${cpfx}sep_char"	=> ";",			# alias to csv_sep_char

	RaiseError		=> 1,
	PrintError		=> 1,
	}) or die "$DBI::errstr\n" || $DBI::errstr;

    my $ffn = "files/$tfn";
    unlink $ffn;
    $dbh->{csv_tables}{tst} = {
	file			=> $tfn,		# alias to f_file
	col_names		=> [qw( c_tst s_tst )],
	};

    is_deeply (
	[ sort $dbh->tables (undef, undef, undef, undef) ],
	[qw( fruit tools )],		"Tables");
    is_deeply (
	[ sort keys %{$dbh->{csv_tables}} ],
	[qw( fruit tools tst )],	"Mixed tables");

    $dbh->{csv_tables}{fruit}{sep_char} = ",";	# should work

    is_deeply ($dbh->selectall_arrayref ("select * from tools order by c_tool"),
	[ [ 1, "Hammer"		],
	  [ 2, "Screwdriver"	],
	  [ 3, "Drill"		],
	  [ 4, "Saw"		],
	  [ 5, "Router"		],
	  [ 6, "Hobbyknife"	],
	  ], "Sorted tools");
    is_deeply ($dbh->selectall_arrayref ("select * from fruit order by c_fruit"),
	[ [ 1, "Apple"		],
	  [ 2, "Blueberry"	],
	  [ 3, "Orange"		],
	  [ 4, "Melon"		],
	  ], "Sorted fruit");

    open my $fh, ">", $ffn;close $fh;
    # If empty should insert "c_tst";"s_tst"
    $dbh->do ("insert into tst values (42, 'Test')");			# "42";"Test"
    $dbh->do ("update tst set s_tst = 'Done' where c_tst = 42");	# "42";"Done"

    $dbh->disconnect;

    open  $fh, "<", $ffn or die "$ffn: $!\n";
    my @dta = <$fh>;
    close $fh;
    is ($dta[-1], qq{"42";"Done"\n}, "Table tst written to $ffn");
    unlink $ffn;
    }

done_testing;

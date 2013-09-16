package DBI::Test::Case::DBD::CSV::t30_insertfetch;

# Test row insertion and retrieval

use strict;
use warnings;

use parent qw( DBI::Test::DBD::CSV::Case );

use Test::More;
use DBI::Test;
use DBI;

sub supported_variant
{
    my ($self,    $test_case, $cfg_pfx, $test_confs,
        $dsn_pfx, $dsn_cred,  $options) = @_;

    $self->is_test_for_mocked ($test_confs) and return;

    return $self->SUPER::supported_variant ($test_case, $cfg_pfx, $test_confs,
        $dsn_pfx, $dsn_cred, $options);
    } # supported_variant

use vars q{$AUTOLOAD};

sub AUTOLOAD
{
    (my $sub = $AUTOLOAD) =~ s/.*:/DBI::Test::DBD::CSV::Case::/;
    {   no strict "refs";
        $sub->(@_);
        }
    } # AUTOLOAD

my @tbl_def = (
    [ "id",   "INTEGER",  4, 0 ],
    [ "name", "CHAR",    64, 0 ],
    [ "val",  "INTEGER",  4, 0 ],
    [ "txt",  "CHAR",    64, 0 ],
    );

sub run_test
{
    my ($self, $dbc) = @_;
    my @DB_CREDS = @$dbc;
    $DB_CREDS[3]->{PrintError} = 0;
    $DB_CREDS[3]->{RaiseError} = 0;
    $DB_CREDS[3]->{f_dir} = DbDir();
    if ($ENV{DBI_PUREPERL}) {
        eval "use Text::CSV;";
        $@ or $DB_CREDS[3]->{csv_class} = "Text::CSV"
        }

    defined $ENV{DBI_SQL_NANO} or
        eval "use SQL::Statement;";

    # START OF TESTS

    my $dbh = connect_ok(@DB_CREDS,	"connect");

    ok (my $tbl = FindNewTable ($dbh),	"find new test table");
    $tbl ||= "tmp99";
    eval {
        local $SIG{__WARN__} = sub {};
        $dbh->do ("drop table $tbl");
        };
    
    like (my $def = TableDefinition ($tbl, @tbl_def),
	    qr{^create table $tbl}i,	"table definition");
    
    my $sz = 0;
    ok ($dbh->do ($def),		"create table");
    my $tbl_file = DbFile ($tbl);
    ok ($sz = -s $tbl_file,		"file exists");
    
    ok ($dbh->do ("insert into $tbl values ".
	          "(1, 'Alligator Descartes', 1111, 'Some Text')"), "insert");
    ok ($sz < -s $tbl_file,		"file grew");
    $sz = -s $tbl_file;
    
    ok ($dbh->do ("insert into $tbl (id, name, val, txt) values ".
	          "(2, 'Crocodile Dundee',    2222, 'Down Under')"), "insert with field names");
    ok ($sz < -s $tbl_file,		"file grew");
    
    ok (my $sth = $dbh->prepare ("select * from $tbl where id = 1"), "prepare");
    is (ref $sth, "DBI::st",		"handle type");
    
    ok ($sth->execute,			"execute");
    
    ok (my $row = $sth->fetch,		"fetch");
    is (ref $row, "ARRAY",		"returned a list");
    is ($sth->errstr, undef,		"no error");
    
    is_deeply ($row, [ 1, "Alligator Descartes", 1111, "Some Text" ], "content");
    
    ok ($sth->finish,			"finish");
    undef $sth;
    
    # Try some other capitilization
    ok ($dbh->do ("DELETE FROM $tbl WHERE id = 1"),	"delete");
    
    # Now, try SELECT'ing the row out. This should fail.
    ok ($sth = $dbh->prepare ("select * from $tbl where id = 1"), "prepare");
    is (ref $sth, "DBI::st",		"handle type");
    
    ok ($sth->execute,			"execute");
    is ($sth->fetch,  undef,		"fetch");
    is ($sth->errstr, undef,		"error");	# ???
    
    ok ($sth->finish,			"finish");
    undef $sth;
    
    ok ($sth = $dbh->prepare ("insert into $tbl values (?, ?, ?, ?)"), "prepare insert");
    ok ($sth->execute (3, "Babar", 3333, "Elephant"), "insert prepared");
    ok ($sth->finish,			"finish");
    undef $sth;
    
    ok ($sth = $dbh->prepare ("insert into $tbl (id, name, val, txt) values (?, ?, ?, ?)"), "prepare insert with field names");
    ok ($sth->execute (4, "Vischje", 33, "in het riet"), "insert prepared");
    ok ($sth->finish,			"finish");
    undef $sth;
    
    ok ($dbh->do ("delete from $tbl"),	"delete all");
    ok ($dbh->do ("insert into $tbl (id) values (0)"), "insert just one field");
    {   local (@ARGV) = DbFile ($tbl);
        my @csv = <>;
        s/\r?\n\Z// for @csv;
        is (scalar @csv, 2,		"Just two lines");
        is ($csv[0], "id,name,val,txt",	"header");
        is ($csv[1], "0,,,",		"data");
        }
    
    ok ($dbh->do ("drop table $tbl"),	"drop");
    ok ($dbh->disconnect,		"disconnect");
    
    done_testing ();
    } # run_test

1;

package DBI::Test::Case::DBD::CSV::t30_insertfetch;

# Test row insertion and retrieval

use strict;
use warnings;

use parent qw( DBI::Test::DBD::CSV::Case );

use Test::More;
use DBI::Test;
# XXX already done by invoking *.t -- use DBI;

# we want more variants ...
sub requires_extended { 1 }

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

    # if this is required for more than this file, it should be maybe in the returned DSN credentials
    $DB_CREDS[3]->{PrintError} = 0;
    $DB_CREDS[3]->{RaiseError} = 0;
    # XXX following is done in DSN::Provider::Dir (inherited by DSN::Provider::CSV)
    # $DB_CREDS[3]->{f_dir} = DbDir ();

    # XXX This isn't really handled, but should be in DSN::Provider::CSV->supported_variant or so
    #if ($ENV{DBI_PUREPERL}) {
    #    eval "use Text::CSV;";
    #    $@ or $DB_CREDS[3]->{csv_class} = "Text::CSV"
    #    }

    # XXX is part of the test configuration, see "zvn_t*.t"
    #defined $ENV{DBI_SQL_NANO} or
    #    eval "use SQL::Statement;";

    # START OF TESTS

    my $dbh = connect_ok (@DB_CREDS,	"connect");

    ok (my $tbl = FindNewTable ($dbh),	"find new test table");
    $tbl ||= "tmp99";
    eval {
        local $SIG{__WARN__} = sub {};
        $dbh->do ("drop table $tbl");
        };
    
    like (my $def = TableDefinition ($tbl, @tbl_def),
	    qr{^create table $tbl}i,	"table definition");
    
    my $sz = 0;
    do_ok ($dbh, $def,			"create table");
    my $tbl_file = DbFile ($tbl);
    ok ($sz = -s $tbl_file,		"file exists");
    
    do_ok ($dbh, "insert into $tbl values ".
	          "(1, 'Alligator Descartes', 1111, 'Some Text')",
					"insert");
    ok ($sz < -s $tbl_file,		"file grew");
    $sz = -s $tbl_file;
    
    do_ok ($dbh, "insert into $tbl (id, name, val, txt) values ".
	          "(2, 'Crocodile Dundee',    2222, 'Down Under')",
					"insert with field names");
    ok ($sz < -s $tbl_file,		"file grew");
    
    my $sth = prepare_ok ($dbh, "select * from $tbl where id = 1",
					"prepare");
    
    execute_ok ($sth,			"execute");
    
    ok (my $row = $sth->fetch,		"fetch");
    is (ref $row, "ARRAY",		"returned a list");
    is ($sth->errstr, undef,		"no error");
    
    is_deeply ($row, [ 1, "Alligator Descartes", 1111, "Some Text" ],
					"content");
    
    ok ($sth->finish,			"finish");
    undef $sth;
    
    # Try some other capitilization
    do_ok ($dbh, "DELETE FROM $tbl WHERE id = 1",
					"delete");
    
    # Now, try SELECT'ing the row out. This should fail.
    $sth = prepare_ok ($dbh, "select * from $tbl where id = 1",
					"prepare");
    is (ref $sth, "DBI::st",		"handle type");
    
    execute_ok ($sth,			"execute");
    is ($sth->fetch,  undef,		"fetch");
    is ($sth->errstr, undef,		"error");	# ???
    
    ok ($sth->finish,			"finish");
    undef $sth;
    
    $sth = prepare_ok ($dbh, "insert into $tbl values (?, ?, ?, ?)",
					"prepare insert");
    execute_ok ($sth, 3, "Babar", 3333, "Elephant",
					"insert prepared");
    ok ($sth->finish,			"finish");
    undef $sth;
    
    $sth = prepare_ok ($dbh, "insert into $tbl (id, name, val, txt) values (?, ?, ?, ?)",
					"prepare insert with field names");
    execute_ok ($sth, 4, "Vischje", 33, "in het riet",
					"insert prepared");
    ok ($sth->finish,			"finish");
    undef $sth;
    
    do_ok ($dbh, "delete from $tbl",	"delete all");
    do_ok ($dbh, "insert into $tbl (id) values (0)",
					"insert just one field");
    {   local (@ARGV) = DbFile ($tbl);
        my @csv = <>;
        s/\r?\n\Z// for @csv;
        is (scalar @csv, 2,		"Just two lines");
        is ($csv[0], "id,name,val,txt",	"header");
        is ($csv[1], "0,,,",		"data");
        }
    
    do_ok ($dbh, "drop table $tbl",	"drop");
    ok ($dbh->disconnect,		"disconnect");
    
    done_testing ();
    } # run_test

1;

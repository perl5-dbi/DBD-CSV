package DBI::Test::Case::DBD::CSV::t31_delete;

# test if delete from shrinks table

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
    [ "id",   "INTEGER",  4, &COL_NULLABLE ],
    [ "name", "CHAR",    64, &COL_NULLABLE ],
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
    
    ok (my $tbl = FindNewTable ($dbh),			"find new test table");
    
    like (my $def = TableDefinition ($tbl, @tbl_def),
    	qr{^create table $tbl}i,			"table definition");
    ok ($dbh->do ($def),					"create table");
    
    my $sz = 0;
    my $tbl_file = DbFile ($tbl);
    ok ($sz = -s $tbl_file,					"file exists");
    
    ok ($dbh->do ("insert into $tbl values (1, 'Foo')"),	"insert");
    ok ($sz < -s $tbl_file,					"file grew");
    $sz = -s $tbl_file;
    
    ok ($dbh->do ("delete from $tbl where id = 1"),		"delete single");
    ok ($sz > -s $tbl_file,					"file shrank");
    $sz = -s $tbl_file;
    
    ok ($dbh->do ("insert into $tbl (id) values ($_)"),	"insert $_") for 1 .. 10;
    ok ($sz < -s $tbl_file,					"file grew");
    
    {   local $dbh->{PrintWarn}  = 0;
        local $dbh->{PrintError} = 0;
        is ($dbh->do ("delete from wxyz where id = 99"), undef,	"delete non-existing tbl");
        }
    my  $zero_ret = $dbh->do ("delete from $tbl where id = 99");
    ok ($zero_ret, "true non-existing delete RV (via do)");
    cmp_ok ($zero_ret, "==", 0,    "delete non-existing row (via do)");
    is ($dbh->do ("delete from $tbl where id =  9"), 1,    "delete single (count) (via do)");
    is ($dbh->do ("delete from $tbl where id >  7"), 2,    "delete more   (count) (via do)");
    
    $zero_ret = $dbh->prepare ("delete from $tbl where id = 88")->execute;
    ok ($zero_ret, "true non-existing delete RV (via prepare/execute)");
    cmp_ok ($zero_ret, "==", 0,    "delete non-existing row (via prepare/execute)");
    is ($dbh->prepare ("delete from $tbl where id =  7")->execute, 1, "delete single (count) (via prepare/execute)");
    is ($dbh->prepare ("delete from $tbl where id >  4")->execute, 2, "delete more   (count) (via prepare/execute)");
    
    ok ($dbh->do ("delete from $tbl"),			"delete all");
    is (-s $tbl_file, $sz,					"file reflects empty table");
    
    ok ($dbh->do ("drop table $tbl"),			"drop table");
    ok ($dbh->disconnect,					"disconnect");
    ok (!-f $tbl_file,					"file removed");
    
    done_testing ();
    } # run_test

1;

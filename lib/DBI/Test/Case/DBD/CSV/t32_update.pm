package DBI::Test::Case::DBD::CSV::t32_update;

# test if update returns expected values / keeps file sizes sane

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

my @tbl_def = (
    [ "id",   "INTEGER",  4, &COL_NULLABLE ],
    [ "name", "CHAR",    64, &COL_NULLABLE ],
    );

use vars q{$AUTOLOAD};
sub AUTOLOAD
{
    (my $sub = $AUTOLOAD) =~ s/.*:/DBI::Test::DBD::CSV::Case::/;
    {   no strict "refs";
        $sub->(@_);
        }
    } # AUTOLOAD

sub run_test
{
    my ($self, $dbc) = @_;
    my @DB_CREDS = @$dbc;
    $DB_CREDS[3]->{PrintError} = 0;
    $DB_CREDS[3]->{RaiseError} = 0;
    $DB_CREDS[3]->{f_dir} = DbDir ();
    if ($ENV{DBI_PUREPERL}) {
        eval "use Text::CSV;";
        $@ or $DB_CREDS[3]->{csv_class} = "Text::CSV"
        }

    defined $ENV{DBI_SQL_NANO} or
        eval "use SQL::Statement;";

    my $dbh = connect_ok (@DB_CREDS,			"connect");
    
    ok (my $tbl = FindNewTable ($dbh),			"find new test table");
    
    like (my $def = TableDefinition ($tbl, @tbl_def),
    	qr{^create table $tbl}i,			"table definition");
    do_ok ($dbh, $def,					"create table");
    
    my $sz = 0;
    my $tbl_file = DbFile ($tbl);
    ok ($sz = -s $tbl_file,				"file exists");
    
    do_ok ($dbh, "insert into $tbl (id) values ($_)",	"insert $_") for 1 .. 10;
    ok ($sz < -s $tbl_file,				"file grew");
    $sz = -s $tbl_file;
    
    {   local $dbh->{PrintWarn}  = 0;
        local $dbh->{PrintError} = 0;
        is ($dbh->do ("update wxyz set name = 'ick' where id = 99"), undef,	"update in non-existing tbl");
        }
    my  $zero_ret = do_ok ($dbh, "update $tbl set name = 'ack' where id = 99", "update");
    ok ($zero_ret, "true non-existing update RV (via do)");
    cmp_ok ($zero_ret, "==", 0, "update non-existing row (via do)");
    
    cmp_ok ($sz, "==", -s $tbl_file, "file size did not change on noop updates");
    
    is (do_ok ($dbh, "update $tbl set name = 'multis' where id >  7", "update"), 3, "update several (count) (via do)");
    cmp_ok ($sz, "<", -s $tbl_file, "file size grew on update");
    
    $sz = -s $tbl_file;
    is (do_ok ($dbh, "update $tbl set name = 'single' where id =  9", "update"), 1, "update single (count) (via do)");
    cmp_ok ($sz, "==", -s $tbl_file, "file size did not change on same-size update");
    
    
    $zero_ret = execute_ok (prepare_ok ($dbh, "update $tbl set name = 'ack' where id = 88", "update"), "execute");
    ok ($zero_ret, "true non-existing update RV (via prepare/execute)");
    cmp_ok ($zero_ret, "==", 0,    "update non-existing row (via prepare/execute)");
    cmp_ok ($sz, "==", -s $tbl_file, "file size did not change on noop update");
    
    $sz = -s $tbl_file;
    is (execute_ok (prepare_ok ($dbh, "update $tbl set name = 'multis' where id < 4", "update"), "execute"), 3, "update several (count) (via prepare/execute)");
    cmp_ok ($sz, "<", -s $tbl_file, "file size grew on update");
    
    $sz = -s $tbl_file;
    is (execute_ok (prepare_ok ($dbh, "update $tbl set name = 'single' where id = 2", "update"), "execute"), 1, "update single (count) (via prepare/execute)");
    cmp_ok ($sz, "==", -s $tbl_file, "file size did not change on same-size update");
    
    do_ok ($dbh, "drop table $tbl",			"drop table");
    ok ($dbh->disconnect,				"disconnect");
    ok (!-f $tbl_file,					"file removed");
    
    done_testing ();
    } # run_test

1;

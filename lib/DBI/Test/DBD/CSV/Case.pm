#!/usr/bin/perl

package DBI::Test::DBD::CSV::Case;

use strict;
use warnings;

use parent qw( DBI::Test::Case );
use Carp   qw( carp );

sub filter_drivers
{
    my ($self, $options, @test_dbds) = @_;
    return grep m{\b CSV \b}x => @test_dbds;
    } # filter_drivers

sub requires_extended { 0 }

sub supported_variant
{
    my ($self,    $test_case, $cfg_pfx, $test_confs,
	$dsn_pfx, $dsn_cred,  $options) = @_;

    if ($self->is_test_for_dbi ($test_confs)) {
	$dsn_cred  && $dsn_cred->[0] or return;
	(my $driver = $dsn_cred->[0]) =~
	    s/^dbi:(\w*?)(?:\((.*?)\))?:.*/DBD::$1/i;
	eval "require $driver;";
	$@ and return carp $@;
	$driver->isa ("DBD::File") and return 1;
	}

    return;
    } # supported_variant

use File::Spec;

my $testname  = "output$$";
my $base_dir  = File::Spec->rel2abs (File::Spec->curdir ());
my $test_dir  = File::Spec->rel2abs ($testname);
my $test_dsn  = $ENV{DBI_DSN}  || "DBI:CSV:f_dir=$testname";
my $test_user = $ENV{DBI_USER} || "";
my $test_pass = $ENV{DBI_PASS} || "";

sub COL_NULLABLE () { 1 }
sub COL_KEY      () { 2 }

sub AnsiTypeToDb
{
    my ($self, $type, $size) = @_;
    my $uctype = uc $type;

    if ($uctype eq "CHAR" || $uctype eq "VARCHAR") {
	$size ||= 1;
	return "$uctype ($size)";
	}

    $uctype eq "BLOB" || $uctype eq "REAL" || $uctype eq "INTEGER" and
	return $uctype;

    $uctype eq "INT" and
	return "INTEGER";

    warn "Unknown type $type\n";
    return $type;
    } # AnsiTypeToDb

# This function generates a table definition based on an input list.  The input
# list consists of references, each reference referring to a single column. The
# column reference consists of column name, type, size and a bitmask of certain
# flags, namely
#
#   COL_NULLABLE - true, if this column may contain NULL's
#   COL_KEY      - true, if this column is part of the table's primary key

sub TableDefinition
{
    my ($self, $tablename, @cols) = @_;

    my @keys = ();
    foreach my $col (@cols) {
	$col->[2] & COL_KEY and push @keys, $col->[0];
	}

    my @colDefs;
    foreach my $col (@cols) {
	my $colDef = $col->[0] . " " . AnsiTypeToDb ($self, $col->[1], $col->[2]);
	$col->[3] & COL_NULLABLE or $colDef .= " NOT NULL";
	push @colDefs, $colDef;
	}
    my $keyDef = @keys ? ", PRIMARY KEY (" . join (", ", @keys) . ")" : "";
    my $tq = $tablename =~ m/^\w+\./ ? qq{"$tablename"} : $tablename;
    return sprintf "CREATE TABLE %s (%s%s)", $tq,
	join (", ", @colDefs), $keyDef;
    } # TableDefinition

# This function generates a list of tables associated to a given DSN.
sub ListTables
{
    my $self = shift;
    my $dbh  = shift or return;

    my @tables = $dbh->func ("list_tables");
    my $msg = $dbh->errstr || $DBI::errstr;
    $msg and die "Cannot create table list: $msg";
    @tables;
    } # ListTables

sub DbCleanup
{
    chdir $base_dir;
    -d $testname or return;
    chdir $testname or BAIL_OUT ("Cleanup failed");
    unlink glob "*";
    chdir $base_dir;
    rmdir $testname;
    } # DbCleanup

mkdir $testname, 0755;
END { DbCleanup (); }

# This functions generates a list of possible DSN's aka
# databases and returns a possible table name for a new
# table being created.
#
# Problem is, we have two different situations here: Test scripts
# call us by pasing a dbh, which is fine for most situations.
{   my $listTablesHook;

    my $testtable = "testaa";
    my $listed    = 0;

    my @tables;

    sub FindNewTable
    {
	my ($self, $dbh) = @_;

	unless ($listed) {
	       if (defined $listTablesHook) {
		@tables = $listTablesHook->($dbh);
		}
	    elsif (defined &ListTables) {
		@tables = ListTables ($self, $dbh);
		}
	    else {
		die "Fatal: ListTables not implemented.\n";
		}
	    $listed = 1;
	    }

	# A small loop to find a free test table we can use to mangle stuff in
	# and out of. This starts at testaa and loops until testaz, then testba
	# - testbz and so on until testzz.
	my $foundtesttable = 1;
	my $table;
	while ($foundtesttable) {
	    $foundtesttable = 0;
	    foreach $table (@tables) {
		if ($table eq $testtable) {
		    $testtable++;
		    $foundtesttable = 1;
		    }
		}
	    }
	$table = $testtable;
	$testtable++;
	return $table;
	} # FindNewTable
    }

sub ServerError
{
    die "# Cannot connect: $DBI::errstr\n";
    } # ServerError

sub Connect
{
    my $self = shift;
    my $attr = @_ && ref $_[-1] eq "HASH" ? pop @_ : {};
    my ($dsn, $usr, $pass) = @_;
    $dsn  ||= $test_dsn;
    $usr  ||= $test_user;
    $pass ||= $test_pass;
    my $dbh = DBI->connect ($dsn, $usr, $pass, $attr) or ServerError;
    $dbh;
    } # Connect

sub DbDir
{
    @_ and $test_dir = File::Spec->catdir ($base_dir, shift);
    $test_dir;
    } # DbDir

sub DbFile
{
    my $file = shift or return;
    File::Spec->catdir ($test_dir, $file);
    } # DbFile

1;

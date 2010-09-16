#!/pro/bin/perl
#
#   DBD::CSV - A DBI driver for CSV and similar structured files
#
#   This module is currently maintained by
#
#	H.Merijn Brand <h.m.brand@xs4all.nl>
#
#   The original author is Jochen Wiedmann.
#   Then maintained by Jeff Zucker
#
#   Copyright (C) 2010 by H.Merijn Brand
#   Copyright (C) 2004 by Jeff Zucker
#   Copyright (C) 1998 by Jochen Wiedmann
#
#   All rights reserved.
#
#   You may distribute this module under the terms of either the GNU
#   General Public License or the Artistic License, as specified in
#   the Perl README file.

require 5.005003;
use strict;

require DynaLoader;
require DBD::File;
require IO::File;

package DBD::CSV;

use strict;

use vars qw( @ISA $VERSION $drh $err $errstr $sqlstate );

@ISA =   qw( DBD::File );

$VERSION  = "0.31";

$err      = 0;		# holds error code   for DBI::err
$errstr   = "";		# holds error string for DBI::errstr
$sqlstate = "";         # holds error state  for DBI::state
$drh      = undef;	# holds driver handle once initialized

sub CLONE		# empty method: prevent warnings when threads are cloned
{
    } # CLONE

# --- DRIVER -------------------------------------------------------------------

package DBD::CSV::dr;

use strict;

use Text::CSV_XS ();
use vars qw( @ISA @CSV_TYPES );

@CSV_TYPES = (
    Text::CSV_XS::IV (), # SQL_TINYINT
    Text::CSV_XS::IV (), # SQL_BIGINT
    Text::CSV_XS::PV (), # SQL_LONGVARBINARY
    Text::CSV_XS::PV (), # SQL_VARBINARY
    Text::CSV_XS::PV (), # SQL_BINARY
    Text::CSV_XS::PV (), # SQL_LONGVARCHAR
    Text::CSV_XS::PV (), # SQL_ALL_TYPES
    Text::CSV_XS::PV (), # SQL_CHAR
    Text::CSV_XS::NV (), # SQL_NUMERIC
    Text::CSV_XS::NV (), # SQL_DECIMAL
    Text::CSV_XS::IV (), # SQL_INTEGER
    Text::CSV_XS::IV (), # SQL_SMALLINT
    Text::CSV_XS::NV (), # SQL_FLOAT
    Text::CSV_XS::NV (), # SQL_REAL
    Text::CSV_XS::NV (), # SQL_DOUBLE
    );

@DBD::CSV::dr::ISA = qw( DBD::File::dr );

$DBD::CSV::dr::imp_data_size     = 0;
$DBD::CSV::dr::data_sources_attr = undef;

$DBD::CSV::ATTRIBUTION = "DBD::CSV $DBD::CSV::VERSION by H.Merijn Brand";

sub connect
{
    my ($drh, $dbname, $user, $auth, $attr) = @_;
    my $dbh = $drh->DBD::File::dr::connect ($dbname, $user, $auth, $attr);
    $dbh->{f_meta} ||= {};
    $dbh->{Active}   = 1;
    $dbh;
    } # connect

# --- DATABASE -----------------------------------------------------------------

package DBD::CSV::db;

use strict;

$DBD::CSV::db::imp_data_size = 0;

@DBD::CSV::db::ISA = qw( DBD::File::db );

sub set_versions
{
    my $this = shift;
    $this->{csv_version} = $DBD::CSV::VERSION;
    return $this->SUPER::set_versions ();
    } # set_versions

if ($DBD::File::VERSION <= 0.38) {
    # Map csv_tables to f_meta.
    # Not absolutely needed, but otherwise I have to write two test suites
    *STORE = sub {
	my ($self, @attr) = @_;
	@attr && $attr[0] eq "csv_tables" and $attr[0] = "f_meta";
	$self->SUPER::STORE (@attr);
	}; # STORE

    *FETCH = sub {
	my ($self, @attr) = @_;
	@attr && $attr[0] eq "csv_tables" and $attr[0] = "f_meta";
	$self->SUPER::FETCH (@attr);
	}; # FETCH

    *DBI::db::csv_versions = *csv_versions = sub {
	join "\n",
	    "DBD::CSV     $DBD::CSV::VERSION using Text::CSV_XS-$Text::CSV_XS::VERSION",
	    "  DBD::File  $DBD::File::VERSION",
	    "DBI          $DBI::VERSION",
	    "OS           $^O",
	    "Perl         $]";
	}; # csv_versions
    }

my %csv_xs_attr;

sub init_valid_attributes
{
    my $dbh = shift;

    my @xs_attr = qw(
	allow_loose_escapes allow_loose_quotes allow_whitespace
	always_quote auto_diag binary blank_is_undef empty_is_undef
	eol escape_char keep_meta_info quote_char quote_null
	quote_space sep_char types verbatim );
    @csv_xs_attr{@xs_attr} = ();

    $dbh->{csv_xs_valid_attrs} = [ @xs_attr ];

    $dbh->{csv_valid_attrs} = { map {("csv_$_" => 1 )} @xs_attr, qw(

	class tables in csv_in out csv_out skip_first_row

	null sep quote escape
	)};

    $dbh->{csv_readonly_attrs} = { };

    $dbh->{csv_meta} = "csv_tables";

    return $dbh->SUPER::init_valid_attributes ();
    } # init_valid_attributes

sub get_csv_versions
{
    my ($dbh, $table) = @_;
    $table ||= "";
    my $class = $dbh->{ImplementorClass};
    $class =~ s/::db$/::Table/;
    my $meta;
    $table and (undef, $meta) = $class->get_table_meta ($dbh, $table, 1);
    unless ($meta) {
	$meta = {};
	$class->bootstrap_table_meta ($dbh, $meta, $table);
	}
    my $dvsn  = eval { $meta->{csv_class}->VERSION (); };
    my $dtype = $meta->{csv_class};
    $dvsn and $dtype .= " ($dvsn)";
    return sprintf "%s using %s", $dbh->{csv_version}, $dtype;
    } # get_csv_versions 

# --- STATEMENT ----------------------------------------------------------------

package DBD::CSV::st;

use strict;

$DBD::CSV::st::imp_data_size = 0;

@DBD::CSV::st::ISA = qw(DBD::File::st);

$DBD::File::VERSION <= 0.38 and *FETCH = sub {
    my ($sth, $attr) = @_;

    my ($struct, @coldefs, @colnames);

    # Being a bit dirty here, as SQL::Statement::Structure does not offer
    # me an interface to the data I want
    $struct   = $sth->{f_stmt}{struct} || {};
    @coldefs  = @{ $struct->{column_defs} || [] };
    @colnames = map { $_->{name} || $_->{value} } @coldefs;

    # dangerous: this accesses the table_defs information from last CREATE TABLE statement
    $attr eq "TYPE"      and
	return [ map { $struct->{table_defs}{columns}{$_}{data_type}   || "CHAR" }
		    @colnames ];

    $attr eq "PRECISION" and
	return [ map { $struct->{table_defs}{columns}{$_}{data_length} || 0 }
		    @colnames ];

    $attr eq "NULLABLE"  and
	return [ map { ( grep m/^NOT NULL$/ =>
		    @{ $struct->{table_defs}{columns}{$_}{constraints} || [] } )
		       ? 0 : 1 }
		    @colnames ];

    return $sth->SUPER::FETCH ($attr);
    }; # FETCH

package DBD::CSV::Statement;

use strict;
use DBD::File;
use Carp;

@DBD::CSV::Statement::ISA = qw(DBD::File::Statement);

# open_table (0 is used up to and including DBI-1.1611
# Later versions use open_file (see DBD::CSV::Table)

$DBD::File::VERSION <= 0.38 and *open_table = sub {
    my ($self, $data, $table, $createMode, $lockMode) = @_;

    my $dbh    = $data->{Database};
    my $tables = $dbh->{f_meta};
       $tables->{$table} ||= {};
    my $meta   = $tables->{$table} || {};
    my $csv_in = $meta->{csv_in} || $dbh->{csv_csv_in};
    unless ($csv_in) {
	my %opts  = ( binary => 1, auto_diag => 1 );

	# Allow specific Text::CSV_XS options
	foreach my $key (grep m/^csv_/ => keys %$dbh) {
	    (my $attr = $key) =~ s/csv_//;
	    $attr =~ m{^(?: eol | sep | quote | escape	# Handled below
			  | tables | sql_parser_object	# Not for Text::CSV_XS
			  | sponge_driver | version	# internal
			  )$}x and next;
	    $opts{$attr} = $dbh->{$key};
	    }
	delete $opts{null} and
	    $opts{blank_is_undef} = $opts{always_quote} = 1;

	my $class = $meta->{class} || $dbh->{csv_class} || "Text::CSV_XS";
	my $eol   = $meta->{eol}   || $dbh->{csv_eol}   || "\r\n";
	$eol =~ m/^\A(?:[\r\n]|\r\n)\Z/ or $opts{eol} = $eol;
	for ([ "sep",    ',' ],
	     [ "quote",  '"' ],
	     [ "escape", '"' ],
	     ) {
	    my ($attr, $def) = ($_->[0]."_char", $_->[1]);
	    $opts{$attr} =
		exists $meta->{$attr} ? $meta->{$attr} :
		    exists $dbh->{"csv_$attr"} ? $dbh->{"csv_$attr"} : $def;
	    }
	$meta->{csv_in}  = $class->new (\%opts) or
	    $class->error_diag;
	$opts{eol} = $eol;
	$meta->{csv_out} = $class->new (\%opts) or
	    $class->error_diag;
	}
    my $file = $meta->{file} || $table;
    my $tbl  = $self->SUPER::open_table ($data, $file, $createMode, $lockMode);
    if ($tbl && $tbl->{fh}) {
	$tbl->{csv_csv_in}  = $meta->{csv_in};
	$tbl->{csv_csv_out} = $meta->{csv_out};
	if (my $types = $meta->{types}) {
	    # The 'types' array contains DBI types, but we need types
	    # suitable for Text::CSV_XS.
	    my $t = [];
	    for (@{$types}) {
		$_ = $_
		    ? $DBD::CSV::dr::CSV_TYPES[$_ + 6] || Text::CSV_XS::PV ()
		    : Text::CSV_XS::PV ();
		push @$t, $_;
		}
	    $tbl->{types} = $t;
	    }
	if ( !$createMode and
	     !$self->{ignore_missing_table} and $self->{command} ne "DROP") {
	    my $array;
	    my $skipRows = exists $meta->{skip_rows}
		? $meta->{skip_rows}
		: exists $meta->{col_names} ? 0 : 1;
	    if ($skipRows--) {
		$array = $tbl->fetch_row ($data) or croak "Missing first row";
		unless ($self->{raw_header}) {
		    s/\W/_/g for @$array;
		    }
		$tbl->{col_names} = $array;
		while ($skipRows--) {
		    $tbl->fetch_row ($data);
		    }
		}
	    $tbl->{first_row_pos} = $tbl->{fh}->tell ();
	    exists $meta->{col_names} and
		$array = $tbl->{col_names} = $meta->{col_names};
	    if (!$tbl->{col_names} || !@{$tbl->{col_names}}) {
		# No column names given; fetch first row and create default
		# names.
		my $ar = $tbl->{cached_row} = $tbl->fetch_row ($data);
		$array = $tbl->{col_names};
		push @$array, map { "col$_" } 0 .. $#$ar;
		}
	    my $i = 0;
	    $tbl->{col_nums}{$_} = $i++ for @$array;
	    }
	}
    $tbl;
    }; # open_table

package DBD::CSV::Table;

use strict;
use DBD::File;
use Carp;

@DBD::CSV::Table::ISA = qw(DBD::File::Table);

sub bootstrap_table_meta
{
    my ($self, $dbh, $meta, $table) = @_;
    $meta->{csv_class} ||= $dbh->{csv_class} || "Text::CSV_XS";
    $meta->{csv_eol}   ||= $dbh->{csv_eol}   || "\r\n";
    exists $meta->{csv_skip_first_row} or
	$meta->{csv_skip_first_row} = $dbh->{csv_skip_first_row};
    $self->SUPER::bootstrap_table_meta ($dbh, $meta, $table);
    } # bootstrap_table_meta

sub init_table_meta
{
    my ($self, $dbh, $meta, $table) = @_;

    $self->SUPER::init_table_meta ($dbh, $table, $meta);

    my $csv_in = $meta->{csv_in} || $dbh->{csv_csv_in};
    unless ($csv_in) {
	my %opts = ( binary => 1, auto_diag => 1 );

	# Allow specific Text::CSV_XS options
	foreach my $attr (@{$dbh->{csv_xs_valid_attrs}}) {
	    $attr eq "eol" and next; # Handles below
	    exists $dbh->{"csv_$attr"} and $opts{$attr} = $dbh->{"csv_$attr"};
	    }
	$dbh->{csv_null} || $meta->{csv_null} and
	    $opts{blank_is_undef} = $opts{always_quote} = 1;

	my $class = $meta->{csv_class};
	my $eol   = $meta->{csv_eol};
	$eol =~ m/^\A(?:[\r\n]|\r\n)\Z/ or $opts{eol} = $eol;
	for ([ "sep",    ',' ],
	     [ "quote",  '"' ],
	     [ "escape", '"' ],
	     ) {
	    my ($attr, $def) = ($_->[0]."_char", $_->[1]);
	    $opts{$attr} =
		exists $meta->{$attr} ? $meta->{$attr} :
		    exists $dbh->{"csv_$attr"} ? $dbh->{"csv_$attr"} : $def;
	    }
	$meta->{csv_in}  = $class->new (\%opts) or
	    $class->error_diag;
	$opts{eol} = $eol;
	$meta->{csv_out} = $class->new (\%opts) or
	    $class->error_diag;
	}
    } # init_table_meta

my %compat_map = map { $_ => "csv_$_" }
    qw( class eof  eol quote_char sep_char escape_char );

__PACKAGE__->register_compat_map (\%compat_map);

sub table_meta_attr_changed
{
    my ($class, $meta, $attr, $value) = @_;

    (my $csv_attr = $attr) =~ s/^csv_//;
    if (exists $csv_xs_attr{$csv_attr}) {
	for ("csv_in", "csv_out") {
	    exists $meta->{$_} && exists $meta->{$_}{$csv_attr} and
		$meta->{$_}{$csv_attr} = $value;
	    }
	}

    $class->SUPER::table_meta_attr_changed ($meta, $attr, $value);
    } # table_meta_attr_changed

$DBD::File::VERSION > 0.38 and *open_file = sub {
    my ($self, $meta, $attrs, $flags) = @_;
    $self->SUPER::open_file ($meta, $attrs, $flags);

    my $tbl = $meta;
    if ($tbl && $tbl->{fh}) {
	$attrs->{csv_csv_in}  = $meta->{csv_in};
	$attrs->{csv_csv_out} = $meta->{csv_out};
	if (my $types = $meta->{types}) {
	    # XXX $meta->{types} is nowhere assigned and should better $meta->{csv_types}
	    # The 'types' array contains DBI types, but we need types
	    # suitable for Text::CSV_XS.
	    my $t = [];
	    for (@{$types}) {
		$_ = $_
		    ? $DBD::CSV::dr::CSV_TYPES[$_ + 6] || Text::CSV_XS::PV ()
		    : Text::CSV_XS::PV ();
		push @$t, $_;
		}
	    $tbl->{types} = $t;
	    }
	if (!$flags->{createMode}) {
	    my $array;
	    my $skipRows = defined $meta->{skip_rows}
		? $meta->{skip_rows}
		: defined $meta->{csv_skip_first_row}
		    ? 1
		    : exists $meta->{col_names} ? 0 : 1;
	    defined $meta->{skip_rows} or
		$meta->{skip_rows} = $skipRows;
	    if ($skipRows--) {
		$array = $attrs->{csv_csv_in}->getline ($tbl->{fh}) or
		    croak "Missing first row due to ".$attrs->{csv_csv_in}->error_diag;
		unless ($meta->{raw_header}) {
		    s/\W/_/g for @$array;
		    }
		$tbl->{col_names} = $array;
		while ($skipRows--) {
		    $tbl->{csv_csv_in}->getline ($tbl->{fh});
		    }
		}
	    $tbl->{first_row_pos} = $tbl->{fh}->tell ();
	    exists $meta->{col_names} and
		$array = $tbl->{col_names} = $meta->{col_names};
	    if (!$tbl->{col_names} || !@{$tbl->{col_names}}) {
		# No column names given; fetch first row and create default
		# names.
		my $ar = $tbl->{cached_row} =
		    $tbl->{csv_csv_in}->getline ($tbl->{fh});
		$array = $tbl->{col_names};
		push @$array, map { "col$_" } 0 .. $#$ar;
		}
	    my $i = 0;
	    $tbl->{col_nums}{$_} = $i++ for @$array; # XXX not necessary for DBI > 1.611
	    }
	}
    }; # open_file

sub fetch_row
{
    my ($self, $data) = @_;

    exists $self->{cached_row} and
	return $self->{row} = delete $self->{cached_row};

    my $tbl = $DBD::File::VERSION <= 0.38 ? $self : $self->{meta};

    my $csv = $self->{csv_csv_in} or
	return do { $data->set_err ($DBI::stderr, "Fetch from undefined handle"); undef };

    my $fields;
    eval { $fields = $csv->getline ($tbl->{fh}) };
    unless ($fields) {
	$csv->eof and return;

	my @diag = $csv->error_diag;
	my $file = $DBD::File::VERSION <= 0.38 ? $self->{file} : $tbl->{f_fqfn};
	croak "Error $diag[0] while reading file $file: $diag[1]";
	}
    @$fields < @{$tbl->{col_names}} and
	push @$fields, (undef) x (@{$tbl->{col_names}} - @$fields);
    $self->{row} = (@$fields ? $fields : undef);
    } # fetch_row

sub push_row
{
    my ($self, $data, $fields) = @_;
    my $tbl = $DBD::File::VERSION <= 0.38 ? $self : $self->{meta};
    my $csv = $self->{csv_csv_out};
    my $fh  = $tbl->{fh};

    unless ($csv->print ($fh, $fields)) {
	my @diag = $csv->error_diag;
	my $file = $DBD::File::VERSION <= 0.38 ? $self->{file} : $tbl->{f_fqfn};
	croak "Error $diag[0] while writing file $file: $diag[1]";
	}
    1;
    } # push_row
*push_names = \&push_row;

1;

__END__

=head1 NAME

DBD::CSV - DBI driver for CSV files

=head1 SYNOPSIS

    use DBI;
    # See "Creating database handle" below
    $dbh = DBI->connect ("dbi:CSV:") or
	die "Cannot connect: $DBI::errstr";

    # Simple statements
    $dbh->do ("CREATE TABLE a (id INTEGER, name CHAR (10))") or
	die "Cannot prepare: " . $dbh->errstr ();

    # Selecting
    $dbh->{RaiseError} = 1;
    my $sth = $dbh->prepare ("select * from foo");
    $sth->execute;
    while (my @row = $sth->fetchrow_array) {
	print "id: $row[0], name: $row[1]\n";
	}

    # Updates
    my $sth = $dbh->prepare ("UPDATE a SET name = ? WHERE id = ?");
    $sth->execute ("DBI rocks!", 1);
    $sth->finish;

    $dbh->disconnect;

=head1 DESCRIPTION

The DBD::CSV module is yet another driver for the DBI (Database independent
interface for Perl). This one is based on the SQL "engine" SQL::Statement
and the abstract DBI driver DBD::File and implements access to so-called
CSV files (Comma Separated Values). Such files are often used for exporting
MS Access and MS Excel data.

See L<DBI> for details on DBI, L<SQL::Statement> for details on
SQL::Statement and L<DBD::File> for details on the base class DBD::File.

=head2 Prerequisites

The only system dependent feature that DBD::File uses, is the C<flock ()>
function. Thus the module should run (in theory) on any system with
a working C<flock ()>, in particular on all Unix machines and on Windows
NT. Under Windows 95 and MacOS the use of C<flock ()> is disabled, thus
the module should still be usable.

Unlike other DBI drivers, you don't need an external SQL engine or a
running server. All you need are the following Perl modules, available
from any CPAN mirror, for example

  http://search.cpan.org/

=over 4

=item DBI

The DBI (Database independent interface for Perl), version 1.00 or
a later release

=item DBD::File

This is the base class for DBD::CSV, and it is part of the DBI
distribution. As DBD::CSV requires version 0.38 or newer for DBD::File
it effectively requires DBI version 1.611 or newer.

=item SQL::Statement

A simple SQL engine. This module defines all of the SQL syntax for
DBD::CSV, new SQL support is added with each release so you should
look for updates to SQL::Statement regularly.

It is possible to run C<DBD::CSV> without this module if you define
the environment variable C<$DBI_SQL_NANO> to 1. This will reduce the
SQL support a lot though. See L<DBI::SQL::Nano> for more details. Note
that the test suite does not test in this mode!

=item Text::CSV_XS

This module is used for writing rows to or reading rows from CSV files.

=back

=head2 Installation

Installing this module (and the prerequisites from above) is quite simple.
The simplest way is to install the bundle:

    $ cpan Bundle::CSV

Alternatively, you can name them all

    $ cpan Text::CSV_XS DBI DBD::CSV

or even trust C<cpan> to resolve all dependencies for you:

    $ cpan DBD::CSV

If you cannot, for whatever reason, use cpan, fetch all modules from
CPAN, and build with a sequence like:

    gzip -d < DBD-CSV-0.28.tgz | tar xf -

(this is for Unix users, Windows users would prefer WinZip or something
similar) and then enter the following:

    cd DBD-CSV-0.28
    perl Makefile.PL
    make test

If any tests fail, let us know. Otherwise go on with

    make install UNINST=1

Note that you almost definitely need root or administrator permissions.
If you don't have them, read the ExtUtils::MakeMaker man page for details
on installing in your own directories. L<ExtUtils::MakeMaker>.

=head2 Supported SQL Syntax

All SQL processing for DBD::CSV is done by the L<SQL::Statement> module.
Features include joins, aliases, built-in and user-defined functions,
and more.  See L<SQL::Statement::Syntax> for a description of the SQL
syntax supported in DBD::CSV.

Table names are case insensitive unless quoted.

=head1 Using DBD::CSV with DBI

For most things, DBD-CSV operates the same as any DBI driver.
See L<DBI> for detailed usage.

=head2 Creating a database handle (connect)

Creating a database handle usually implies connecting to a database server.
Thus this command reads

    use DBI;
    my $dbh = DBI->connect ("dbi:CSV:", "", "", {
	f_dir => "/home/user/folder",
	});

The directory tells the driver where it should create or open tables (a.k.a.
files). It defaults to the current directory, so the following are equivalent:

    $dbh = DBI->connect ("dbi:CSV:");
    $dbh = DBI->connect ("dbi:CSV:", undef, undef, { f_dir => "." });
    $dbh = DBI->connect ("dbi:CSV:f_dir=.");

We were told, that VMS might - for whatever reason - require:

    $dbh = DBI->connect ("dbi:CSV:f_dir=");

The preferred way of passing the arguments is by driver attributes:

    # specify most possible flags via driver flags
    $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
	f_schema         => undef,
	f_dir            => "data",
	f_ext            => ".csv/r",
	f_lock           => 2,
	f_encoding       => "utf8",

	csv_eol          => "\r\n",
	csv_sep_char     => ",",
	csv_quote_char   => '"',
	csv_escape_char  => '"',
	csv_class        => "Text::CSV_XS",
	csv_null         => 1,
	csv_tables       => {
	    info => { file => "info.csv" }
	    },

	RaiseError       => 1,
	PrintError       => 1,
	FetchHashKeyName => "NAME_lc",
	}) or die $DBI::errstr;

but you may set these attributes in the DSN as well, separated by semicolons.
Pay attention to the semi-colon for C<csv_sep_char> (as seen in many CSV
exports from MS Excel) is being escaped in below example, as is would
otherwise be seen as attribute separator:

    $dbh = DBI->connect (
	"dbi:CSV:f_dir=$ENV{HOME}/csvdb;f_ext=.csv;f_lock=2;" .
	"f_encoding=utf8;csv_eol=\n;csv_sep_char=\\;;" .
	"csv_quote_char=\";csv_escape_char=\\;csv_class=Text::CSV_XS;" .
	"csv_null=1") or die $DBI::errstr;

Using attributes in the DSN is easier to use when the DSN is derived from an
outside source (environment variable, database entry, or configure file),
whereas using all entries in the attribute hash is easier to read and to
maintain.

=head2 Creating and dropping tables

You can create and drop tables with commands like the following:

    $dbh->do ("CREATE TABLE $table (id INTEGER, name CHAR (64))");
    $dbh->do ("DROP TABLE $table");

Note that currently only the column names will be stored and no other data.
Thus all other information including column type (INTEGER or CHAR (x), for
example), column attributes (NOT NULL, PRIMARY KEY, ...) will silently be
discarded. This may change in a later release.

A drop just removes the file without any warning.

See L<DBI> for more details.

Table names cannot be arbitrary, due to restrictions of the SQL syntax.
I recommend that table names are valid SQL identifiers: The first
character is alphabetic, followed by an arbitrary number of alphanumeric
characters. If you want to use other files, the file names must start
with "/", "./" or "../" and they must not contain white space.

=head2 Inserting, fetching and modifying data

The following examples insert some data in a table and fetch it back:
First all data in the string:

    $dbh->do ("INSERT INTO $table VALUES (1, ".
	       $dbh->quote ("foobar") . ")");

Note the use of the quote method for escaping the word "foobar". Any
string must be escaped, even if it does not contain binary data.

Next an example using parameters:

    $dbh->do ("INSERT INTO $table VALUES (?, ?)", undef, 2,
	      "It's a string!");

Note that you don't need to use the quote method here, this is done
automatically for you. This version is particularly well designed for
loops. Whenever performance is an issue, I recommend using this method.

You might wonder about the C<undef>. Don't wonder, just take it as it
is. :-) It's an attribute argument that I have never ever used and
will be parsed to the prepare method as a second argument.

To retrieve data, you can use the following:

    my $query = "SELECT * FROM $table WHERE id > 1 ORDER BY id";
    my $sth   = $dbh->prepare ($query);
    $sth->execute ();
    while (my $row = $sth->fetchrow_hashref) {
	print "Found result row: id = ", $row->{id},
	      ", name = ", $row->{name};
	}
    $sth->finish ();

Again, column binding works: The same example again.

    my $sth = $dbh->prepare (qq;
	SELECT * FROM $table WHERE id > 1 ORDER BY id;
	;);
    $sth->execute;
    my ($id, $name);
    $sth->bind_columns (undef, \$id, \$name);
    while ($sth->fetch) {
	print "Found result row: id = $id, name = $name\n";
	}
    $sth->finish;

Of course you can even use input parameters. Here's the same example
for the third time:

    my $sth = $dbh->prepare ("SELECT * FROM $table WHERE id = ?");
    $sth->bind_columns (undef, \$id, \$name);
    for (my $i = 1; $i <= 2; $i++) {
	$sth->execute ($id);
	if ($sth->fetch) {
	    print "Found result row: id = $id, name = $name\n";
	    }
	$sth->finish;
	}

See L<DBI> for details on these methods. See L<SQL::Statement> for
details on the WHERE clause.

Data rows are modified with the UPDATE statement:

    $dbh->do ("UPDATE $table SET id = 3 WHERE id = 1");

Likewise you use the DELETE statement for removing rows:

    $dbh->do ("DELETE FROM $table WHERE id > 1");

=head2 Error handling

In the above examples we have never cared about return codes. Of course,
this cannot be recommended. Instead we should have written (for example):

    my $sth = $dbh->prepare ("SELECT * FROM $table WHERE id = ?") or
	die "prepare: " . $dbh->errstr ();
    $sth->bind_columns (undef, \$id, \$name) or
	die "bind_columns: " . $dbh->errstr ();
    for (my $i = 1; $i <= 2; $i++) {
	$sth->execute ($id) or
	    die "execute: " . $dbh->errstr ();
	$sth->fetch and
	    print "Found result row: id = $id, name = $name\n";
	}
    $sth->finish ($id) or die "finish: " . $dbh->errstr ();

Obviously this is tedious. Fortunately we have DBI's I<RaiseError>
attribute:

    $dbh->{RaiseError} = 1;
    $@ = "";
    eval {
	my $sth = $dbh->prepare ("SELECT * FROM $table WHERE id = ?");
	$sth->bind_columns (undef, \$id, \$name);
	for (my $i = 1; $i <= 2; $i++) {
	    $sth->execute ($id);
	    $sth->fetch and
		print "Found result row: id = $id, name = $name\n";
	    }
	$sth->finish ($id);
	};
    $@ and die "SQL database error: $@";

This is not only shorter, it even works when using DBI methods within
subroutines.

=head1 DBI database handle attributes

=head2 Metadata

The following attributes are handled by DBI itself and not by DBD::File,
thus they all work as expected:

    Active
    ActiveKids
    CachedKids
    CompatMode             (Not used)
    InactiveDestroy
    Kids
    PrintError
    RaiseError
    Warn                   (Not used)

The following DBI attributes are handled by DBD::File:

=over 4

=item AutoCommit

Always on

=item ChopBlanks

Works

=item NUM_OF_FIELDS

Valid after C<$sth-E<gt>execute>

=item NUM_OF_PARAMS

Valid after C<$sth-E<gt>prepare>

=item NAME

=item NAME_lc

=item NAME_uc

Valid after C<$sth-E<gt>execute>; undef for Non-Select statements.

=item NULLABLE

Not really working. Always returns an array ref of one's, as DBD::CSV
does not verify input data. Valid after C<$sth-E<gt>execute>; undef for
non-Select statements.

=back

These attributes and methods are not supported:

    bind_param_inout
    CursorName
    LongReadLen
    LongTruncOk

=head1 DBD-CSV specific database handle attributes

In addition to the DBI attributes, you can use the following dbh
attributes:

=over 4

=item f_dir

This attribute is used for setting the directory where CSV files are
opened. Usually you set it in the dbh, it defaults to the current
directory ("."). However, it is overwritable in the statement handles.

=item f_ext

This attribute is used for setting the file extension.

=item f_schema

This attribute allows you to set the database schema name. The default is
to use the owner of C<f_dir>. C<undef> is allowed, but not in the DSN part.

    my $dbh = DBI->connect ("dbi:CSV:", "", "", {
	f_schema => undef,
	f_dir    => "data",
	f_ext    => ".csv/r",
	}) or die $DBI::errstr;

=item f_encoding

This attribute allows you to set the encoding of the data. With CSV, it is
not possible to set (and remember) the encoding on a per-field basis, but
DBD::File now allows to set the encoding of the underlying file. If this
attribute is not set, or undef is passed, the file will be seen as binary.

=item f_lock

With this attribute, you can force locking mode (if locking is supported
at all) for opening tables. By default, tables are opened with a shared
lock for reading, and with an exclusive lock for writing. The supported
modes are:

=over 2

=item 0

Force no locking at all.

=item 1

Only shared locks will be used.

=item 2

Only exclusive locks will be used.

=back

But see L<DBD::File/"KNOWN BUGS">.

=item csv_eol

=item csv_sep_char

=item csv_quote_char

=item csv_escape_char

=item csv_class

=item csv_csv

The attributes I<csv_eol>, I<csv_sep_char>, I<csv_quote_char> and
I<csv_escape_char> are corresponding to the respective attributes of the
Text::CSV_XS object. You want to set these attributes if you have unusual
CSV files like F</etc/passwd> or MS Excel generated CSV files with a semicolon
as separator. Defaults are "\015\012", ';', '"' and '"', respectively.

The I<csv_eol> attribute defines the end-of-line pattern, which is better
known as a record separator pattern since it separates records.  The default
is windows-style end-of-lines "\015\012" for output (writing) and unset for
input (reading), so if on unix you may want to set this to newline ("\n")
like this:

  $dbh->{csv_eol} = "\n";

It is also possible to use multi-character patterns as record separators.
For example this file uses newlines as field separators (sep_char) and
the pattern "\n__ENDREC__\n" as the record separators (eol):

  name
  city
  __ENDREC__
  joe
  seattle
  __ENDREC__
  sue
  portland
  __ENDREC__

To handle this file, you'd do this:

  $dbh->{eol}      = "\n__ENDREC__\n" ,
  $dbh->{sep_char} = "\n"

The attributes are used to create an instance of the class I<csv_class>,
by default Text::CSV_XS. Alternatively you may pass an instance as
I<csv_csv>, the latter takes precedence. Note that the I<binary>
attribute I<must> be set to a true value in that case.

Additionally you may overwrite these attributes on a per-table base in
the I<csv_tables> attribute.

=item csv_null

With this option set, all new statement handles will set C<always_quote>
and C<blank_is_undef> in the CSV parser and writer, so it knows how to
distinguish between the empty string and C<undef> or C<NULL>. You cannot
reset it with a false value. You can pass it to connect, or set it later:

  $dbh = DBI->connect ("dbi:CSV:", "", "", { csv_null => 1 });

  $dbh->{csv_null} = 1;

=item csv_tables

This hash ref is used for storing table dependent metadata. For any
table it contains an element with the table name as key and another
hash ref with the following attributes:

=item csv_*

All other attributes that start with C<csv_> and are not described above
will be passed to C<Text::CSV_XS> (without the C<csv_> prefix). these
extra options are most likely to be only useful for reading (select)
handles. Examples:

  $dbh->{csv_allow_whitespace}    = 1;
  $dbh->{csv_allow_loose_quotes}  = 1;
  $dbh->{csv_allow_loose_escapes} = 1;

See the C<Text::CSV_XS> documentation for the full list and the documentation.

=over 4

=item file

The tables file name; defaults to

    "$dbh->{f_dir}/$table"

=item eol

=item sep_char

=item quote_char

=item escape_char

=item class

=item csv

These correspond to the attributes I<csv_eol>, I<csv_sep_char>,
I<csv_quote_char>, I<csv_escape_char>, I<csv_class> and I<csv_csv>.
The difference is that they work on a per-table base.

=item col_names

=item skip_first_row

By default DBD::CSV assumes that column names are stored in the first row
of the CSV file and sanitizes them (see C<raw_header> below). If this is
not the case, you can supply an array ref of table names with the
I<col_names> attribute. In that case the attribute I<skip_first_row> will
be set to FALSE.

If you supply an empty array ref, the driver will read the first row
for you, count the number of columns and create column names like
C<col0>, C<col1>, ...

=item raw_header

Due to the SQL standard, field names cannot contain special characters
like a dot (C<.>). Following the approach of mdb_tools, all these tokens
are translated to an underscore (C<_>) when reading the first line of the
CSV file, so all field names are `sanitized'. If you do not want this to
happen, set C<raw_header> to a true value. DBD::CSV cannot guarantee that
any part in the toolchain will work if field names have those characters,
and the chances are high that the SQL statements will fail.

=back

=back

It's strongly recommended to check the attributes supported by
L<DBD::File/Metadata>.

Example: Suggest you want to use F</etc/passwd> as a CSV file. :-)
There simplest way is:

    use DBI;
    my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
	f_dir           => "/etc",
	csv_sep_char    => ":",
	csv_quote_char  => undef,
	csv_escape_char => undef,
	});
    $dbh->{csv_tables}{passwd} = {
	col_names => [qw( login password uid gid realname
			  directory shell )];
	};
    $sth = $dbh->prepare ("SELECT * FROM passwd");

Another possibility where you leave all the defaults as they are and
overwrite them on a per table base:

    require DBI;
    my $dbh = DBI->connect ("dbi:CSV:");
    $dbh->{csv_tables}{passwd} = {
	eol         => "\n",
	sep_char    => ":",
	quote_char  => undef,
	escape_char => undef,
	file        => "/etc/passwd",
	col_names   => [qw( login password uid gid
			    realname directory shell )],
	};
    $sth = $dbh->prepare ("SELECT * FROM passwd");

=head2 Driver private methods

These methods are inherited from DBD::File:

=over 4

=item data_sources

The C<data_sources> method returns a list of sub-directories of the current
directory in the form "dbi:CSV:directory=$dirname".

If you want to read the sub-directories of another directory, use

    my $drh  = DBI->install_driver ("CSV");
    my @list = $drh->data_sources (f_dir => "/usr/local/csv_data");

=item list_tables

This method returns a list of file names inside $dbh->{directory}.
Example:

    my $dbh  = DBI->connect ("dbi:CSV:directory=/usr/local/csv_data");
    my @list = $dbh->func ("list_tables");

Note that the list includes all files contained in the directory, even
those that have non-valid table names, from the view of SQL. See
L<Creating and dropping tables> above.

=back

=head1 KNOWN ISSUES

=over 4

=item *

The module is using flock () internally. However, this function is not
available on platforms. Using flock () is disabled on MacOS and Windows
95: There's no locking at all (perhaps not so important on these
operating systems, as they are for single users anyways).

=back

=head1 TODO

=over 4

=item Tests

Aim for a full 100% code coverage

 - eol      Make tests for different record separators.
 - csv_xs   Test with a variety of combinations for
	    sep_char, quote_char, and escape_char testing
 - quoting  $dbh->do ("drop table $_") for DBI-tables ();
 - errors   Make sure that all documented exceptions are tested.
	    . write to write-protected file
	    . read from badly formatted csv
	    . pass bad arguments to csv parser while fetching

Add tests that specifically test DBD::File functionality where
that is useful.

=item RT

Attack all open DBD::CSV bugs in RT

=item CPAN::Forum

Attack all items in http://www.cpanforum.com/dist/DBD-CSV

=item Documentation

Expand on error-handling, and document all possible errors.
Use Text::CSV_XS::error_diag () wherever possible.

=item Debugging

Implement and document dbd_verbose.

=item Data dictionary

Investigate the possibility to store the data dictionary in a file like
.sys$columns that can store the field attributes (type, key, nullable).

=item Examples

Make more real-life examples from the docs in examples/

=back

=head1 SEE ALSO

L<DBI>, L<Text::CSV_XS>, L<SQL::Statement>, L<DBI::SQL::Nano>

For help on the use of DBD::CSV, see the DBI users mailing list:

  http://lists.cpan.org/showlist.cgi?name=dbi-users

For general information on DBI see

  http://dbi.perl.org/ and http://faq.dbi-support.com/

=head1 AUTHORS and MAINTAINERS

This module is currently maintained by

    H.Merijn Brand <h.m.brand@xs4all.nl>

in close cooperation with and help from

    Jens Rehsack <sno@NetBSD.org>

The original author is Jochen Wiedmann.
Previous maintainer was Jeff Zucker

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2010 by H.Merijn Brand
Copyright (C) 2004-2009 by Jeff Zucker
Copyright (C) 1998-2004 by Jochen Wiedmann

All rights reserved.

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=cut

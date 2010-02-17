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

$VERSION  = "0.27";

$err      = 0;		# holds error code   for DBI::err
$errstr   = "";		# holds error string for DBI::errstr
$sqlstate = "";         # holds error state  for DBI::state
$drh      = undef;	# holds driver handle once initialised

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
    $dbh->{csv_tables} ||= {};
    $dbh->{Active}       = 1;
    $dbh;
    } # connect

# --- DATABASE -----------------------------------------------------------------

package DBD::CSV::db;

use strict;

$DBD::CSV::db::imp_data_size = 0;

@DBD::CSV::db::ISA = qw( DBD::File::db );

sub csv_cache_sql_parser_object
{
    my $dbh = shift;
    my $parser = {
	dialect    => "CSV",
	RaiseError => $dbh->FETCH ("RaiseError"),
	PrintError => $dbh->FETCH ("PrintError"),
        };
    my $sql_flags  =  $dbh->FETCH ("csv_sql") || {};
    %$parser = (%$parser, %$sql_flags);
     $parser = SQL::Parser->new ($parser->{dialect}, $parser);
    $dbh->{csv_sql_parser_object} = $parser;
    return $parser;
    } # csv_cache_sql_parser_object

# --- STATEMENT ----------------------------------------------------------------

package DBD::CSV::st;

use strict;

$DBD::CSV::st::imp_data_size = 0;

@DBD::CSV::st::ISA = qw(DBD::File::st);

sub FETCH
{
    my ($sth, $attr) = @_;

    # Being a bit dirty here, as SQL::Statement::Structure does not offer
    # me an interface to the data I want
    my $struct = $sth->{f_stmt}{struct} || {};
    my @cols = @{ $struct->{column_names} || [] };

    $attr eq "TYPE"      and
	return [ map { $struct->{column_defs}{$_}{data_type}   || "CHAR" }
		    @cols ];

    $attr eq "PRECISION" and
	return [ map { $struct->{column_defs}{$_}{data_length} || 0 }
		    @cols ];

    $attr eq "NULLABLE"  and
	return [ map { ( grep m/^NOT NULL$/ =>
		    @{ $struct->{column_defs}{$_}{constraints} || [] } )
		       ? 0 : 1 }
		    @cols ];

    return $sth->SUPER::FETCH ($attr);
    } # FETCH

package DBD::CSV::Statement;

use strict;
use Carp;

@DBD::CSV::Statement::ISA = qw(DBD::File::Statement);

sub open_table
{
    my ($self, $data, $table, $createMode, $lockMode) = @_;
    my $dbh    = $data->{Database};
    my $tables = $dbh->{csv_tables};
       $tables->{$table} ||= {};
    my $meta   = $tables->{$table} || {};
    my $csv_in = $meta->{csv_in} || $dbh->{csv_csv_in};
    unless ($csv_in) {
	my %opts  = ( binary => 1 );

	# Allow specific Text::CSV_XS options
	foreach my $key (grep m/^csv_/ => keys %$dbh) {
	    (my $attr = $key) =~ s/csv_//;
	    $attr =~ m{^(?: eol | sep | quote | escape	# Handled below
			  | tables | sql_parser_object	# Not for Text::CSV_XS
			  | sponge_driver		# internal
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
		    : Text::CSV_XS::PV();
		push @$t, $_;
		}
	    $tbl->{types} = $t;
	    }
	if ( !$createMode and
	     !$self->{ignore_missing_table} and $self->command ne "DROP") {
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
    } # open_table

package DBD::CSV::Table;

use strict;
use Carp;

@DBD::CSV::Table::ISA = qw(DBD::File::Table);

sub fetch_row
{
    my ($self, $data) = @_;

    exists $self->{cached_row} and
	return $self->{row} = delete $self->{cached_row};

    my $csv = $self->{csv_csv_in} or
	return do { $data->set_err ($DBI::stderr, "Fetch from undefined handle"); undef };

    my $fields;
    eval { $fields = $csv->getline ($self->{fh}) };
    unless ($fields) {
	$csv->eof and return;

	my @diag = $csv->error_diag;
	croak "Error $diag[0] while reading file $self->{file}: $diag[1]";
	}
    @$fields < @{$self->{col_names}} and
	push @$fields, (undef) x (@{$self->{col_names}} - @$fields);
    $self->{row} = (@$fields ? $fields : undef);
    } # fetch_row

sub push_row
{
    my ($self, $data, $fields) = @_;
    my $csv = $self->{csv_csv_out};
    my $fh  = $self->{fh};

    unless ($csv->print ($fh, $fields)) {
	my @diag = $csv->error_diag;
	croak "Error $diag[0] while writing file $self->{file}: $diag[1]";
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
    $dbh = DBI->connect ("DBI:CSV:f_dir=/home/joe/csvdb") or
        die "Cannot connect: $DBI::errstr";
    $sth = $dbh->prepare ("CREATE TABLE a (id INTEGER, name CHAR(10))") or
        die "Cannot prepare: " . $dbh->errstr ();
    $sth->execute or die "Cannot execute: " . $sth->errstr ();
    $sth->finish;
    $dbh->disconnect;

    # Read a CSV file with ";" as the separator, as exported by
    # MS Excel. Note we need to escape the ";", otherwise it
    # would be treated as an attribute separator.
    $dbh = DBI->connect (qq{DBI:CSV:csv_sep_char=\\;});
    $sth = $dbh->prepare ("SELECT * FROM info");

    # Same example, this time reading "info.csv" as a table:
    $dbh = DBI->connect (qq{DBI:CSV:csv_sep_char=\\;});
    $dbh->{csv_tables}{info} = { file => "info.csv"};
    $sth = $dbh->prepare ("SELECT * FROM info");

=head1 DESCRIPTION

The DBD::CSV module is yet another driver for the DBI (Database independent
interface for Perl). This one is based on the SQL "engine" SQL::Statement
and the abstract DBI driver DBD::File and implements access to
so-called CSV files (Comma separated values). Such files are mostly used for
exporting MS Access and MS Excel data.

See L<DBI(3)> for details on DBI, L<SQL::Statement(3)> for details on
SQL::Statement and L<DBD::File(3)> for details on the base class DBD::File.

=head2 Prerequisites

The only system dependent feature that DBD::File uses, is the C<flock ()>
function. Thus the module should run (in theory) on any system with
a working C<flock ()>, in particular on all Unix machines and on Windows
NT. Under Windows 95 and MacOS the use of C<flock ()> is disabled, thus
the module should still be usable,

Unlike other DBI drivers, you don't need an external SQL engine
or a running server. All you need are the following Perl modules,
available from any CPAN mirror, for example

  ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module

=over 4

=item DBI

The DBI (Database independent interface for Perl), version 1.00 or
a later release

=item DBD::File

This is the base class for DBD::CSV, and it is included in the DBI
distribution. As DBD::CSV requires version 0.37 or newer for DBD::File
it effectively requires DBI version 1.609 or newer.

=item SQL::Statement

A simple SQL engine. This module defines all of the SQL syntax for
DBD::CSV, new SQL support is added with each release so you should
look for updates to SQL::Statement regularly.

=item Text::CSV_XS

This module is used for writing rows to or reading rows from CSV files.

=back

=head2 Installation

Installing this module (and the prerequisites from above) is quite simple.
You just fetch the archive, extract it with

    gzip -cd DBD-CSV-0.1000.tar.gz | tar xf -

(this is for Unix users, Windows users would prefer WinZip or something
similar) and then enter the following:

    cd DBD-CSV-0.1000
    perl Makefile.PL
    make
    make test

If any tests fail, let me know. Otherwise go on with

    make install

Note that you almost definitely need root or administrator permissions.
If you don't have them, read the ExtUtils::MakeMaker man page for details
on installing in your own directories. L<ExtUtils::MakeMaker>.

=head2 Supported SQL Syntax

All SQL processing for DBD::CSV is done by the L<SQL::Statement> module.
Features include joins, aliases, built-in and user-defined functions,
and more.  See L<SQL::Statement::Syntax> for a description of the SQL
syntax supported in DBD::CSV.

Table names are case insensitive unless quoted.

=head1 Using DBD-CSV with DBI

For most things, DBD-CSV operates the same as any DBI driver.
See L<DBI> for detailed usage.

=head2 Creating a database handle

Creating a database handle usually implies connecting to a database server.
Thus this command reads

    use DBI;
    my $dbh = DBI->connect ("DBI:CSV:f_dir=$dir");

The directory tells the driver where it should create or open tables
(a.k.a. files). It defaults to the current directory, thus the following
are equivalent:

    $dbh = DBI->connect ("DBI:CSV:");
    $dbh = DBI->connect ("DBI:CSV:f_dir=.");

(I was told, that VMS requires

    $dbh = DBI->connect ("DBI:CSV:f_dir=");

for whatever reasons.)

You may set other attributes in the DSN string, separated by semicolons.

=head2 Creating and dropping tables

You can create and drop tables with commands like the following:

    $dbh->do ("CREATE TABLE $table (id INTEGER, name CHAR(64))");
    $dbh->do ("DROP TABLE $table");

Note that currently only the column names will be stored and no other data.
Thus all other information including column type (INTEGER or CHAR(x), for
example), column attributes (NOT NULL, PRIMARY KEY, ...) will silently be
discarded. This may change in a later release.

A drop just removes the file without any warning.

See L<DBI(3)> for more details.

Table names cannot be arbitrary, due to restrictions of the SQL syntax.
I recommend that table names are valid SQL identifiers: The first
character is alphabetic, followed by an arbitrary number of alphanumeric
characters. If you want to use other files, the file names must start
with '/', './' or '../' and they must not contain white space.

=head2 Inserting, fetching and modifying data

The following examples insert some data in a table and fetch it back:
First all data in the string:

    $dbh->do ("INSERT INTO $table VALUES (1, ".
               $dbh->quote ("foobar") . ")");

Note the use of the quote method for escaping the word 'foobar'. Any
string must be escaped, even if it doesn't contain binary data.

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

See L<DBI(3)> for details on these methods. See L<SQL::Statement(3)> for
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
doesn't verify input data. Valid after C<$sth-E<gt>execute>; undef for
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

This attribute allows you to set the database schema name. The default
is to use the owner of C<f_dir>. C<undef> is allowed, but not in the DSN part.

    my $dbh = DBI->connect ("dbi:CSV:", "", "", {
        f_schema => undef,
        f_dir    => "data",
        f_ext    => ".csv/r",
        }) or die $DBI::errstr;

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

Example: Suggest you want to use F</etc/passwd> as a CSV file. :-)
There simplest way is:

    use DBI;
    my $dbh = DBI->connect ("DBI:CSV:f_dir=/etc;csv_eol=\n;".
                            "csv_sep_char=:;csv_quote_char=;".
                            "csv_escape_char=");
    $dbh->{csv_tables}{passwd} = {
        col_names => ["login", "password", "uid", "gid", "realname",
                      "directory", "shell"];
        };
    $sth = $dbh->prepare ("SELECT * FROM passwd");

Another possibility where you leave all the defaults as they are and
overwrite them on a per table base:

    require DBI;
    my $dbh = DBI->connect ("DBI:CSV:");
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

The C<data_sources> method returns a list of subdirectories of the current
directory in the form "DBI:CSV:directory=$dirname".

If you want to read the subdirectories of another directory, use

    my $drh  = DBI->install_driver ("CSV");
    my @list = $drh->data_sources (f_dir => "/usr/local/csv_data");

=item list_tables

This method returns a list of file names inside $dbh->{directory}.
Example:

    my $dbh  = DBI->connect ("DBI:CSV:directory=/usr/local/csv_data");
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

Add 'sane_colnames' attribute to allow weird characters in col_names.
Translate all illegal characters to '_' like mdb_tools does.

 s{[-\x00-\x20'":;.,/\\]}{_}g for @$row;

=item CPAN::Forum

Attack all items in http://www.cpanforum.com/dist/DBD-CSV

=item Documentation

Expand on error-handling, and document all possible errors.
Use Text::CSV_XS::error_diag () wherever possible.

=item Debugging

Implement and document dbd_verbose.

=item Encoding

Test how well UTF-8 is supported, if not (yet), enable UTF-8, and maybe
even more.

=item Data dictionary

Investigate the possibility to store the data dictionary in a file like
.sys$columns that can store the field attributes (type, key, nullable).

=item Examples

Make more real-life examples from the docs in examples/

=back

=head1 SEE ALSO

L<DBI(3)>, L<Text::CSV_XS(3)>, L<SQL::Statement(3)>

For help on the use of DBD::CSV, see the DBI users mailing list:

  http://lists.cpan.org/showlist.cgi?name=dbi-users

For general information on DBI see

  http://dbi.perl.org/ and http://faq.dbi-support.com/

=head1 AUTHORS and MAINTAINERS

This module is currently maintained by

    H.Merijn Brand <h.m.brand@xs4all.nl>

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

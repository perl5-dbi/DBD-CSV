# -*- perl -*-
#
#   DBD::CSV - A DBI driver for CSV and similar structured files
#
#   This module is Copyright (C) 1998 by
#
#       Jochen Wiedmann
#       Am Eisteich 9
#       72555 Metzingen
#       Germany
#
#       Email: joe@ispsoft.de
#       Phone: +49 7123 14887
#
#   All rights reserved.
#
#   You may distribute this module under the terms of either the GNU
#   General Public License or the Artistic License, as specified in
#   the Perl README file.
#

require 5.004;
use strict;


require DynaLoader;
require DBD::File;
require IO::File;


package DBD::CSV;

use vars qw(@ISA $VERSION $drh $err $errstr $sqlstate);

@ISA = qw(DBD::File);

$VERSION = '0.1013';

$err = 0;		# holds error code   for DBI::err
$errstr = "";		# holds error string for DBI::errstr
$sqlstate = "";         # holds error state  for DBI::state
$drh = undef;		# holds driver handle once initialised


package DBD::CSV::dr; # ====== DRIVER ======

use Text::CSV_XS qw(IV PV NV);

use vars qw(@ISA @CSV_TYPES);

@CSV_TYPES = (
    IV(), # SQL_TINYINT
    IV(), # SQL_BIGINT
    PV(), # SQL_LONGVARBINARY
    PV(), # SQL_VARBINARY
    PV(), # SQL_BINARY
    PV(), # SQL_LONGVARCHAR
    PV(), # SQL_ALL_TYPES
    PV(), # SQL_CHAR
    NV(), # SQL_NUMERIC
    NV(), # SQL_DECIMAL
    IV(), # SQL_INTEGER
    IV(), # SQL_SMALLINT
    NV(), # SQL_FLOAT
    NV(), # SQL_REAL
    NV(), # SQL_DOUBLE
);

@DBD::CSV::dr::ISA = qw(DBD::File::dr);

$DBD::CSV::dr::imp_data_size = 0;
$DBD::CSV::dr::data_sources_attr = undef;

sub connect ($$;$$$) {
    my($drh, $dbname, $user, $auth, $attr) = @_;

    my $this = $drh->DBD::File::dr::connect($dbname, $user, $auth, $attr);
    if (!exists($this->{csv_tables})) {
	$this->{csv_tables} = {};
    }

    $this;
}


package DBD::CSV::db; # ====== DATABASE ======

$DBD::CSV::db::imp_data_size = 0;

@DBD::CSV::db::ISA = qw(DBD::File::db);


package DBD::CSV::st; # ====== STATEMENT ======

$DBD::CSV::st::imp_data_size = 0;

@DBD::CSV::st::ISA = qw(DBD::File::st);


package DBD::CSV::Statement;

@DBD::CSV::Statement::ISA = qw(DBD::File::Statement);

sub open_table ($$$$$) {
    my($self, $data, $table, $createMode, $lockMode) = @_;
    my $dbh = $data->{Database};
    my $tables = $dbh->{csv_tables};
    if (!exists($tables->{$table})) {
	$tables->{$table} = {};
    }
    my $meta = $tables->{$table};
    my $csv = $meta->{csv_csv} || $dbh->{csv_csv};
    if (!$csv) {
	my $class = $meta->{csv_class}  ||  $dbh->{'csv_class'};
	if (!$class) {
	    $class = 'Text::CSV_XS';
	}
	$csv = $meta->{csv_csv} = $class->new({ binary => 1,
						eol => "\015\012" });
    }				     
    my $file = $meta->{file}  ||  $table;
    my $tbl = $self->SUPER::open_table($data, $file, $createMode, $lockMode);
    if ($tbl) {
	$tbl->{csv_csv} = $csv;
	my $types = $meta->{types};
	if ($types) {
	    # The 'types' array contains DBI types, but we need types
	    # suitable for Text::CSV_XS.
	    my $t = [];
	    foreach (@{$types}) {
		if ($_) {
		    $_ = $DBD::CSV::CSV_TYPES[$_+6]  ||  PV();
		} else {
		    $_ = PV();
		}
		push(@$t, $_);
	    }
	    $tbl->{types} = $t;
	}
	if (!$createMode) {
	    my($array, $skipRows);
	    if (exists($meta->{skip_rows})) {
		$skipRows = $meta->{skip_rows};
	    } else {
		$skipRows = exists($meta->{col_names}) ? 0 : 1;
	    }
	    if ($skipRows--) {
		if (!($array = $tbl->fetch_row($data))) {
		    die "Missing first row";
		}
		$tbl->{col_names} = $array;
		while ($skipRows--) {
		    $tbl->fetch_row($data);
		}
	    }
	    $tbl->{first_row_pos} = $tbl->{fh}->tell();
	    if (exists($meta->{col_names})) {
		$array = $tbl->{col_names} = $meta->{col_names};
	    } elsif (!$tbl->{col_names}  ||  !@{$tbl->{col_names}}) {
		# No column names given; fetch first row and create default
		# names.
		my $a = $tbl->{cached_row} = $tbl->fetch_row($data);
		$array = $tbl->{'col_names'};
		for (my $i = 0;  $i < @$a;  $i++) {
		    push(@$array, "col$i");
		}
	    }
	    my($col, $i);
	    my $columns = $tbl->{col_nums};
	    foreach $col (@$array) {
		$columns->{$col} = $i++;
	    }
	}
    }
    $tbl;
}


package DBD::CSV::Table;

@DBD::CSV::Table::ISA = qw(DBD::File::Table);

sub fetch_row ($$) {
    my($self, $data) = @_;
    my $fields;
    if (exists($self->{cached_row})) {
	$fields = delete($self->{cached_row});
    } else {
	my $csv = $self->{csv_csv};
	$fields = $csv->getline($self->{'fh'});
	if (!$fields) {
	    if ($!) {
		die "Error while reading file " . $self->{'file'} . ": $!";
	    }
	}
    }
    $self->{row} = (@$fields ? $fields : undef);
}

sub push_row ($$$) {
    my($self, $data, $fields) = @_;
    my($csv) = $self->{csv_csv};
    my($fh) = $self->{'fh'};
    #
    #  Remove undef from the right end of the fields, so that at least
    #  in these cases undef is returned from FetchRow
    #
    while (@$fields  &&  !defined($fields->[$#$fields])) {
	pop @$fields;
    }
    if (!$csv->print($fh, $fields)) {
	die "Error while writing file " . $self->{'file'} . ": $!";
    }
    1;
}
*push_names = \&push_row;


1;


__END__

=head1 NAME

DBD::CSV - DBI driver for CSV files

=head1 SYNOPSIS

    use DBI;
    $dbh = DBI->connect("DBI:CSV:f_dir=/home/joe/csvdb")
        or die "Cannot connect: " . $DBI::errstr;
    $sth = $dbh->prepare("CREATE TABLE a (id INTEGER, name CHAR(10))")
        or die "Cannot prepare: " . $dbh->errstr();
    $sth->execute() or die "Cannot execute: " . $sth->errstr();
    $sth->finish();
    $dbh->disconnect();


=head1 WARNING

THIS IS ALPHA SOFTWARE. It is *only* 'Alpha' because the interface (API)
is not finalised. The Alpha status does not reflect code quality or
stability.


=head1 DESCRIPTION

The DBD::CSV module is yet another driver for the DBI (Database independent
interface for Perl). This one is based on the SQL "engine" SQL::Statement
and the abstract DBI driver DBD::File and implements access to
so-called CSV files (Comma separated values). Such files are mostly used for
exporting MS Acess and MS Excel data.

See L<DBI(3)> for details on DBI, L<SQL::Statement(3)> for details on
SQL::Statement and L<DBD::File(3)> for details on the base class
DBD::File.


=head2 Prerequisites

The only system dependent feature that DBD::File uses, is the flock()
function. Thus the module should run (in theory) on any system with
a working flock(), in particular on all Unix machines, on Windows 95
and NT.

Unlike other DBI drivers, you don't need an external SQL engine
or a running server. All you need are the following Perl modules,
available from any CPAN mirror, for example

  ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module

=over 4

=item DBI

the DBI (Database independent interface for Perl), version 0.93 or
a later release

=item SQL::Statement

a simple SQL engine

=item Text::CSV_XS

this module is used for writing rows to or reading rows from CSV files.

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


=head2 Creating a database handle

Creating a database handle usually implies connecting to a database server.
Thus this command reads

    use DBI;
    my $dbh = DBI->connect("DBI:File:f_dir=$dir");

The directory tells the driver where it should create or open tables (aka
files). It defaults to the current directory, thus the following are
equivalent:

    $dbh = DBI->connect("DBI:File:");
    $dbh = DBI->connect("DBI:File:f_dir=.");

You may set other attributes in the DSN string, separated by semicolons.


=head2 Creating and dropping tables

You can create and drop tables with commands like the following:

    $dbh->do("CREATE TABLE $table (id INTEGER, name CHAR(64))");
    $dbh->do("DROP TABLE $table");

Note that currently only the column names will be stored and no other data.
Thus all other information including column type (INTEGER or CHAR(x), for
example), column attributes (NOT NULL, PRIMARY KEY, ...) will silently be
discarded. This may change in a later release.

A drop just removes the file without any warning.

See L<DBI(3)> for more details.

Table names cannot be arbitrary, due to restrictions of the SQL syntax.
I recommend table names to be valid SQL identifiers: The first
character is alphabetic, followed by an arbitrary number of alphanumeric
characters. If you want to use other files, the file names must start
with '/', './' or '../' and they must not contain white space.


=head2 Inserting, fetching and modifying data

The following examples insert some data in a table and fetch it back:
First all data in the string:

    $dbh->do("INSERT INTO $table VALUES (1, "
             . $dbh->quote("foobar") . ")");

Note the use of the quote method for escaping the word 'foobar'. Any
string must be escaped, even if it doesn't contain binary data.

Next an example using parameters:

    $dbh->do("INSERT INTO $table VALUES (?, ?)",
	     2, "It's a string!");

Note that you don't need to use the quote method here, this is done
automatically for you. This version is particularly well designed for
loops. Whenever performance is an issue, I recommend using this method.


To retrieve data, you can use the following:

    my($query) = "SELECT * FROM $table WHERE id > 1 ORDER BY id";
    my($sth) = $dbh->prepare($query);
    $sth->execute();
    while (my($row) = $sth->fetchrow_hashref) {
        print("Found result row: id = ", $row->{'id'},
              ", name = ", $row->{'name'});
    }
    $sth->finish();

Again, column binding works: The same example again.

    my($query) = "SELECT * FROM $table WHERE id > 1 ORDER BY id";
    my($sth) = $dbh->prepare($query);
    $sth->execute();
    my($id, $name);
    $sth->bind_columns(undef, \$id, \$name);
    while ($sth->fetch) {
        print("Found result row: id = $id, name = $name\n");
    }
    $sth->finish();

Of course you can even use input parameters. Here's the same example
for the third time:

    my($query) = "SELECT * FROM $table WHERE id = ?";
    my($sth) = $dbh->prepare($query);
    $sth->bind_columns(undef, \$id, \$name);
    for (my($i) = 1;  $i <= 2;   $i++) {
	$sth->execute($id);
	if ($sth->fetch) {
	    print("Found result row: id = $id, name = $name\n");
	}
        $sth->finish();
    }

See L<DBI(3)> for details on these methods. See L<SQL::Statement(3)> for
details on the WHERE clause.

Data rows are modified with the UPDATE statement:

    $dbh->do("UPDATE $table SET id = 3 WHERE id = 1");

Likewise you use the DELETE statement for removing rows:

    $dbh->do("DELETE FROM $table WHERE id > 1");


=head2 Error handling

In the above examples we have never cared for return codes. Of course
this cannot be recommended. Instead we should have written (for example)

    my($query) = "SELECT * FROM $table WHERE id = ?";
    my($sth) = $dbh->prepare($query)
        or die "prepare: " . $dbh->errstr();
    $sth->bind_columns(undef, \$id, \$name)
        or die "bind_columns: " . $dbh->errstr();
    for (my($i) = 1;  $i <= 2;   $i++) {
	$sth->execute($id)
	    or die "execute: " . $dbh->errstr();
	if ($sth->fetch) {
	    print("Found result row: id = $id, name = $name\n");
	}
    }
    $sth->finish($id)
        or die "finish: " . $dbh->errstr();

Obviously this is tedious. Fortunately we have DBI's I<RaiseError>
attribute:

    $dbh->{'RaiseError'} = 1;
    $@ = '';
    eval {
        my($query) = "SELECT * FROM $table WHERE id = ?";
        my($sth) = $dbh->prepare($query);
        $sth->bind_columns(undef, \$id, \$name);
        for (my($i) = 1;  $i <= 2;   $i++) {
	    $sth->execute($id);
	    if ($sth->fetch) {
	        print("Found result row: id = $id, name = $name\n");
	    }
        }
        $sth->finish($id);
    };
    if ($@) { die "SQL database error: $@"; }

This is not only shorter, it even works when using DBI methods within
subroutines.


=head2 Metadata

The following attributes are handled by DBI itself and not by DBD::File,
thus they all work like expected:

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

Valid after C<$sth->execute>

=item NUM_OF_PARAMS

Valid after C<$sth->prepare>

=item NAME

Valid after C<$sth->execute>; undef for Non-Select statements.

=item NULLABLE

Not really working, always returns an array ref of one's, as DBD::CSV
doesn't verify input data. Valid after C<$sth->execute>; undef for
Non-Select statements.

=back

These attributes and methods are not supported:

    bind_param_inout
    CursorName
    LongReadLen
    LongTruncOk

Additional to the DBI attributes, you can use the following dbh
attributes:

=over 8

=item f_dir

This attribute is used for setting the directory where CSV files are
opened. Usually you set it in the dbh, it defaults to the current
directory ("."). However, it is overwritable in the statement handles.

=item csv_class

=item csv_csv

Used as a default for the respective attributes of I<csv_tables>,
see below.

=item csv_tables

This hash ref is used for storing table dependent meta data. For any
table it contains an element with the table name as key and another
hash ref with the following attributes:

=over 12

=item file

The tables file name; defaults to

    $dbh->{f_dir} . "/$table

=item csv_class

The class to use for accessing the file, by default "Text::CSV_XS".
This attribute (like any other attribute of prefix I<csv_>, see
I<csv_csv> below) is inherited from the dbh, if not explicitly
specified.

=item csv_csv

The csv object, an instance of I<csv_class>. You need to supply such
an object for overwriting attributes like C<$csv->{eol}>,
C<$csv->{quote_char}> and the like. See L<Text::CSV_XS(3)> for
details. Note that by default binary mode is used for creating the
csv object. You must not change this!

=item col_names

=item skip_first_row

By default DBD::CSV assumes that column names are stored in the first
row of the CSV file. If this is not the case, you can supply an array
ref of table names with the I<col_names> attribute. In that case the
attribute I<skip_first_row> will be set to FALSE.

If you supply an empty array ref, the driver will read the first row
for you, count the number of columns and create column names like
C<col0>, C<col1>, ...

=back

Example: Suggest you want to use C</etc/passwd> as a CSV file. :-)
You can read it like this:

    require DBI;
    my $dbh = DBI->connect("DBI:CSV:f_dir=/etc");
    my $dbh->{csv_tables}->{passwd} = {
        csv_csv => Text::CSV_XS->new({ binary => 1,
                                       eol => "\012",
                                       quote_char => undef,
                                       escape_char => undef,
                                       sep_char => ':'}),
        file => '/etc/passwd',
        col_names => ["login", "password", "uid", "gid", "realname",
                      "directory", "shell"]
    };
    $dbh->do("UPDATE passwd SET login = 'joe' WHERE login = 'wiedmann'");


=head2 Driver private methods

These methods are inherited from DBD::File:

=over 4

=item data_sources

The C<data_sources> method returns a list of subdirectories of the current
directory in the form "DBI:CSV:directory=$dirname". Unfortunately the
current version of DBI doesn't accept attributes of the data_sources
method. Thus the method reads a global variable

    $DBD::CSV::dr::data_sources_attr

if you want to read the subdirectories of another directory. Example:

    my($drh) = DBI->install_driver("CSV");
    $DBD::CSV::dr::data_sources_attr = "/usr/local/csv_data";
    my(@list) = $drh->data_sources();

=item list_tables

This method returns a list of file names inside $dbh->{'directory'}.
Example:

    my($dbh) = DBI->connect("DBI:CSV:directory=/usr/local/csv_data");
    my(@list) = $dbh->func('list_tables');

Note that the list includes all files contained in the directory, even
those that have non-valid table names, from the view of SQL. See
L<Creating and dropping tables> above.

=back


=head2 Data restrictions

When inserting and fetching data, you will sometimes be surprised: DBD::CSV
doesn't correctly handle data types, in particular NULL's. If you insert
integers, it might happen, that fetch returns a string. Of course, a string
containing the integer, so that's perhaps not a real problem. But the
following will never work:

    $dbh->do("INSERT INTO $table (id, name) VALUES (?, ?)",
             undef, "foo bar");
    $sth = $dbh->prepare("SELECT * FROM $table WHERE id IS NULL");
    $sth->execute();
    my($id, $name);
    $sth->bind_columns(undef, \$id, \$name);
    while ($sth->fetch) {
        printf("Found result row: id = %s, name = %s\n",
              defined($id) ? $id : "NULL",
              defined($name) ? $name : "NULL");
    }
    $sth->finish();

The row we have just inserted, will never be returned! The reason is
obvious, if you examine the CSV file: The corresponding row looks
like

    "","foo bar"

In other words, not a NULL is stored, but an empty string. CSV files
don't have a concept of NULL values. Surprisingly the above example
works, if you insert a NULL value for the name! Again, you find
the explanation by examining the CSV file:

    ""

In other words, DBD::CSV has "emulated" a NULL value by writing a row
with less columns. Of course this works only if the rightmost column
is NULL, the two rightmost columns are NULL, ..., but the leftmost
column will never be NULL!

See L<Creating and dropping tables> above for table name restrictions.


=head1 TODO

These are merely restrictions of the DBD::File or SQL::Statement
modules:

=over 4

=item Joins

The current version of the module works with single table SELECT's
only, although the basic design of the SQL::Statement module allows
joins and the likes.

=item Table name mapping

Currently it is not possible to use files with names like C<names.csv>.
Instead you have to use soft links or rename files. As an alternative
one might use, for example a dbh attribute 'table_map'. It might be a
hash ref, the keys being the table names and the values being the file
names.

=item Column name mapping

Currently the module assumes that column names are stored in the first
row. While this is fine in most cases, there should be a possibility
of setting column names and column number from the programmer: For
example MS Access doesn't export column names by default.

=back


=head1 AUTHOR AND COPYRIGHT

This module is Copyright (C) 1998 by

    Jochen Wiedmann
    Am Eisteich 9
    72555 Metzingen
    Germany

    Email: joe@ispsoft.de
    Phone: +49 7123 14887

All rights reserved.

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file. 


=head1 SEE ALSO

L<DBI(3)>, L<Text::CSV_XS(3)>, L<SQL::Statement(3)>


=cut

# -*- perl -*-
#

require 5.004;

require DynaLoader;
require IO::File;
require DBI;
require SQL::Statement;
require SQL::Eval;
require Text::CSV_XS;


package DBD::CSV;

use vars qw(@ISA $VERSION $err $errstr $sqlstate);

@ISA = qw(DynaLoader);

$VERSION = '0.1002';

$err = 0;		# holds error code   for DBI::err
$errstr = "";		# holds error string for DBI::errstr
$sqlstate = "";         # holds error state  for DBI::state
$drh = undef;		# holds driver handle once initialised


sub driver{
    return $drh if $drh;
    my($class, $attr) = @_;

    $class .= "::dr";

    # not a 'my' since we use it above to prevent multiple drivers

    $drh = DBI::_new_drh($class, {
	'Name' => 'CSV',
	'Version' => $VERSION,
	'Err'    => \$DBD::CSV::err,
	'Errstr' => \$DBD::CSV::errstr,
	'State' => \$DBD::CSV::sqlstate,
	'Attribution' => 'DBD::CSV by Jochen Wiedmann',
    });

    $drh;
}

bootstrap DBD::CSV $VERSION;



package DBD::CSV::dr; # ====== DRIVER ======

$DBD::CSV::dr::imp_data_size = 0;
$DBD::CSV::dr::data_sources_attr = {};

sub connect {
    my $drh = shift;
    my($dbname, $user, $auth)= @_;

    # create a 'blank' dbh
    my $this = DBI::_new_dbh($drh, {
	'Name' => $dbname,
	'USER' => $user, 
	'CURRENT_USER' => $user,
    });

    if ($this) {
	$this->{'private_dbd_csv'} = {
	    'directory' => '.',
	    'eol' => "\015\012",
	    'quote_char' => '"',
	    'escape_char' => '"',
	    'sep_char' => ','
	};
	while (length($dbname)) {
	    my($var, $val);
	    if ($dbname =~ /^(.*?);(.*)/) {
		$var = $1;
		$dbname = $2;
	    } else {
		$var = $dbname;
		$dbname = '';
	    }
	    if ($var =~ /^(.+?)=(.*)/) {
		$var = $1;
		$val = $2;
		$this->{'private_dbd_csv'}->{$var} = $val;
	    }
	}
    }

    $this;
}

sub data_sources ($;$) {
    my($self, $attr) = @_;
    $attr ||= $DBD::CSV::dr::data_sources_attr;
    my($dir) = exists($attr->{'directory'}) ? $attr->{'directory'} : ".";
    my($dirh) = Symbol::gensym();
    if (!opendir($dirh, $dir)) {
	&DBD::CSV::SetError($drh, "Cannot open directory $dir", -1, "S1000");
	return undef;
    }
    my($file, @dsns, %names);
    while (defined($file = readdir($dirh))) {
	if ($file ne '.'  &&  $file ne '..'  &&  -d "$dir/$file") {
	    push(@dsns, "DBI:CSV:directory=$dir/$file");
	}
    }
    @dsns;
}

sub disconnect_all {
}

sub DESTROY {
    undef;
}


package DBD::CSV::db; # ====== DATABASE ======

$DBD::CSV::db::imp_data_size = 0;


sub prepare {
    my($dbh, $statement, @attribs)= @_;
    my($dbhattr) = $dbh->{'private_dbd_csv'};

    # create a 'blank' dbh
    my $sth = DBI::_new_sth($dbh, {
	'Statement' => $statement,
    });

    if ($sth) {
	$@ = '';
	my($stmt) = eval { DBD::CSV::Statement->new($statement) };
	if ($@) {
	    &DBD::CSV::SetError($self, $@, -1, 'S1000');
	    undef $sth;
	} else {
	    $sth->{'private_dbd_csv'} = {
		'stmt' => $stmt,
		'csv' => Text::CSV_XS->new({
		    'binary' => 1,
		    'eol' => $dbhattr->{'eol'},
		    'quote_char' => $dbhattr->{'quote_char'},
		    'escape_char' => $dbhattr->{'escape_char'},
		    'sep_char' => $dbhattr->{'sep_char'}
		}),
		'directory' => $dbhattr->{'directory'},
		'params' => []
	    };
	    $sth->{'NUM_OF_PARAMS'} = scalar($stmt->params());
	}
    }

    $sth;
}

sub disconnect {
    1;
}

sub FETCH {
    my ($dbh, $attrib) = @_;
    if ($attrib eq 'AutoCommit') {
	return 1;
    } elsif (exists($dbh->{'private_dbd_csv'}->{$attrib})) {
	return $dbh->{'private_dbd_csv'}->{$attrib};
    }
    # else pass up to DBI to handle
    return $dbh->DBD::_::db::FETCH($attrib);
}

sub STORE {
    my ($dbh, $attrib, $value) = @_;
    if ($attrib eq 'AutoCommit') {
	return 1 if $value; # is already set
	croak("Can't disable AutoCommit");
    } elsif (exists($dbh->{'private_dbd_csv'}->{$attrib})) {
	$dbh->{'private_dbd_csv'}->{$attrib} = $value;
	return 1;
    }
    return $dbh->DBD::_::db::STORE($attrib, $value);
}

sub DESTROY {
    undef;
}

sub list_tables ($) {
    my($dbh) = @_;
    my($dir) = $dbh->{'private_dbd_csv'}->{'directory'};
    my($dirh) = Symbol::gensym();
    if (!opendir($dirh, $dir)) {
	&DBD::CSV::SetError($dbh, "Cannot open directory $dir", -1, "S1000");
	return undef;
    }
    my($file, @tables, %names);
    while (defined($file = readdir($dirh))) {
	if ($file ne '.'  &&  $file ne '..'  &&  -f "$dir/$file") {
	    push(@tables, $file);
	}
    }
    @tables;
}

sub quote ($$) {
    my($self, $str) = @_;
    $str =~ s/\\/\\\\/sg;
    $str =~ s/\0/\\0/sg;
    $str =~ s/\'/\\\'/sg;
    $str =~ s/\n/\\n/sg;
    $str =~ s/\r/\\r/sg;
    "'$str'";
}

sub commit ($) {
    my($self) = shift;
    &DBD::CSV::SetWarning($self,
			  "Commit ineffective while AutoCommit is on", -1);
    1;
}

sub rollback ($) {
    my($self) = shift;
    &DBD::CSV::SetWarning($self,
			  "Rollback ineffective while AutoCommit is on",
			  -1);
    0;
}

package DBD::CSV::st; # ====== STATEMENT ======

$DBD::CSV::st::imp_data_size = 0;

sub bind_param ($$$;$) {
    my($sth, $pNum, $val, $attr) = @_;
    $sth->FETCH('params')->[$pNum-1] = $val;
    1;
}

sub execute {
    my($sth, @bind_values) = @_;
    my($params);
    if (@bind_values) {
	$sth->STORE('params', ($params = [@bind_values]));
    } else {
	$params = $sth->FETCH('params');
    }
    my($stmt) = $sth->FETCH('stmt');
    my($result) = $stmt->execute($sth, $params);
    if ($stmt->{'NUM_OF_FIELDS'}  &&  !$sth->FETCH('NUM_OF_FIELDS')) {
	$sth->STORE('NUM_OF_FIELDS', $stmt->{'NUM_OF_FIELDS'});
    }
    return $result;
}

sub fetch ($) {
    my($sth) = shift;
    my($data) = $sth->{'private_dbd_csv'}->{'stmt'}->{'data'};
    my($av) = $sth->func('get_fbav');
    if (!$data  ||  ref($data) ne 'ARRAY') {
	&DBD::CSV::SetError($sth,
			    "Attempt to fetch row from a Non-SELECT statement",
			     -1, "S1000");
	return undef;
    }
    my($dav) = shift(@$data);
    if (!$dav) {
	return undef;
    }
    my($val);
    my($chopBlanks) = $sth->FETCH('ChopBlanks');
    for ($i = 0;  $i < $sth->FETCH('NUM_OF_FIELDS');  $i++) {
	my($val) = $dav->[$i];
	if ($chopBlanks) {
	    $val =~ s/\s+$//s;
	}
	$av->[$i] = $val;
    }
    $av;
}
*fetchrow_arrayref = \&fetch;

sub FETCH ($$) {
    my ($sth, $attrib) = @_;
    if ($attrib eq 'NAME') {
	my($meta) = $sth->FETCH('stmt')->{'NAME'};
	if (!$meta) {
	    return undef;
	}
	my($names) = [];
	my($col);
	foreach $col (@$meta) {
	    push(@$names, $col->[0]->name());
	}
	return $names;
    } elsif ($attrib eq 'NULLABLE') {
	my($meta) = $sth->FETCH('stmt')->{'NAME'};
	if (!$meta) {
	    return undef;
	}
	my($names) = [];
	my($col);
	foreach $col (@$meta) {
	    push(@$names, 1);
	}
	return $names;
    }
    if (exists($sth->{'private_dbd_csv'}->{$attrib})) {
	return $sth->{'private_dbd_csv'}->{$attrib};
    }
    # else pass up to DBI to handle
    return $sth->DBD::_::st::FETCH($attrib);
}

sub STORE ($$$) {
    my ($sth, $attrib, $value) = @_;
    if (exists($sth->{'private_dbd_csv'}->{$attrib})) {
	$sth->{'private_dbd_csv'}->{$attrib} = $value;
	return 1;
    }
    return $sth->DBD::_::st::STORE($attrib, $value);
}

sub DESTROY ($) {
    undef;
}

sub rows ($) { shift->{'private_dbd_csv'}->{'stmt'}->{'NUM_OF_ROWS'} };

sub finish ($) { 1; }


package DBD::CSV::Statement;

@DBD::CSV::Statement::ISA = qw(SQL::Statement);

sub open_table ($$$$$) {
    my($self, $data, $table, $createMode, $lockMode) = @_;
    my($dir) = $data->FETCH('directory');
    my($file) =  $dir . "/" . $table;
    my($fh);
    if ($createMode) {
	if (-f $file) {
	    die "Cannot create table $table: Already exists";
	}
	if (!($fh = IO::File->new($file, "a+"))) {
	    die "Cannot open $file for writing: $!";
	}
	if (!$fh->seek(0, 0)) {
	    die " Error while seeking back: $!";
	}
    } else {
	if (!($fh = IO::File->new($file, ($lockMode ? "r+" : "r")))) {
	    die " Cannot open $file: $!";
	}
    }
    if ($lockMode) {
	if (!flock($fh, 2)) {
	    die " Cannot obtain exclusive lock on $file: $!";
	}
    } else {
	if (!flock($fh, 1)) {
	    die "Cannot obtain shared lock on $file: $!";
	}
    }
    my($columns) = {};
    my($array) = [];
    my($tbl) = {
	'file' => $file,
	'fh' => $fh,
	'col_nums' => $columns,
	'col_names' => $array,
	'csv' => $data->{'private_dbd_csv'}->{'csv'}
    };
    bless($tbl, "DBD::CSV::Table");
    if (!$createMode) {
	if (!($array = $tbl->fetch_row($data))) {
	    die "Missing column names";
	}
	$tbl->{'first_row_pos'} = $fh->tell();
	$tbl->{'col_names'} = $array;
	my($col, $i);
	foreach $col (@$array) {
	    $columns->{$col} = $i++;
	}
    }
    $tbl;
}


package DBD::CSV::Table;

@DBD::CSV::Table::ISA = qw(SQL::Eval::Table);

sub drop ($) {
    my($self) = @_;
    unlink($self->{'file'});
    return 1;
}

sub fetch_row ($$) {
    my($self, $data) = @_;
    my($csv) = $data->FETCH('csv');
    my($fields) = $csv->getline($self->{'fh'});
    if (!$fields) {
	if ($!) { die "Error while reading file " . $self->{'file'} . ": $!"; }
    }
    $self->{'row'} = (@$fields ? $fields : undef);
}

sub push_row ($$$) {
    my($self, $data, $fields) = @_;
    my($csv) = $data->FETCH('csv');
    my($fh) = $self->{'fh'};
    #
    #  Remove undef from the right end of the fields, so that at least
    #  in these cases undef is returned from FetchRow
    #
    while (@$fields  &&  !defined($fields->[$#fields])) {
	pop @$fields;
    }
    if (!$csv->print($fh, $fields)) {
	die "Error while writing file " . $self->{'file'} . ": $!";
    }
    1;
}
*push_names = \&push_row;

sub seek ($$$$) {
    my($self, $data, $pos, $whence) = @_;
    if ($whence == 0  &&  $pos == 0) {
	$pos = $self->{'first_row_pos'};
    } elsif ($whence != 2  ||  $pos != 0) {
	die "Illegal seek position: pos = $pos, whence = $whence";
    }
    if (!$self->{'fh'}->seek($pos, $whence)) {
	die "Error while seeking in " . $self->{'file'} . ": $!";
    }
}

sub truncate ($$) {
    my($self, $data) = @_;
    if (!$self->{'fh'}->truncate($self->{'fh'}->tell())) {
	die "Error while truncating " . $self->{'file'} . ": $!";
    }
    1;
}

1;


__END__

=head1 NAME

DBD::CSV - DBI driver for CSV files

=head1 SYNOPSIS

    use DBI;
    $dbh = DBI->connect("DBI:CSV:directory=/home/joe/csvdb")
        or die "Cannot connect: " . $DBI::errstr;
    $sth = DBI->prepare("CREATE TABLE a (id INTEGER, name CHAR(10))")
        or die "Cannot prepare: " . $dbh->errstr();
    $sth->execute() or die "Cannot execute: " . $sth->errstr();
    $sth->finish();
    $dbh->disconnect();

=head1 DESCRIPTION

The DBD::CSV module is yet another driver for the DBI (Database independent
interface for Perl). This one is based on the SQL "engine" SQL::Statement
and implements access to so-called CSV files (Comma separated values). Such
files are mostly used for exporting MS Acess and MS Excel data.

See L<DBI(3)> for details on DBI and L<SQL::Statement(3)> for details on
SQL::Statement.


=head2 Prerequisites

The only system dependent feature that DBD::CSV uses, is the flock()
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

=item Text::CSV_XS

this module is used for writing rows to or reading rows from CSV files.
Note that you need version 0.10, the C version and not the old Perl-
only version.

=back


=head2 Installation

Installing this module (and the prerequisites from above) is quite simple.
You just fetch the archive, extract it with

    gzip -cd DBD-CSV-0.1000.tar.gz | tar xf -

(this is for Unix users, Windows users would prefer WinZip or something
similar) and then enter the following:

    cd DBD-CSV-0.1000
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
    my($dbh) = DBI->connect("DBI:CSV:directory=$dir");

The directory tells the driver where it should create or open tables (aka
CSV files). It defaults to the current directory, thus the following are
equivalent:

    $dbh = DBI->connect("DBI:CSV:");
    $dbh = DBI->connect("DBI:CSV:directory=.");

You may set other attributes in the DSN string, separated by semicolons.


=head2 Creating and dropping tables

You can create and drop tables with commands like the following:

    $dbh->do("CREATE TABLE $table (id INTEGER, name CHAR(64))");
    $dbh->do("DROP TABLE $table");

The table is created as an empty file, then a first row with column
names will be written into the file. Note that currently only the
column names will be stored and no other data. Thus all other
information including column type (INTEGER or CHAR(x), for example),
column attributes (NOT NULL, PRIMARY KEY, ...) will silently be
discarded. This may change in a later release.

A drop just removes the file without any warning.

See L<DBI(3)> for more details.

Table names cannot be arbitrary, due to restrictions of the SQL syntax.
I recommend table names to be valid SQL identifiers: The first
character is alphabetic, followed by an arbitrary number of alphanumeric
characters. If you want to use other files, the file names must start
with '/', './' or '../' and they must not contain white space.


=head2 Inserting, fetching and modifying data

The following examples insert some data in in a table and fetch it back:
First all data in the string:

    $dbh->do("INSERT INTO $table VALUES (1, "
             . $dbh->quote("foobar") . ")");

Note the use of the quote method for escaping the word 'foobar'. Any
string must be escaped, even if they don't contain binary data.

Next an example using parameters:

    $dbh->do("INSERT INTO $table VALUES (?, ?)",
	     2, "It's a string!");

Note that you don't need to use the quote method here, this is done
automatically for you. This version is particularly well designed for
loops. Whenever performance is an issue, I recommend using this method.
See L<Data restrictions> below for possible problems.


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

See L<DBI(3)> for details on these methods. See L<Data restrictions> below
for possible problems. See L<SQL::Statement(3)> for details on the WHERE
clause.

Data rows are modified with the UPDATE statement:

    $dbh->do("UPDATE $table SET id = 3 WHERE id = 1");

Likewise you use the DELETE statement for removing rows:

    $dbh->do("DELETE FROM $table WHERE id > 1");


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

The following attributes are handled by DBI itself and not by DBD::CSV,
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

The following DBI attributes are handled by DBD::CSV:

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

See L<Data restrictions> above for details.

=back

These attributes and methods are not supported:

    bind_param_inout
    CursorName
    LongReadLen
    LongTruncOk

Additional to the DBI attributes, you can use the following:

=over 4

=item directory

This attribute is used for setting the directory where CSV files are
opened. Usually you set it in the dbh, it defaults to the current
directory ("."). However, it is overwritable in the statement handles.

=item eol

=item quote_char

=item escape_char

=item sep_char

These are corresponding to the same attributes of the Text::CSV_XS
object.

You need access to the DBD::CSV_XS object, if you want to work with
non-default CSV files. For example, the following will advice the
DBD::CSV_XS file to use semicolons as field separators:

    $dbh->{'sep_char'} = ';';

Note that DBD::CSV will put the Text::CSV_XS object into binary mode, so
that you can safely work with arbitrary data. You must not change this!

=back

=head2 Driver private methods

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


=head1 TODO

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

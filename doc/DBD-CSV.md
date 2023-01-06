# NAME

DBD::CSV - DBI driver for CSV files

# SYNOPSIS

    use DBI;
    # See "Creating database handle" below
    $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
        f_ext      => ".csv/r",
        RaiseError => 1,
        }) or die "Cannot connect: $DBI::errstr";

    # Simple statements
    $dbh->do ("CREATE TABLE foo (id INTEGER, name CHAR (10))");

    # Selecting
    my $sth = $dbh->prepare ("select * from foo");
    $sth->execute;
    $sth->bind_columns (\my ($id, $name));
    while ($sth->fetch) {
        print "id: $id, name: $name\n";
        }

    # Updates
    my $sth = $dbh->prepare ("UPDATE foo SET name = ? WHERE id = ?");
    $sth->execute ("DBI rocks!", 1);
    $sth->finish;

    $dbh->disconnect;

# DESCRIPTION

The DBD::CSV module is yet another driver for the DBI (Database independent
interface for Perl). This one is based on the SQL "engine" SQL::Statement
and the abstract DBI driver DBD::File and implements access to so-called
CSV files (Comma Separated Values). Such files are often used for exporting
MS Access and MS Excel data.

See [DBI](https://metacpan.org/pod/DBI) for details on DBI, [SQL::Statement](https://metacpan.org/pod/SQL%3A%3AStatement) for details on
SQL::Statement and [DBD::File](https://metacpan.org/pod/DBD%3A%3AFile) for details on the base class DBD::File.

## Prerequisites

The only system dependent feature that DBD::File uses, is the `flock ()`
function. Thus the module should run (in theory) on any system with
a working `flock ()`, in particular on all Unix machines and on Windows
NT. Under Windows 95 and MacOS the use of `flock ()` is disabled, thus
the module should still be usable.

Unlike other DBI drivers, you don't need an external SQL engine or a
running server. All you need are the following Perl modules, available
from any CPAN mirror, for example

    http://search.cpan.org/

- DBI


    A recent version of the [DBI](https://metacpan.org/pod/DBI) (Database independent interface for Perl).
    See below why.

- DBD::File


    This is the base class for DBD::CSV, and it is part of the DBI
    distribution. As DBD::CSV requires a matching version of [DBD::File](https://metacpan.org/pod/DBD%3A%3AFile)
    which is (partly) developed by the same team that maintains
    DBD::CSV. See META.json or Makefile.PL for the minimum versions.

- SQL::Statement


    A simple SQL engine. This module defines all of the SQL syntax for
    DBD::CSV, new SQL support is added with each release so you should
    look for updates to SQL::Statement regularly.

    It is possible to run `DBD::CSV` without this module if you define
    the environment variable `$DBI_SQL_NANO` to 1. This will reduce the
    SQL support a lot though. See [DBI::SQL::Nano](https://metacpan.org/pod/DBI%3A%3ASQL%3A%3ANano) for more details. Note
    that the test suite does only test in this mode in the development
    environment.

- Text::CSV\_XS


    This module is used to read and write rows in a CSV file.

## Installation

Installing this module (and the prerequisites from above) is quite simple.
The simplest way is to install the bundle:

    $ cpan Bundle::DBD::CSV

Alternatively, you can name them all

    $ cpan Text::CSV_XS DBI DBD::CSV

or even trust `cpan` to resolve all dependencies for you:

    $ cpan DBD::CSV

If you cannot, for whatever reason, use cpan, fetch all modules from
CPAN, and build with a sequence like:

    gzip -d < DBD-CSV-0.40.tgz | tar xf -

(this is for Unix users, Windows users would prefer WinZip or something
similar) and then enter the following:

    cd DBD-CSV-0.40
    perl Makefile.PL
    make test

If any tests fail, let us know. Otherwise go on with

    make install UNINST=1

Note that you almost definitely need root or administrator permissions.
If you don't have them, read the ExtUtils::MakeMaker man page for details
on installing in your own directories. [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils%3A%3AMakeMaker).

## Supported SQL Syntax

All SQL processing for DBD::CSV is done by SQL::Statement. See
[SQL::Statement](https://metacpan.org/pod/SQL%3A%3AStatement) for more specific information about its feature set.
Features include joins, aliases, built-in and user-defined functions,
and more.  See [SQL::Statement::Syntax](https://metacpan.org/pod/SQL%3A%3AStatement%3A%3ASyntax) for a description of the SQL
syntax supported in DBD::CSV.

Table- and column-names are case insensitive unless quoted. Column names
will be sanitized unless ["raw\_header"](#raw_header) is true.

# Using DBD::CSV with DBI

For most things, DBD-CSV operates the same as any DBI driver.
See [DBI](https://metacpan.org/pod/DBI) for detailed usage.

## Creating a database handle (connect)

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
        f_dir_search     => [],
        f_ext            => ".csv/r",
        f_lock           => 2,
        f_encoding       => "utf8",

        csv_eol          => "\r\n",
        csv_sep_char     => ",",
        csv_quote_char   => '"',
        csv_escape_char  => '"',
        csv_class        => "Text::CSV_XS",
        csv_null         => 1,
        csv_bom          => 0,
        csv_tables       => {
            syspwd => {
                sep_char    => ":",
                quote_char  => undef,
                escape_char => undef,
                file        => "/etc/passwd",
                col_names   => [qw( login password
                                    uid gid realname
                                    directory shell )],
                },
            },

        RaiseError       => 1,
        PrintError       => 1,
        FetchHashKeyName => "NAME_lc",
        }) or die $DBI::errstr;

but you may set these attributes in the DSN as well, separated by semicolons.
Pay attention to the semi-colon for `csv_sep_char` (as seen in many CSV
exports from MS Excel) is being escaped in below example, as is would
otherwise be seen as attribute separator:

    $dbh = DBI->connect (
        "dbi:CSV:f_dir=$ENV{HOME}/csvdb;f_ext=.csv;f_lock=2;" .
        "f_encoding=utf8;csv_eol=\n;csv_sep_char=\\;;" .
        "csv_quote_char=\";csv_escape_char=\\;csv_class=Text::CSV_XS;" .
        "csv_null=1") or die $DBI::errstr;

Using attributes in the DSN is easier to use when the DSN is derived from an
outside source (environment variable, database entry, or configure file),
whereas specifying entries in the attribute hash is easier to read and to
maintain.

The default value for `csv_binary` is `1` (True).

The default value for `csv_auto_diag` is <1>. Note that this might cause
trouble on perl versions older than 5.8.9, so up to and including perl
version 5.8.8 it might be required to use `;csv_auto_diag=0` inside the
`DSN` or `csv_auto_diag =` 0> inside the attributes.

## Creating and dropping tables

You can create and drop tables with commands like the following:

    $dbh->do ("CREATE TABLE $table (id INTEGER, name CHAR (64))");
    $dbh->do ("DROP TABLE $table");

Note that currently only the column names will be stored and no other data.
Thus all other information including column type (INTEGER or CHAR (x), for
example), column attributes (NOT NULL, PRIMARY KEY, ...) will silently be
discarded. This may change in a later release.

A drop just removes the file without any warning.

See [DBI](https://metacpan.org/pod/DBI) for more details.

Table names cannot be arbitrary, due to restrictions of the SQL syntax.
I recommend that table names are valid SQL identifiers: The first
character is alphabetic, followed by an arbitrary number of alphanumeric
characters. If you want to use other files, the file names must start
with "/", "./" or "../" and they must not contain white space.

## Inserting, fetching and modifying data

The following examples insert some data in a table and fetch it back:
First, an example where the column data is concatenated in the SQL string:

    $dbh->do ("INSERT INTO $table VALUES (1, ".
               $dbh->quote ("foobar") . ")");

Note the use of the quote method for escaping the word "foobar". Any
string must be escaped, even if it does not contain binary data.

Next, an example using parameters:

    $dbh->do ("INSERT INTO $table VALUES (?, ?)", undef, 2,
              "It's a string!");

Note that you don't need to quote column data passed as parameters.
This version is particularly well designed for
loops. Whenever performance is an issue, I recommend using this method.

You might wonder about the `undef`. Don't wonder, just take it as it
is. :-) It's an attribute argument that I have never used and will be
passed to the prepare method as the second argument.

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

See [DBI](https://metacpan.org/pod/DBI) for details on these methods. See [SQL::Statement](https://metacpan.org/pod/SQL%3A%3AStatement) for
details on the WHERE clause.

Data rows are modified with the UPDATE statement:

    $dbh->do ("UPDATE $table SET id = 3 WHERE id = 1");

Likewise you use the DELETE statement for removing rows:

    $dbh->do ("DELETE FROM $table WHERE id > 1");

## Error handling

In the above examples we have never cared about return codes. Of
course, this is not recommended. Instead we should have written (for
example):

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

Obviously this is tedious. Fortunately we have DBI's _RaiseError_
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

# DBI database handle attributes

## Metadata

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

- AutoCommit


    Always on

- ChopBlanks


    Works

- NUM\_OF\_FIELDS


    Valid after `$sth->execute`

- NUM\_OF\_PARAMS


    Valid after `$sth->prepare`

- NAME

- NAME\_lc

- NAME\_uc


    Valid after `$sth->execute`; undef for Non-Select statements.

- NULLABLE


    Not really working. Always returns an array ref of one's, as DBD::CSV
    does not verify input data. Valid after `$sth->execute`; undef for
    non-Select statements.

These attributes and methods are not supported:

    bind_param_inout
    CursorName
    LongReadLen
    LongTruncOk

# DBD-CSV specific database handle attributes

In addition to the DBI attributes, you can use the following dbh
attributes:

## DBD::File attributes

- f\_dir


    This attribute is used for setting the directory where CSV files are
    opened. Usually you set it in the dbh and it defaults to the current
    directory ("."). However, it may be overridden in statement handles.

- f\_dir\_search


    This attribute optionally defines a list of extra directories to search
    when opening existing tables. It should be an anonymous list or an array
    reference listing all folders where tables could be found.

        my $dbh = DBI->connect ("dbi:CSV:", "", "", {
            f_dir        => "data",
            f_dir_search => [ "ref/data", "ref/old" ],
            f_ext        => ".csv/r",
            }) or die $DBI::errstr;

- f\_ext


    This attribute is used for setting the file extension.

- f\_schema


    This attribute allows you to set the database schema name. The default is
    to use the owner of `f_dir`. `undef` is allowed, but not in the DSN part.

        my $dbh = DBI->connect ("dbi:CSV:", "", "", {
            f_schema => undef,
            f_dir    => "data",
            f_ext    => ".csv/r",
            }) or die $DBI::errstr;

- f\_encoding


    This attribute allows you to set the encoding of the data. With CSV, it is not
    possible to set (and remember) the encoding on a column basis, but DBD::File
    now allows the encoding to be set on the underlying file. If this attribute is
    not set, or undef is passed, the file will be seen as binary.

- f\_lock


    With this attribute you can specify a locking mode to be used (if locking is
    supported at all) for opening tables. By default, tables are opened with a
    shared lock for reading, and with an exclusive lock for writing. The
    supported modes are:

    - 0


        Force no locking at all.

    - 1


        Only shared locks will be used.

    - 2


        Only exclusive locks will be used.

But see ["KNOWN BUGS" in DBD::File](https://metacpan.org/pod/DBD%3A%3AFile#KNOWN-BUGS).

## DBD::CSV specific attributes

- csv\_class

    The attribute _csv\_class_ controls the CSV parsing engine. This defaults
    to `Text::CSV_XS`, but `Text::CSV` can be used in some cases, too.
    Please be aware that `Text::CSV` does not care about any edge case as
    `Text::CSV_XS` does and that `Text::CSV` is probably about 100 times
    slower than `Text::CSV_XS`.

    In order to use the specified class other than `Text::CSV_XS`, it needs
    to be loaded before use.  `DBD::CSV` does not `require`/`use` the
    specified class itself.

## Text::CSV\_XS specific attributes

- csv\_eol

- csv\_sep\_char

- csv\_quote\_char

- csv\_escape\_char

- csv\_csv


    The attributes _csv\_eol_, _csv\_sep\_char_, _csv\_quote\_char_ and
    _csv\_escape\_char_ are corresponding to the respective attributes of the
    _csv\_class_ (usually Text::CSV\_CS) object. You may want to set these
    attributes if you have unusual CSV files like `/etc/passwd` or MS Excel
    generated CSV files with a semicolon as separator. Defaults are
    `\015\012`", `,`, `"` and `"`, respectively.

    The _csv\_eol_ attribute defines the end-of-line pattern, which is better
    known as a record separator pattern since it separates records.  The default
    is windows-style end-of-lines `\015\012` for output (writing) and unset for
    input (reading), so if on unix you may want to set this to newline (`\n`)
    like this:

        $dbh->{csv_eol} = "\n";

    It is also possible to use multi-character patterns as record separators.
    For example this file uses newlines as field separators (sep\_char) and
    the pattern "\\n\_\_ENDREC\_\_\\n" as the record separators (eol):

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

    The attributes are used to create an instance of the class _csv\_class_,
    by default Text::CSV\_XS. Alternatively you may pass an instance as
    _csv\_csv_, the latter takes precedence. Note that the _binary_
    attribute _must_ be set to a true value in that case.

    Additionally you may overwrite these attributes on a per-table base in
    the _csv\_tables_ attribute.

- csv\_null


    With this option set, all new statement handles will set `always_quote`
    and `blank_is_undef` in the CSV parser and writer, so it knows how to
    distinguish between the empty string and `undef` or `NULL`. You cannot
    reset it with a false value. You can pass it to connect, or set it later:

        $dbh = DBI->connect ("dbi:CSV:", "", "", { csv_null => 1 });

        $dbh->{csv_null} = 1;

- csv\_bom


    With this option set, the CSV parser will try to detect BOM (Byte Order Mark)
    in the header line. This requires [Text::CSV\_XS](https://metacpan.org/pod/Text%3A%3ACSV_XS) version 1.22 or higher.

        $dbh = DBI->connect ("dbi:CSV:", "", "", { csv_bom => 1 });

        $dbh->{csv_bom} = 1;

- csv\_tables


    This hash ref is used for storing table dependent metadata. For any
    table it contains an element with the table name as key and another
    hash ref with the following attributes:

    - o

        All valid attributes to the CSV parsing module. Any of them can optionally
        be prefixed with `csv_`.

    - o

        All attributes valid to DBD::File

    If you pass it `f_file` or its alias `file`, `f_ext` has no effect, but
    `f_dir` and `f_encoding` still have.

        csv_tables => {
            syspwd => {                   # Table name
                csv_sep_char => ":",      # Text::CSV_XS
                quote_char   => undef,    # Text::CSV_XS
                escape_char  => undef,    # Text::CSV_XS
                f_dir        => "/etc",   # DBD::File
                f_file       => "passwd", # DBD::File
                col_names    =>           # DBD::File
                  [qw( login password uid gid realname directory shell )],
                },
            },

- csv\_\*


    All other attributes that start with `csv_` and are not described above
    will be passed to `Text::CSV_XS` (without the `csv_` prefix). These
    extra options are only likely to be useful for reading (select)
    handles. Examples:

        $dbh->{csv_allow_whitespace}    = 1;
        $dbh->{csv_allow_loose_quotes}  = 1;
        $dbh->{csv_allow_loose_escapes} = 1;

    See the `Text::CSV_XS` documentation for the full list and the documentation.

## Driver specific attributes

- f\_file


    The name of the file used for the table; defaults to

        "$dbh->{f_dir}/$table"

- eol

- sep\_char

- quote\_char

- escape\_char

- class

- csv


    These correspond to the attributes _csv\_eol_, _csv\_sep\_char_,
    _csv\_quote\_char_, _csv\_escape\_char_, _csv\_class_ and _csv\_csv_.
    The difference is that they work on a per-table basis.

- col\_names

- skip\_first\_row


    By default DBD::CSV assumes that column names are stored in the first row
    of the CSV file and sanitizes them (see `raw_header` below). If this is
    not the case, you can supply an array ref of table names with the
    _col\_names_ attribute. In that case the attribute _skip\_first\_row_ will
    be set to FALSE.

    If you supply an empty array ref, the driver will read the first row
    for you, count the number of columns and create column names like
    `col0`, `col1`, ...

    Note that column names that match reserved SQL words will cause unwanted
    and sometimes confusing errors. If your CSV has headers that match reserved
    words, you will require these two attributes.

    If `test.csv` looks like

        select,from
        1,2

    the select query would result in `select select, from from test;`, which
    obviously is illegal SQL.

- raw\_header


    Due to the SQL standard, field names cannot contain special characters
    like a dot (`.`) or a space (` `) unless the column names are quoted.
    Following the approach of mdb\_tools, all these tokens are translated to an
    underscore (`_`) when reading the first line of the CSV file, so all field
    names are 'sanitized'. If you do not want this to happen, set `raw_header`
    to a true value and the entries in the first line of the CSV data will be
    used verbatim for column headers and field names.  DBD::CSV cannot guarantee
    that any part in the toolchain will work if field names have those characters,
    and the chances are high that the SQL statements will fail.

    Currently, the sanitizing of headers is as simple as

        s/\W/_/g;

    Note that headers (column names) might be folded in other parts of the code
    stack, specifically SQL::Statement, whose docs mention:

        Wildcards are expanded to lower cased identifiers. This might
        confuse some people, but it was easier to implement.

    That means that in

        my $sth = $dbh->prepare ("select * from foo");
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            say for keys %$row;
            }

    all keys will show as all lower case, regardless of the original header.

It's strongly recommended to check the attributes supported by
["Metadata" in DBD::File](https://metacpan.org/pod/DBD%3A%3AFile#Metadata).

Example: Suppose you want to use `/etc/passwd` as a CSV file. :-)
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
override them on a per table basis:

    require DBI;
    my $dbh = DBI->connect ("dbi:CSV:");
    $dbh->{csv_tables}{passwd} = {
        eol         => "\n",
        sep_char    => ":",
        quote_char  => undef,
        escape_char => undef,
        f_file      => "/etc/passwd",
        col_names   => [qw( login password uid gid
                            realname directory shell )],
        };
    $sth = $dbh->prepare ("SELECT * FROM passwd");

## Driver private methods

These methods are inherited from DBD::File:

- data\_sources


    The `data_sources` method returns a list of sub-directories of the current
    directory in the form "dbi:CSV:directory=$dirname".

    If you want to read the sub-directories of another directory, use

        my $drh  = DBI->install_driver ("CSV");
        my @list = $drh->data_sources (f_dir => "/usr/local/csv_data");

- list\_tables


    This method returns a list of file-names inside $dbh->{directory}.
    Example:

        my $dbh  = DBI->connect ("dbi:CSV:directory=/usr/local/csv_data");
        my @list = $dbh->func ("list_tables");

    Note that the list includes all files contained in the directory, even
    those that have non-valid table names, from the view of SQL. See
    ["Creating and dropping tables"](#creating-and-dropping-tables) above.

# KNOWN ISSUES

- The module is using flock () internally. However, this function is not
available on some platforms. Use of flock () is disabled on MacOS and
Windows 95: There's no locking at all (perhaps not so important on
these operating systems, as they are for single users anyways).

# TODO

- Tests


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

- RT


    Attack all open DBD::CSV bugs in RT

- CPAN::Forum


    Attack all items in http://www.cpanforum.com/dist/DBD-CSV

- Documentation


    Expand on error-handling, and document all possible errors.
    Use Text::CSV\_XS::error\_diag () wherever possible.

- Debugging


    Implement and document dbd\_verbose.

- Data dictionary


    Investigate the possibility to store the data dictionary in a file like
    .sys$columns that can store the field attributes (type, key, nullable).

- Examples


    Make more real-life examples from the docs in examples/

# SEE ALSO

[DBI](https://metacpan.org/pod/DBI), [Text::CSV\_XS](https://metacpan.org/pod/Text%3A%3ACSV_XS), [SQL::Statement](https://metacpan.org/pod/SQL%3A%3AStatement), [DBI::SQL::Nano](https://metacpan.org/pod/DBI%3A%3ASQL%3A%3ANano)

For help on the use of DBD::CSV, see the DBI users mailing list:

    http://lists.cpan.org/showlist.cgi?name=dbi-users

For general information on DBI see

    http://dbi.perl.org/ and http://faq.dbi-support.com/

# AUTHORS and MAINTAINERS

This module is currently maintained by

    H.Merijn Brand <h.m.brand@xs4all.nl>

in close cooperation with and help from

    Jens Rehsack <sno@NetBSD.org>

The original author is Jochen Wiedmann.
Previous maintainer was Jeff Zucker

# COPYRIGHT AND LICENSE

Copyright (C) 2009-2023 by H.Merijn Brand
Copyright (C) 2004-2009 by Jeff Zucker
Copyright (C) 1998-2004 by Jochen Wiedmann

All rights reserved.

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

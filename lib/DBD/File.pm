# -*- perl -*-
#
#   DBD::File - A base class for implementing DBI drivers that
#               act on plain files
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
require DBI;
require SQL::Statement;
require SQL::Eval;


package DBD::File;

use vars qw(@ISA $VERSION $drh $err $errstr $sqlstate);

@ISA = qw(DynaLoader);

$VERSION = '0.1002';

$err = 0;		# holds error code   for DBI::err
$errstr = "";		# holds error string for DBI::errstr
$sqlstate = "";         # holds error state  for DBI::state
$drh = undef;		# holds driver handle once initialised


sub driver ($;$) {
    my($class, $attr) = @_;
    my $drh = eval '$' . $class . "::drh";
    if (!$drh) {
	if (!$attr) { $attr = {} };
	if (!exists($attr->{Attribution})) {
	    $attr->{Attribution} = "$class by Jochen Wiedmann";
	}
	if (!exists($attr->{Version})) {
	    $attr->{Version} = eval '$' . $class . '::VERSION';
        }
        if (!exists($attr->{Err})) {
	    $attr->{Err} = eval '\$' . $class . '::err';
        }
        if (!exists($attr->{Errstr})) {
	    $attr->{Errstr} = eval '\$' . $class . '::errstr';
        }
        if (!exists($attr->{State})) {
	    $attr->{State} = eval '\$' . $class . '::state';
        }
        if (!exists($attr->{Name})) {
	    my $c = $class;
	    $c =~ s/^DBD\:\://;
	    $attr->{Name} = $c;
        }

        $drh = DBI::_new_drh($class . "::dr", $attr);
    }
    $drh;
}


package DBD::File::dr; # ====== DRIVER ======

$DBD::File::dr::imp_data_size = 0;
$DBD::File::dr::data_sources_attr = undef;

sub connect ($$;$$$) {
    my($drh, $dbname, $user, $auth, $attr)= @_;

    # create a 'blank' dbh
    my $this = DBI::_new_dbh($drh, {
	'Name' => $dbname,
	'USER' => $user, 
	'CURRENT_USER' => $user,
    });

    if ($this) {
	my($var, $val);
	$this->{f_dir} = '.';
	while (length($dbname)) {
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
		$this->{$var} = $val;
	    }
	}
    }

    $this;
}

sub data_sources ($;$) {
    my($drh, $attr) = @_;
    $attr ||= $DBD::File::dr::data_sources_attr;
    my($dir) = exists($attr->{'f_dir'}) ?
	$attr->{'f_dir'} : '.';
    my($dirh) = Symbol::gensym();
    if (!opendir($dirh, $dir)) {
	$drh->STORE('errstr', "Cannot open directory $dir");
	return undef;
    }
    my($file, @dsns, %names, $driver);
    if ($drh->{'ImplementorClass'} =~ /^dbd\:\:([^\:]+)\:\:/i) {
	$driver = $1;
    } else {
	$driver = 'File';
    }
    while (defined($file = readdir($dirh))) {
	if ($file ne '.'  &&  $file ne '..'  &&  -d "$dir/$file") {
	    push(@dsns, "DBI:$driver:f_dir=$dir/$file");
	}
    }
    @dsns;
}

sub disconnect_all {
}

sub DESTROY {
    undef;
}


package DBD::File::db; # ====== DATABASE ======

$DBD::File::db::imp_data_size = 0;


sub prepare ($$;@) {
    my($dbh, $statement, @attribs)= @_;

    # create a 'blank' dbh
    my $sth = DBI::_new_sth($dbh, {'Statement' => $statement});

    if ($sth) {
	$@ = '';
	my $class = $sth->FETCH('ImplementorClass');
	$class =~ s/::st$/::Statement/;
	my($stmt) = eval { $class->new($statement) };
	if ($@) {
	    $dbh->STORE('errstr', $@);
	    undef $sth;
	} else {
	    $sth->STORE('f_stmt', $stmt);
	    $sth->STORE('f_params', []);
	    $sth->STORE('NUM_OF_PARAMS', scalar($stmt->params()));
	}
    }

    $sth;
}

sub disconnect ($) {
    1;
}

sub FETCH ($$) {
    my ($dbh, $attrib) = @_;
    if ($attrib eq 'AutoCommit') {
	return 1;
    } elsif ($attrib eq (lc $attrib)) {
	# Driver private attributes are lower cased
	return $dbh->{$attrib};
    }
    # else pass up to DBI to handle
    return $dbh->DBD::_::db::FETCH($attrib);
}

sub STORE ($$$) {
    my ($dbh, $attrib, $value) = @_;
    if ($attrib eq 'AutoCommit') {
	return 1 if $value; # is already set
	croak("Can't disable AutoCommit");
    } elsif ($attrib eq (lc $attrib)) {
	# Driver private attributes are lower cased
	$dbh->{$attrib} = $value;
	return 1;
    }
    return $dbh->DBD::_::db::STORE($attrib, $value);
}

sub DESTROY ($) {
    undef;
}

sub list_tables ($) {
    my($dbh) = @_;
    my($dir) = $dbh->{f_dir};
    my($dirh) = Symbol::gensym();
    if (!opendir($dirh, $dir)) {
	$dbh->STORE('errstr', "Cannot open directory $dir");
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
    if (!defined($str)) { return "NULL" }
    $str =~ s/\\/\\\\/sg;
    $str =~ s/\0/\\0/sg;
    $str =~ s/\'/\\\'/sg;
    $str =~ s/\n/\\n/sg;
    $str =~ s/\r/\\r/sg;
    "'$str'";
}

sub commit ($) {
    my($dbh) = shift;
    if ($dbh->FETCH('Warn')) {
	warn("Commit ineffective while AutoCommit is on", -1);
    }
    1;
}

sub rollback ($) {
    my($dbh) = shift;
    if ($dbh->FETCH('Warn')) {
	warn("Rollback ineffective while AutoCommit is on", -1);
    }
    0;
}


package DBD::File::st; # ====== STATEMENT ======

$DBD::File::st::imp_data_size = 0;

sub bind_param ($$$;$) {
    my($sth, $pNum, $val, $attr) = @_;
    $sth->{f_params}->[$pNum-1] = $val;
    1;
}

sub execute {
    my $sth = shift;
    my $params;
    if (@_) {
	$sth->{'f_params'} = ($params = [@_]);
    } else {
	$params = $sth->{'f_params'};
    }
    my $stmt = $sth->{'f_stmt'};
    my $result = eval { $stmt->execute($sth, $params); };
    if ($@) {
	$sth->STORE('errstr', $@);
    }
    if ($stmt->{'NUM_OF_FIELDS'}  &&  !$sth->FETCH('NUM_OF_FIELDS')) {
	$sth->STORE('NUM_OF_FIELDS', $stmt->{'NUM_OF_FIELDS'});
    }
    return $result;
}

sub fetch ($) {
    my $sth = shift;
    my $data = $sth->{f_stmt}->{data};
    if (!$data  ||  ref($data) ne 'ARRAY') {
	$sth->STORE('errstr', "Attempt to fetch row from a Non-SELECT"
		    . " statement");
	return undef;
    }
    my $dav = shift @$data;
    if (!$dav) {
	return undef;
    }
    if ($sth->FETCH('ChopBlanks')) {
	map { $_ =~ s/\s+$//; } @$dav;
    }
    $sth->_set_fbav($dav);
}
*fetchrow_arrayref = \&fetch;

sub FETCH ($$) {
    my ($sth, $attrib) = @_;
    if ($attrib eq 'TYPE') {
	# Workaround for a bug in DBI 0.93
	return undef;
    }
    if ($attrib eq 'NAME') {
	my($meta) = $sth->FETCH('f_stmt')->{'NAME'};
	if (!$meta) {
	    return undef;
	}
	my($names) = [];
	my($col);
	foreach $col (@$meta) {
	    push(@$names, $col->[0]->name());
	}
	return $names;
    }
    if ($attrib eq 'NULLABLE') {
	my($meta) = $sth->FETCH('f_stmt')->{'NAME'}; # Intentional !
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
    if ($attrib eq (lc $attrib)) {
	# Private driver attributes are lower cased
	return $sth->{$attrib};
    }
    # else pass up to DBI to handle
    return $sth->DBD::_::st::FETCH($attrib);
}

sub STORE ($$$) {
    my ($sth, $attrib, $value) = @_;
    if ($attrib eq (lc $attrib)) {
	# Private driver attributes are lower cased
	$sth->{$attrib} = $value;
	return 1;
    }
    return $sth->DBD::_::st::STORE($attrib, $value);
}

sub DESTROY ($) {
    undef;
}

sub rows ($) { shift->{'f_stmt'}->{'NUM_OF_ROWS'} };

sub finish ($) { 1; }


package DBD::File::Statement;

@DBD::File::Statement::ISA = qw(SQL::Statement);

sub open_table ($$$$$) {
    my($self, $data, $table, $createMode, $lockMode) = @_;
    my $file = $table;
    if ($file !~ /^(\.?\.)?\//) {
	$file = $data->{Database}->{'f_dir'} . "/$table";
    }
    my $fh;
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
    binmode($fh);
    if ($lockMode) {
	if (!flock($fh, 2)) {
	    die " Cannot obtain exclusive lock on $file: $!";
	}
    } else {
	if (!flock($fh, 1)) {
	    die "Cannot obtain shared lock on $file: $!";
	}
    }
    my $columns = {};
    my $array = [];
    my $tbl = {
	file => $file,
	fh => $fh,
	col_nums => $columns,
	col_names => $array,
	first_row_pos => $fh->tell()
    };
    my $class = ref($self);
    $class =~ s/::Statement/::Table/;
    bless($tbl, $class);
    $tbl;
}


package DBD::File::Table;

@DBD::File::Table::ISA = qw(SQL::Eval::Table);

sub drop ($) {
    my($self) = @_;
    # We have to close the file before unlinking it: Some OS'es will
    # refuse the unlink otherwise.
    $self->{'fh'}->close();
    unlink($self->{'file'});
    return 1;
}

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

DBD::File - Base class for writing DBI drivers for plain files

=head1 SYNOPSIS

    use DBI;
    $dbh = DBI->connect("DBI:File:f_dir=/home/joe/csvdb")
        or die "Cannot connect: " . $DBI::errstr;
    $sth = $dbh->prepare("CREATE TABLE a (id INTEGER, name CHAR(10))")
        or die "Cannot prepare: " . $dbh->errstr();
    $sth->execute() or die "Cannot execute: " . $sth->errstr();
    $sth->finish();
    $dbh->disconnect();

=head1 DESCRIPTION

The DBD::File module is not a true DBI driver, but an abstract
base class for deriving concrete DBI drivers from it. The implication is,
that these drivers work with plain files, for example CSV files or
INI files. The module is based on the SQL::Statement module, a simple
SQL engine.

See L<DBI(3)> for details on DBI, L<SQL::Statement(3)> for details on
SQL::Statement and L<DBD::CSV(3)> or L<DBD::IniFile(3)> for example
drivers.


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
attribute:

=over 4

=item f_dir

This attribute is used for setting the directory where CSV files are
opened. Usually you set it in the dbh, it defaults to the current
directory ("."). However, it is overwritable in the statement handles.

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

This method returns a list of file names inside $dbh->{'f_dir'}.
Example:

    my($dbh) = DBI->connect("DBI:CSV:f_dir=/usr/local/csv_data");
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

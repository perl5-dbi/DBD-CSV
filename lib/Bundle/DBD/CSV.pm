# -*- perl -*-

package Bundle::DBD::CSV;

$VERSION = '0.1016';

1;

__END__

=head1 NAME

Bundle::DBD::CSV - A bundle to install the DBD::CSV driver

=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::DBD::CSV'>

=head1 CONTENTS

DBI 1.02

Text::CSV_XS 0.14

SQL::Statement 0.1006

DBD::File

DBD::CSV

=head1 DESCRIPTION

This bundle includes all that's needed to access so-called CSV (Comma
Separated Values) files via a pseudo SQL engine (SQL::Statement) and DBI.

=cut

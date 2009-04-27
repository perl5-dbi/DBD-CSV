# -*- perl -*-

package Bundle::DBD::CSV;

$VERSION = "1.02";

1;

__END__

=head1 NAME

Bundle::DBD::CSV - A bundle to install the DBD::CSV driver

=head1 SYNOPSIS

C<perl -MCPAN -e 'install Bundle::DBD::CSV'>

=head1 CONTENTS

DBI 1.607

Text::CSV_XS 0.64

SQL::Statement 1.20

DBD::File 0.36

DBD::CSV 0.30

=head1 DESCRIPTION

This bundle includes all that's needed to access so-called CSV (Comma
Separated Values) files via a pseudo SQL engine (SQL::Statement) and DBI.

=cut

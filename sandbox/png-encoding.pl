#!/pro/bin/perl

use v5.12;
use warnings;

use DBI qw(:sql_types);
use Encode;
use Data::Peek;

my $euro = "\x{20ac}";
# NOTE: you don't seem to be able to have Unicode column names
#my $column = "fred\x{20ac}";
my $column = "fred";
# NOTE: you don't seem to be able to have Unicode table names
#my $table = "test1\x{20ac}";
my $table = "test1";
my $h     = DBI->connect (
    "dbi:CSV:",
    undef, undef, {
	f_encoding => "UTF8",
	#f_encoding => "UCS2",
	f_ext      => ".csv",
	RaiseError => 1
	});
eval {
    local $h->{PrintError} = 0;
    $h->do (qq/drop table $table/);
    };
$h->do (qq/create table $table ($column varchar(50), b blob)/);

my $png = join "" =>
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00",
    "\x00\x01\x00\x00\x00\x64\x08\x02\x00\x00\x00\xC8\x4E\xCD\x37\x00\x00\x00",
    "\x01\x73\x52\x47\x42\x00\xAE\xCE\x1C\xE9\x00\x00\x00\x09\x70\x48\x59\x73",
    "\x00\x00\x0D\xD7\x00\x00\x0D\xD7\x01\x42\x28\x9B\x78\x00\x00\x00\x07\x74",
    "\x49\x4D\x45\x07\xD7\x0B\x09\x13\x28\x35\xDC\xB9\x8F\x0C\x00\x00\x00\x14",
    "\x49\x44\x41\x54\x18\xD3\x63\x78\xFE\xE2\x29\x13\x03\x03\xC3\x28\x1E\x1C",
    "\x18\x00\xD0\x56\x03\x7B\x9B\x91\x28\xCF\x00\x00\x00\x00\x49\x45\x4E\x44",
    "\xAE\x42\x60\x82";

my $s = $h->prepare (qq/insert into $table values(?,?)/);
$s->bind_param (1, $euro);
$s->bind_param (2, $png, {TYPE => SQL_BLOB});
$s->execute;

$s = $h->prepare (qq/select $column,b from $table/);
my ($col1, $col2);
$s->bind_col (1, \$col1);
$s->bind_col (2, \$col2, { TYPE => SQL_BLOB });
$s->execute;
$s->fetch;

if ($col1 eq $euro) {
    say "Euro in/out successfully";
    }
else {
    say "Data selected does not match data inserted";
    DDump ($col1);
    }

say "UTF8 flag on char   data is ", (Encode::is_utf8 ($col1) ? "On" : "Off");
say "UTF8 flag on binary data is ", (Encode::is_utf8 ($col2) ? "On" : "Off");

say "The BLOB/PNG is recovered ", $col2 eq $png ? "OK" : "Damaged";
Encode::_utf8_off ($col2);
$col2 = eval qq{ "$col2" };
say "The BLOB/PNG is recovered ", $col2 eq $png ? "OK" : "Damaged";

# you can happily use Unicode in SQL:
$s = $h->prepare ("select $column from $table where $column = " .
	    $h->quote ($euro));
$s->execute;
my $r = $s->fetchrow_arrayref;
DDumper ($r);

unlink "test1.csv";

__END__

outputs:

Euro in /
    out successfully UTF8 flag on char data is On UTF8 flag on binary data is On
    Wide character in print at csv2 . pl line 55. $VAR1 = ["\x{20ac}"];

    and out
    . png file is corrupt
    . If you remove f_encoding the blob works but the unicode / utf8 does not

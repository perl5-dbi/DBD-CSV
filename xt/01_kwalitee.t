#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN { $ENV{AUTHOR_TESTING} = 1; }
use Test::Kwalitee qw( kwalitee_ok );;

kwalitee_ok (qw(
    -has_meta_yml
    -metayml_conforms_spec_current
    -metayml_conforms_to_known_spec
    -metayml_declares_perl_version
    -metayml_has_license
    -metayml_has_provides
    -metayml_is_parsable

    -use_strict
    ));
# use_strict is still broken, as it does not include "use 5.16.2;" as
# equivalent to use strict

my @experimental = qw(
     no_stdin_for_prompting
     prereq_matches_use
     has_test_pod
     has_test_pod_coverage
     use_warnings

     build_prereq_matches_use
     easily_repackageable
     easily_repackageable_by_debian
     easily_repackageable_by_fedora
     fits_fedora_license
     has_license_in_source_file
     has_version_in_each_file
     has_version_in_each_file
     uses_test_nowarnings
     );

done_testing ();

#!perl -T

use strict;
use warnings;

use Test::More tests => 4;

require Scope::Upper;

for (qw/reap localize localize_elem TOPLEVEL/) {
 eval { Scope::Upper->import($_) };
 is($@, '', 'import ' . $_);
}

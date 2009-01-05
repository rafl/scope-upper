#!perl -T

use strict;
use warnings;

use Test::More tests => 9;

require Scope::Upper;

for (qw/reap localize localize_elem TOP CURRENT UP DOWN SUB EVAL/) {
 eval { Scope::Upper->import($_) };
 is($@, '', 'import ' . $_);
}

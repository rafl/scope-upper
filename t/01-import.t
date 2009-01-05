#!perl -T

use strict;
use warnings;

use Test::More tests => 10;

require Scope::Upper;

for (qw/reap localize localize_elem localize_delete TOP HERE UP DOWN SUB EVAL/) {
 eval { Scope::Upper->import($_) };
 is($@, '', 'import ' . $_);
}

#!perl -T

use strict;
use warnings;

use Test::More tests => 12;

require Scope::Upper;

for (qw/reap localize localize_elem localize_delete unwind TOP HERE UP DOWN SUB EVAL CALLER/) {
 eval { Scope::Upper->import($_) };
 is($@, '', 'import ' . $_);
}

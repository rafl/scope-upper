#!perl -T

use strict;
use warnings;

use Test::More tests => 4;

use Scope::Upper qw/unwind/;

my @res;

@res = (7, eval {
 unwind;
 8;
});
is_deeply \@res, [ 7 ], 'unwind()';

@res = (7, eval {
 unwind -1;
 8;
});
is_deeply \@res, [ 7 ], 'unwind(-1)';

@res = (7, eval {
 unwind 100;
 8;
});
like $@, qr/^Can't\s+return\s+outside\s+a\s+subroutine/, 'unwind(100)';
is_deeply \@res, [ 7 ], 'unwind(100)';

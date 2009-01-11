#!perl -T

use strict;
use warnings;

use Test::More tests => 46;

use Scope::Upper qw/:words/;

is HERE, 0, 'main : here';
is TOP,  0, 'main : top';
is UP,   0, 'main : up';
is DOWN, 0, 'main : down';
is SUB,  undef, 'main : sub';
is EVAL, undef, 'main : eval';

{
 is HERE, 0, '{ 1 } : here';
 is TOP,  1, '{ 1 } : top';
 is UP,   1, '{ 1 } : up';
 is DOWN, 0, '{ 1 } : down';
 is DOWN(UP), 0, '{ 1 } : up then down';
 is UP(DOWN), 1, '{ 1 } : down then up';
}

do {
 is TOP, 1, 'do { 1 } : top';
 is SUB, undef, 'do { 1 } : sub';
 is EVAL, undef, 'do { 1 } : eval';
};

eval {
 is TOP, 1, 'eval { 1 } : top';
 is SUB, undef, 'eval { 1 } : sub';
 is EVAL, 0, 'eval { 1 } : eval';
};

eval q[
 is TOP, 1, 'eval "1" : top';
 is SUB, undef, 'eval "1" : sub';
 is EVAL, 0, 'eval "1" : eval';
];

do {
 is TOP, 1, 'do { 1 } while (0) : top';
} while (0);

sub {
 is TOP, 1, 'sub { 1 } : top';
 is SUB, 0, 'sub { 1 } : sub';
 is EVAL, undef, 'sub { 1 } : eval';
}->();

for (1) {
 is TOP, 1, 'for () { 1 } : top';
}

do {
 eval {
  do {
   sub {
    eval q[
     {
      is HERE, 0, 'mixed : here';
      is TOP,  6, 'mixed : top';
      is SUB,  2, 'mixed : first sub';
      is SUB(SUB), 2, 'mixed : still first sub';
      is EVAL, 1, 'mixed : first eval';
      is EVAL(EVAL),     1, 'mixed : still first eval';
      is EVAL(UP(EVAL)), 4, 'mixed : second eval';
     }
    ];
   }->();
  }
 };
} while (0);

{
 is CALLER,    1, '{ } : caller';
 is CALLER(0), 1, '{ } : caller 0';
 is CALLER(1), 1, '{ } : caller 1';
 sub {
  is CALLER,    0, '{ sub { } } : caller';
  is CALLER(0), 0, '{ sub { } } : caller 0';
  is CALLER(1), 2, '{ sub { } } : caller 1';
  for (1) {
   is CALLER,    1, '{ sub { for { } } } : caller';
   is CALLER(0), 1, '{ sub { for { } } } : caller 0';
   is CALLER(1), 3, '{ sub { for { } } } : caller 1';
   eval {
    is CALLER,    0, '{ sub { for { eval { } } } } : caller';
    is CALLER(0), 0, '{ sub { for { eval { } } } } : caller 0';
    is CALLER(1), 2, '{ sub { for { eval { } } } } : caller 1';
    is CALLER(2), 4, '{ sub { for { eval { } } } } : caller 2';
   }
  }
 }->();
}

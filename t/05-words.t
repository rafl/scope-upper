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
 is HERE, 1, '{ 1 } : here';
 is TOP,  0, '{ 1 } : top';
 is UP,   0, '{ 1 } : up';
 is DOWN, 1, '{ 1 } : down';
 is DOWN(UP), 1, '{ 1 } : up then down';
 is UP(DOWN), 0, '{ 1 } : down then up';
}

do {
 is HERE, 1,     'do { 1 } : here';
 is SUB,  undef, 'do { 1 } : sub';
 is EVAL, undef, 'do { 1 } : eval';
};

eval {
 is HERE, 1,     'eval { 1 } : here';
 is SUB,  undef, 'eval { 1 } : sub';
 is EVAL, 1,     'eval { 1 } : eval';
};

eval q[
 is HERE, 1,     'eval "1" : here';
 is SUB,  undef, 'eval "1" : sub';
 is EVAL, 1,     'eval "1" : eval';
];

do {
 is HERE, 1, 'do { 1 } while (0) : here';
} while (0);

sub {
 is HERE, 1,     'sub { 1 } : here';
 is SUB,  1,     'sub { 1 } : sub';
 is EVAL, undef, 'sub { 1 } : eval';
}->();

for (1) {
 is HERE, 1, 'for () { 1 } : here';
}

do {
 eval {
  do {
   sub {
    eval q[
     {
      is HERE,           6, 'mixed : here';
      is TOP,            0, 'mixed : top';
      is SUB,            4, 'mixed : first sub';
      is SUB(SUB),       4, 'mixed : still first sub';
      is EVAL,           5, 'mixed : first eval';
      is EVAL(EVAL),     5, 'mixed : still first eval';
      is EVAL(UP(EVAL)), 2, 'mixed : second eval';
     }
    ];
   }->();
  }
 };
} while (0);

{
 is CALLER,    0, '{ } : caller';
 is CALLER(0), 0, '{ } : caller 0';
 is CALLER(1), 0, '{ } : caller 1';
 sub {
  is CALLER,    2, '{ sub { } } : caller';
  is CALLER(0), 2, '{ sub { } } : caller 0';
  is CALLER(1), 0, '{ sub { } } : caller 1';
  for (1) {
   is CALLER,    2, '{ sub { for { } } } : caller';
   is CALLER(0), 2, '{ sub { for { } } } : caller 0';
   is CALLER(1), 0, '{ sub { for { } } } : caller 1';
   eval {
    is CALLER,    4, '{ sub { for { eval { } } } } : caller';
    is CALLER(0), 4, '{ sub { for { eval { } } } } : caller 0';
    is CALLER(1), 2, '{ sub { for { eval { } } } } : caller 1';
    is CALLER(2), 0, '{ sub { for { eval { } } } } : caller 2';
   }
  }
 }->();
}

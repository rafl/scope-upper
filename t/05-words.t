#!perl -T

use strict;
use warnings;

use Test::More tests => 29 + 13 * 2;

use Scope::Upper qw/:words/;

# This test is for internal use only and doesn't imply any kind of future
# compatibility on what the words should actually return.
# It is expected to fail when ran under the debugger.

is HERE, 0, 'main : here';
is TOP,  0, 'main : top';
is UP,   0, 'main : up';
is SUB,  undef, 'main : sub';
is EVAL, undef, 'main : eval';

{
 is HERE, 1, '{ 1 } : here';
 is TOP,  0, '{ 1 } : top';
 is UP,   0, '{ 1 } : up';
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
 is SCOPE,    1, 'block : scope';
 is SCOPE(0), 1, 'block : scope 0';
 is SCOPE(1), 0, 'block : scope 1';
 is CALLER,    0, 'block: caller';
 is CALLER(0), 0, 'block : caller 0';
 is CALLER(1), 0, 'block : caller 1';
 sub {
  is SCOPE,    2, 'block sub : scope';
  is SCOPE(0), 2, 'block sub : scope 0';
  is SCOPE(1), 1, 'block sub : scope 1';
  is CALLER,    2, 'block sub : caller';
  is CALLER(0), 2, 'block sub : caller 0';
  is CALLER(1), 0, 'block sub : caller 1';
  for (1) {
   is SCOPE,    3, 'block sub for : scope';
   is SCOPE(0), 3, 'block sub for : scope 0';
   is SCOPE(1), 2, 'block sub for : scope 1';
   is CALLER,    2, 'block sub for : caller';
   is CALLER(0), 2, 'block sub for : caller 0';
   is CALLER(1), 0, 'block sub for : caller 1';
   eval {
    is SCOPE,    4, 'block sub for eval : scope';
    is SCOPE(0), 4, 'block sub for eval : scope 0';
    is SCOPE(1), 3, 'block sub for eval : scope 1';
    is SCOPE(2), 2, 'block sub for eval : scope 2';
    is CALLER,    4, 'block sub for eval : caller';
    is CALLER(0), 4, 'block sub for eval : caller 0';
    is CALLER(1), 2, 'block sub for eval : caller 1';
    is CALLER(2), 0, 'block sub for eval : caller 2';
   }
  }
 }->();
}

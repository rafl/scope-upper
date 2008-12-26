#!perl -T

use strict;
use warnings;

use Test::More tests => 9;

use Scope::Upper qw/TOPLEVEL/;

is TOPLEVEL, 0, 'main is 0';

{
 is TOPLEVEL, 1, '{ 1 }';
}

do {
 is TOPLEVEL, 1, 'do { 1 }';
};

eval {
 is TOPLEVEL, 1, 'eval { 1 }';
};

eval q[
 is TOPLEVEL, 1, 'eval "1"';
];

do {
 is TOPLEVEL, 1, 'do { 1 } while (0)';
} while (0);

sub {
 is TOPLEVEL, 1, 'sub { 1 }';
}->();

for (1) {
 is TOPLEVEL, 1, 'for () { 1 }';
}

do {
 eval {
  do {
   sub {
    eval q[
     {
      is TOPLEVEL, 6, 'all'
     }
    ];
   }->();
  }
 };
} while (0);

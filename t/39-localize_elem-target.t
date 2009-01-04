#!perl -T

use strict;
use warnings;

use Test::More tests => 21;

use Scope::Upper qw/localize_elem/;

# Arrays

our @a;

{
 local @a = (4 .. 6);
 {
  localize_elem '@main::a', 1, 8, 0;
  is_deeply \@a, [ 4, 8, 6 ], 'localize_elem "@a", 1, 8, 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_elem "@a", 1, 8, 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  localize_elem '@main::a', 4, 8, 0;
  is_deeply \@a, [ 4 .. 6, undef, 8 ], 'localize_elem "@a", 4, 8, 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_elem "@a", 4, 8, 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  localize_elem '@main::a', -2, 8, 0;
  is_deeply \@a, [ 4, 8, 6 ], 'localize_elem "@a", -2, 8, 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_elem "@a", -2, 8, 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  eval { localize_elem '@main::a', -4, 8, 0 };
  like $@, qr/Modification of non-creatable array value attempted, subscript -4/, 'localize_elem "@a", -4, 8, 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_elem "@a", -4, 8, 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize_elem '@main::a', 1, 12, 1;
   is_deeply \@a, [ 5 .. 7 ], 'localize_elem "@a", 1, 12, 1 [not yet]';
  }
  is_deeply \@a, [ 5, 12, 7 ], 'localize_elem "@a", 1, 12, 1 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_elem "@a", 1, 12, 1 [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize_elem '@main::a', 4, 12, 1;
   is_deeply \@a, [ 5 .. 7 ], 'localize_elem "@a", 4, 12, 1 [not yet]';
  }
  is_deeply \@a, [ 5 .. 7, undef, 12 ], 'localize_elem "@a", 4, 12, 1 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_elem "@a", 4, 12, 1 [end]';
}

# Hashes

our %h;

{
 local %h = (a => 1, b => 2);
 {
  localize_elem '%main::h', 'a', 3, 0;
  is_deeply \%h, { a => 3, b => 2 }, 'localize_elem "%h", "a", 3, 0 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_elem "%h", "a", 3, 0 [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  localize_elem '%main::h', 'c', 3, 0;
  is_deeply \%h, { a => 1, b => 2, c => 3 }, 'localize_elem "%h", "c", 3, 0 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_elem "%h", "c", 3, 0 [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  local %h = (a => 3, c => 4);
  {
   localize_elem '%main::h', 'a', 5, 1;
   is_deeply \%h, { a => 3, c => 4 }, 'localize_elem "%h", "a", 5, 1 [not yet]';
  }
  is_deeply \%h, { a => 5, c => 4 }, 'localize_elem "%h", "a", 5, 1 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_elem "%h", "a", 5, 1 [end]';
}


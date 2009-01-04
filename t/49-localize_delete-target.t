#!perl -T

use strict;
use warnings;

use Test::More tests => 36;

use Scope::Upper qw/localize_delete/;

# Arrays

our @a;

{
 local @a = (4 .. 6);
 {
  localize_delete '@main::a', 1, 0;
  is_deeply \@a, [ 4, undef, 6 ], 'localize_delete "@a", 1, 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 1, 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  localize_delete '@main::a', 4, 0;
  is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (nonexistent), 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (nonexistent), 0 [end]';
}

{
 local @a = (4 .. 6);
 local $a[4] = 7;
 {
  localize_delete '@main::a', 4, 0;
  is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (exists), 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6, undef, 7 ], 'localize_delete "@a", 4 (exists), 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  localize_delete '@main::a', -2, 0;
  is_deeply \@a, [ 4, undef, 6 ], 'localize_delete "@a", -2, 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", -2, 0 [end]';
}

{
 local @a = (4 .. 6);
 local $a[4] = 7;
 {
  localize_delete '@main::a', -1, 0;
  is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", -1 (exists), 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6, undef, 7 ], 'localize_delete "@a", -1 (exists), 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  eval { localize_delete '@main::a', -4, 0 };
  like $@, qr/Modification of non-creatable array value attempted, subscript -4/, 'localize_delete "@a", -4 (out of bounds), 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", -4 (out of bounds), 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize_delete '@main::a', 1, 1;
   is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 1, 1 [not yet]';
  }
  is_deeply \@a, [ 5, undef, 7 ], 'localize_delete "@a", 1, 1 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 1, 1 [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize_delete '@main::a', 4, 1;
   is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 4 (nonexistent), 1 [not yet]';
  }
  is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 4 (nonexistent), 1 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (nonexistent), 1 [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  local $a[4] = 8;
  {
   localize_delete '@main::a', 4, 1;
   is_deeply \@a, [ 5 .. 7, undef, 8 ], 'localize_delete "@a", 4 (exists), 1 [not yet]';
  }
  is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 4 (exists), 1 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (exists), 1 [end]';
}

# Hashes

our %h;

{
 local %h = (a => 1, b => 2);
 {
  localize_delete '%main::h', 'a', 0;
  is_deeply \%h, { b => 2 }, 'localize_delete "%h", "a", 0 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "a", 0 [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  localize_delete '%main::h', 'c', 0;
  is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "c", 0 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "c", 0 [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  local %h = (a => 3, c => 4);
  {
   localize_delete '%main::h', 'a', 1;
   is_deeply \%h, { a => 3, c => 4 }, 'localize_delete "%h", "a", 1 [not yet]';
  }
  is_deeply \%h, { c => 4 }, 'localize_delete "%h", "a", 1 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "a", 1 [end]';
}

# Others

our $x = 1;
{
 localize_delete '$x', 2, 0;
 is $x, undef, 'localize "$x", anything, 0 [ok]';
}
is $x, 1, 'localize "$x", anything, 0 [end]';

sub x { 1 };
{
 localize_delete '&x', 2, 0;
 ok !exists(&x), 'localize "&x", anything, 0 [ok]';
}
is x(), 1, 'localize "&x", anything, 0 [end]';

{
 localize_delete *x, sub { }, 0;
 is !exists(&x),  1, 'localize *x, anything, 0 [ok 1]';
 is !defined($x), 1, 'localize *x, anything, 0 [ok 2]';
}
is x(), 1, 'localize *x, anything, 0 [end 1]';
is $x,  1, 'localize *x, anything, 0 [end 2]';

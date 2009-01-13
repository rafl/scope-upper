#!perl -T

use strict;
use warnings;

use Test::More tests => 36;

use Scope::Upper qw/localize_delete UP HERE/;

# Arrays

our @a;

{
 local @a = (4 .. 6);
 {
  localize_delete '@main::a', 1 => HERE;
  is_deeply \@a, [ 4, undef, 6 ], 'localize_delete "@a", 1 => HERE [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 1 => HERE [end]';
}

{
 local @a = (4 .. 6);
 {
  localize_delete '@main::a', 4 => HERE;
  is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (nonexistent) => HERE [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (nonexistent) => HERE [end]';
}

{
 local @a = (4 .. 6);
 local $a[4] = 7;
 {
  localize_delete '@main::a', 4 => HERE;
  is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (exists) => HERE [ok]';
 }
 is_deeply \@a, [ 4 .. 6, undef, 7 ], 'localize_delete "@a", 4 (exists) => HERE [end]';
}

{
 local @a = (4 .. 6);
 {
  localize_delete '@main::a', -2 => HERE;
  is_deeply \@a, [ 4, undef, 6 ], 'localize_delete "@a", -2 => HERE [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", -2 => HERE [end]';
}

{
 local @a = (4 .. 6);
 local $a[4] = 7;
 {
  localize_delete '@main::a', -1 => HERE;
  is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", -1 (exists) => HERE [ok]';
 }
 is_deeply \@a, [ 4 .. 6, undef, 7 ], 'localize_delete "@a", -1 (exists) => HERE [end]';
}

{
 local @a = (4 .. 6);
 {
  eval { localize_delete '@main::a', -4 => HERE };
  like $@, qr/Modification of non-creatable array value attempted, subscript -4/, 'localize_delete "@a", -4 (out of bounds) => HERE [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", -4 (out of bounds) => HERE [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize_delete '@main::a', 1 => UP;
   is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 1 => UP [not yet]';
  }
  is_deeply \@a, [ 5, undef, 7 ], 'localize_delete "@a", 1 => UP [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 1 => UP [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize_delete '@main::a', 4 => UP;
   is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 4 (nonexistent) => UP [not yet]';
  }
  is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 4 (nonexistent) => UP [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (nonexistent) => UP [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  local $a[4] = 8;
  {
   localize_delete '@main::a', 4 => UP;
   is_deeply \@a, [ 5 .. 7, undef, 8 ], 'localize_delete "@a", 4 (exists) => UP [not yet]';
  }
  is_deeply \@a, [ 5 .. 7 ], 'localize_delete "@a", 4 (exists) => UP [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize_delete "@a", 4 (exists) => UP [end]';
}

# Hashes

our %h;

{
 local %h = (a => 1, b => 2);
 {
  localize_delete '%main::h', 'a' => HERE;
  is_deeply \%h, { b => 2 }, 'localize_delete "%h", "a" => HERE [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "a" => HERE [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  localize_delete '%main::h', 'c' => HERE;
  is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "c" => HERE [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "c" => HERE [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  local %h = (a => 3, c => 4);
  {
   localize_delete '%main::h', 'a' => UP;
   is_deeply \%h, { a => 3, c => 4 }, 'localize_delete "%h", "a" => UP [not yet]';
  }
  is_deeply \%h, { c => 4 }, 'localize_delete "%h", "a" => UP [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize_delete "%h", "a" => UP [end]';
}

# Others

our $x = 1;
{
 localize_delete '$x', 2 => HERE;
 is $x, undef, 'localize "$x", anything => HERE [ok]';
}
is $x, 1, 'localize "$x", anything => HERE [end]';

sub x { 1 };
{
 localize_delete '&x', 2 => HERE;
 ok !exists(&x), 'localize "&x", anything => HERE [ok]';
}
is x(), 1, 'localize "&x", anything => HERE [end]';

{
 localize_delete *x, sub { } => HERE;
 is !exists(&x),  1, 'localize *x, anything => HERE [ok 1]';
 is !defined($x), 1, 'localize *x, anything => HERE [ok 2]';
}
is x(), 1, 'localize *x, anything => HERE [end 1]';
is $x,  1, 'localize *x, anything => HERE [end 2]';

#!perl

use strict;
use warnings;

use Scope::Upper qw/localize_delete/;

use Test::More tests => 5;

our $deleted;

{
 package Scope::Upper::Test::TiedArray;

 sub TIEARRAY { bless [], $_[0] }
 sub STORE { $_[0]->[$_[1]] = $_[2] }
 sub FETCH { $_[0]->[$_[1]] }
 sub CLEAR { @{$_[0]} = (); }
 sub FETCHSIZE { scalar @{$_[0]} }
 sub DELETE { ++$main::deleted; delete $_[0]->[$_[1]] }
 sub EXTEND {}
}

our @a;

tie @a, 'Scope::Upper::Test::TiedArray';
{
 local @a = (5 .. 7);
 local $a[4] = 9;
 is $deleted, undef, 'localize_delete @tied_array, $existent => 0 [not deleted]';
 {
  localize_delete '@a', 4 => 0;
  is $deleted, 1, 'localize_delete @tied_array, $existent => 0 [deleted]';
  is_deeply \@a, [ 5 .. 7 ], 'localize_delete @tied_array, $existent => 0 [ok]';
 }
 is_deeply \@a, [ 5 .. 7, undef, 9 ], 'localize_elem @incomplete_tied_array, $nonexistent, 12 => 0 [end]';
 is $deleted, 1, 'localize_delete @tied_array, $existent => 0 [not more deleted]';
}

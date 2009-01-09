#!perl -T

use strict;
use warnings;

use Test::More tests => 10 + 5 + 6;

use Scope::Upper qw/localize/;

our $x;

sub loc { local $x; my $y = $_[1]; localize '$x', $y, $_[0] + 1 }

$x = 0;
{
 is($x, 0, 'start');
 local $x = 7;
 {
  local $x = 8;
  loc(1, 1);
  is($x, 8, 'not localized');
  local $x = 9;
  is($x, 9, 'not localized');
 }
 is($x, 1, 'localized to 1');
 {
  is($x, 1, 'localized to 1');
  {
   is($x, 1, 'localized to 1');
   local $x = 10;
   is($x, 10, 'localized to undef');
  }
  is($x, 1, 'localized to 1');
 }
 is($x, 1, 'localized to 1');
}
is($x, 0, 'end');

$x = 0;
{
 is($x, 0, 'start');
 local $x = 8;
 {
  {
   local $x = 8;
   loc(2, 1);
   is($x, 8, 'not localized');
  }
  loc(0, 2);
  is($x, 2, 'localized to 2');
 }
 is($x, 1, 'localized to 1');
}
is($x, 0, 'end');

$x = 0;
{
 is($x, 0, 'start');
 local $x;
 {
  {
   loc(2, 1);
   is($x, undef, 'not localized');
   local $x;
   loc(1, 2);
   is($x, undef, 'not localized');
  }
  is($x, 2, 'localized to 2');
 }
 is($x, 1, 'localized to 1');
}
is($x, 0, 'end');


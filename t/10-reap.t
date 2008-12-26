#!perl -T

use strict;
use warnings;

use Test::More tests => 4 + 8 + 8 + 18 + 4 + 8 + 6 + 11 + 5 + 17;

use Scope::Upper qw/reap/;

my $x;

sub add { local $_; my $y = $_[1]; reap sub { $x += $y }, $_[0] + 1 }

$x = 0;
{
 is($x, 0, 'start');
 {
  add(0, 1);
  is($x, 0, '1 didn\'t run');
 }
 is($x, 1, '1 ran');
}
is($x, 1, 'end');

$x = 0;
{
 is($x, 0, 'start');
 local $_ = 3;
 is($_, 3, '$_ has the right value');
 {
  add(0, 1);
  is($_, 3, '$_ has the right value');
  local $_ = 7;
  is($_, 7, '$_ has the right value');
  is($x, 0, '1 didn\'t run');
 }
 is($x, 1, '1 ran');
 is($_, 3, '$_ has the right value');
}
is($x, 1, 'end');

$x = 0;
{
 is($x, 0, 'start');
 {
  add(0, 1);
  is($x, 0, '1 didn\'t run');
  {
   add(0, 2);
   is($x, 0, '1 and 2 didn\'t run');
  }
  is($x, 2, '1 didn\'t run, 2 ran');
  {
   add(0, 4);
   is($x, 2, '1 and 3 didn\'t run, 2 ran');
  }
  is($x, 6, '1 didn\'t run, 2 and 3 ran');
 }
 is($x, 7, '1, 2 and 3 ran');
}
is($x, 7, 'end');

$x = 0;
{
 is($x, 0, 'start');
 local $_ = 3;
 is($_, 3, '$_ has the right value');
 {
  add(0, 1);
  is($_, 3, '$_ has the right value');
  local $_ = 5;
  is($x, 0, '1 didn\'t run');
  is($_, 5, '$_ has the right value');
  {
   add(0, 2);
   is($_, 5, '$_ has the right value');
   local $_ = 7;
   is($_, 7, '$_ has the right value');
   is($x, 0, '1 and 2 didn\'t run');
  }
  is($x, 2, '1 didn\'t run, 2 ran');
  is($_, 5, '$_ has the right value');
  {
   local $_ = 9;
   is($_, 9, '$_ has the right value');
   add(0, 4);
   local $_ = 11;
   is($_, 11, '$_ has the right value');
   is($x, 2, '1 and 3 didn\'t run, 2 ran');
  }
  is($x, 6, '1 didn\'t run, 2 and 3 ran');
  is($_, 5, '$_ has the right value');
 }
 is($x, 7, '1, 2 and 3 ran');
 is($_, 3, '$_ has the right value');
}
is($x, 7, 'end');

$x = 0;
{
 is($x, 0, 'start');
 {
  add(0, 1);
  add(0, 2);
  is($x, 0, '1 and 2 didn\'t run');
 }
 is($x, 3, '1 and 2 ran');
}
is($x, 3, 'end');

$x = 0;
{
 is($x, 0, 'start');
 local $_ = 3;
 {
  local $_ = 5;
  add(0, 1);
  is($_, 5, '$_ has the right value');
  local $_ = 7;
  add(0, 2);
  is($_, 7, '$_ has the right value');
  is($x, 0, '1 and 2 didn\'t run');
  local $_ = 9;
  is($_, 9, '$_ has the right value');
 }
 is($x, 3, '1 and 2 ran');
 is($_, 3, '$_ has the right value');
}
is($x, 3, 'end');

$x = 0;
{
 is($x, 0, 'start');
 {
  {
   {
    add(2, 1);
    is($x, 0, '1 didn\'t run');
   }
   is($x, 0, '1 didn\'t run');
  }
  is($x, 0, '1 didn\'t run');
 }
 is($x, 1, '1 ran');
}
is($x, 1, 'end');

$x = 0;
{
 is($x, 0, 'start');
 {
  {
   add(1, 1);
   is($x, 0, '1 didn\'t run');
  }
  is($x, 0, '1 didn\'t run');
 }
 is($x, 1, '1 ran');
 { 
  {
   {
    add(2, 2);
    is($x, 1, '2 didn\'t run');
   }
   is($x, 1, '2 didn\'t run');
   {
    add(1, 4);
    is($x, 1, '2 and 3 didn\'t run');
   }
   is($x, 1, '2 and 3 didn\'t run');
  }
  is($x, 5, '2 didn\'t run, 3 ran');
 }
 is($x, 7, '2 and 3 ran');
}
is($x, 7, 'end');

sub bleh { add(1, 2); }

$x = 0;
{
 is($x, 0, 'start');
 {
  add(0, 1);
  is($x, 0, '1 didn\'t run');
  bleh();
  is($x, 0, '1 didn\'t run');
 }
 is($x, 3, '1 ran');
}
is($x, 3, 'end');

sub bar {
 is($_, 7, '$_ has the right value');
 local $_ = 9;
 add(2, 4);
 is($_, 9, '$_ has the right value');
 add(3, 8);
 is($_, 9, '$_ has the right value');
}

sub foo {
 local $_ = 7;
 add(0, 2);
 is($_, 7, '$_ has the right value');
 is($x, 0, '1, 2 didn\'t run');
 bar();
 is($x, 0, '1, 2, 3, 4 didn\'t run');
 is($_, 7, '$_ has the right value');
 add(1, 16);
 is($_, 7, '$_ has the right value');
}

$x = 0;
{
 is($x, 0, 'start');
 local $_ = 3;
 add(0, 1);
 is($_, 3, '$_ has the right value');
 {
  local $_ = 5;
  is($_, 5, '$_ has the right value');
  is($x, 0, '1 didn\'t run');
  {
   foo();
   is($x, 2, '1, 3, 4 and 5 didn\'t run, 2 ran');
   is($_, 5, '$_ has the right value');
  }
  is($x, 22, '1 and 4 didn\'t run, 2, 3 and 5 ran');
 }
 is($x, 30, '1 didn\'t run, 2, 3, 4 and 5 ran');
}
is($x, 31, 'end');

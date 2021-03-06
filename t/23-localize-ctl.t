#!perl -T

use strict;
use warnings;

use Test::More tests => 44;

use Scope::Upper qw/localize UP HERE/;

our ($x, $y);

{
 local $x = 1;
 {
  local $x = 2;
  localize '$y' => 1 => HERE;
  is $x, 2, 'last 0 [ok - x]';
  is $y, 1, 'last 0 [ok - y]';
  last;
  $y = 2;
 }
 is $x, 1,     'last 0 [end - x]';
 is $y, undef, 'last 0 [end - y]';
}

{
 local $x = 1;
LOOP:
 {
  local $x = 2;
  local $y = 0;
  {
   local $x = 3;
   localize '$y' => 1 => UP;
   is $x, 3, 'last 1 [ok - x]';
   is $y, 0, 'last 1 [ok - y]';
   last LOOP;
   $y = 3;
  }
  $y = 2;
 }
 is $x, 1,     'last 1 [end - x]';
 is $y, undef, 'last 1 [end - y]';
}

{
 local $x = 1;
 {
  local $x = 2;
  localize '$y' => 1 => HERE;
  is $x, 2, 'next 0 [ok - x]';
  is $y, 1, 'next 0 [ok - y]';
  next;
  $y = 2;
 }
 is $x, 1,     'next 0 [end - x]';
 is $y, undef, 'next 0 [end - y]';
}

{
 local $x = 1;
LOOP:
 {
  local $x = 2;
  local $y = 0;
  {
   local $x = 3;
   localize '$y' => 1 => UP;
   is $x, 3, 'next 1 [ok - x]';
   is $y, 0, 'next 1 [ok - y]';
   next LOOP;
   $y = 3;
  }
  $y = 2;
 }
 is $x, 1,     'next 1 [end - x]';
 is $y, undef, 'next 1 [end - y]';
}

{
 local $x = 1;
 {
  local $x = 2;
  {
   localize '$y' => 1 => UP UP;
  }
  is $x, 2,     'goto 1 [not yet - x]';
  is $y, undef, 'goto 1 [not yet - y]';
  {
   local $x = 3;
   goto OVER1;
  }
 }
 $y = 0;
OVER1:
 is $x, 1, 'goto 1 [ok - x]';
 is $y, 1, 'goto 1 [ok - y]';
}

$y = undef;
{
 local $x = 1;
 {
  local $x = 2;
  {
   local $x = 3;
   {
    localize '$y' => 1 => UP UP UP;
   }
   is $x, 3,     'goto 2 [not yet - x]';
   is $y, undef, 'goto 2 [not yet - y]';
   {
    local $x = 4;
    goto OVER2;
   }
  }
 }
 $y = 0;
OVER2:
 is $x, 1, 'goto 2 [ok - x]';
 is $y, 1, 'goto 2 [ok - y]';
}

$y = undef;
{
 local $x = 1;
 {
  eval {
   local $x = 2;
   {
    {
     local $x = 3;
     localize '$y' => 1 => UP UP UP UP;
     is $x, 3,     'die - reap outside eval [not yet 1 - x]';
     is $y, undef, 'die - reap outside eval [not yet 1 - y]';
    }
    is $x, 2,     'die - reap outside eval [not yet 2 - x]';
    is $y, undef, 'die - reap outside eval [not yet 2 - y]';
    die;
   }
  };
  is $x, 1,     'die - reap outside eval [not yet 3 - x]';
  is $y, undef, 'die - reap outside eval [not yet 3 - y]';
 } # should trigger here
 is $x, 1, 'die - reap outside eval [ok - x]';
 is $y, 1, 'die - reap outside eval [ok - y]';
}

$y = undef;
{
 local $x = 1;
 eval {
  local $x = 2;
  {
   {
    local $x = 3;
    localize '$y' => 1 => UP UP UP;
    is $x, 3,     'die - reap at eval [not yet 1 - x]';
    is $y, undef, 'die - reap at eval [not yet 1 - y]';
   }
   is $x, 2,     'die - reap at eval [not yet 2 - x]';
   is $y, undef, 'die - reap at eval [not yet 2 - y]';
   die;
  }
 }; # should trigger here
 is $x, 1, 'die - reap at eval [ok - x]';
 is $y, 1, 'die - reap at eval [ok - y]';
}

$y = undef;
{
 local $x = 1;
 eval {
  local $x = 2;
  {
   {
    local $x = 3;
    localize '$y' => 1 => UP UP;
    is $x, 3,     'die - reap inside eval [not yet 1 - x]';
    is $y, undef, 'die - reap inside eval [not yet 1 - y]';
   }
   is $x, 2,     'die - reap inside eval [not yet 2 - x]';
   is $y, undef, 'die - reap inside eval [not yet 2 - y]';
   die;
  } # should trigger here
 };
 is $x, 1,     'die - reap inside eval [ok - x]';
 is $y, undef, 'die - reap inside eval [ok - y]';
}

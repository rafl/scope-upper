#!perl -T

use strict;
use warnings;

use Test::More tests => 50;

use Scope::Upper qw/localize/;

# Scalars

our $x;

{
 local $x = 2;
 {
  localize *x, \1, 0;
  is $x, 1, 'localize *x, \1, 0 [ok]';
 }
 is $x, 2, 'localize *x, \1, 0 [end]';
}

sub _t { shift->{t} }

{
 local $x;
 {
  localize *x, \bless({ t => 1 }, 'main'), 0;
  is ref($x), 'main', 'localize *x, obj, 0 [ref]';
  is $x->_t, 1, 'localize *x, obj, 0 [meth]';
 }
 is $x, undef, 'localize *x, obj, 0 [end]';
}

{
 local $x = 2;
 {
  local $x = 3;
  localize *x, 1, 0;
  is $x, undef, 'localize *x, 1, 0 [ok]';
 }
 is $x, $] < 5.008009 ? undef : 2, 'localize *x, 1, 0 [end]';
}
undef *x;

{
 local $x = 7;
 {
  localize '$x', 2, 0;
  is $x, 2, 'localize "$x", 2, 0 [ok]';
 }
 is $x, 7, 'localize "$x", 2, 0 [end]';
}

{
 local $x = 8;
 {
  localize ' $x', 3, 0;
  is $x, 3, 'localize " $x", 3, 0 [ok]';
 }
 is $x, 8, 'localize " $x", 3, 0 [end]';
}

SKIP:
{
 skip 'Can\'t localize through a reference in 5.6' => 2 if $] < 5.008;
 no strict 'refs';
 local ${''} = 9;
 {
  localize '$', 4, 0;
  is ${''}, 4, 'localize "$", 4, 0 [ok]';
 }
 is ${''}, 9, 'localize "$", 4, 0 [end]';
}

SKIP:
{
 skip 'Can\'t localize through a reference in 5.6' => 2 if $] < 5.008;
 no strict 'refs';
 local ${''} = 10;
 {
  localize '', 5, 0;
  is ${''}, 5, 'localize "", 4, 0 [ok]';
 }
 is ${''}, 10, 'localize "", 4, 0 [end]';
}

{
 local $x = 2;
 {
  localize 'x', \1, 0;
  is $x, 1, 'localize "x", \1, 0 [ok]';
 }
 is $x, 2, 'localize "x", \1, 0 [end]';
}

{
 local $x = 4;
 {
  localize 'x', 3, 0;
  is $x, 3, 'localize "x", 3, 0 [ok]';
 }
 is $x, 4, 'localize "x", 3, 0 [end]';
}

{
 local $x;
 {
  localize 'x', bless({ t => 2 }, 'main'), 0;
  is ref($x), 'main', 'localize "x", obj, 0 [ref]';
  is $x->_t, 2, 'localize "x", obj, 0 [meth]';
 }
 is $x, undef, 'localize "x", obj, 0 [end]';
}

sub callthrough (*$) {
 my ($what, $val) = @_;
 if (ref $what) {
  $what = $$what;
  $val  = eval "\\$val";
 }
 local $x = 'x';
 localize $what, $val, 1;
 is $x, 'x', 'localize callthrough [not yet]';
}

{
 package Scope::Upper::Test::Mock1;
 our $x;
 {
  main::callthrough(*x, 4);
  Test::More::is($x,       4,     'localize glob [ok - SUTM1]');
  Test::More::is($main::x, undef, 'localize glob [ok - main]');
 }
}

{
 package Scope::Upper::Test::Mock2;
 our $x;
 {
  main::callthrough(*main::x, 5);
  Test::More::is($x,       undef, 'localize qualified glob [ok - SUTM2]');
  Test::More::is($main::x, 5,     'localize qualified glob [ok - main]');
 }
}

{
 package Scope::Upper::Test::Mock3;
 our $x;
 {
  main::callthrough('$main::x', 6);
  Test::More::is($x,       undef, 'localize fully qualified name [ok - SUTM3]');
  Test::More::is($main::x, 6,     'localize fully qualified name [ok - main]');
 }
}

{
 package Scope::Upper::Test::Mock4;
 our $x;
 {
  main::callthrough('$x', 7);
  Test::More::is($x,       7,     'localize unqualified name [ok - SUTM4]');
  Test::More::is($main::x, undef, 'localize unqualified name [ok - main]');
 }
}

$_ = 'foo';
{
 package Scope::Upper::Test::Mock5;
 {
  main::callthrough('$_', 'bar');
  Test::More::ok(/bar/, 'localize $_ [ok]');
 }
}
undef $_;

# Arrays

our @a;
my $xa = [ 7 .. 9 ];

{
 local @a = (4 .. 6);
 {
  localize *a, $xa, 0;
  is_deeply \@a, $xa, 'localize *a, [ ], 0 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize *a, [ ], 0 [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize *a, $xa, 1;
   is_deeply \@a, [ 5 .. 7 ], 'localize *a, [ ], 1 [not yet]';
  }
  is_deeply \@a, $xa, 'localize *a, [ ], 1 [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize *a, [ ], 1 [end]';
}

# Hashes

our %h;
my $xh = { a => 5, c => 7 };

{
 local %h = (a => 1, b => 2);
 {
  localize *h, $xh, 0;
  is_deeply \%h, $xh, 'localize *h, { }, 0 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize *h, { }, 0 [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  local %h = (b => 3, c => 4);
  {
   localize *h, $xh, 1;
   is_deeply \%h, { b => 3, c => 4 }, 'localize *h, { }, 1 [not yet]';
  }
  is_deeply \%h, $xh, 'localize *h, { }, 1 [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize *h, { }, 1 [end]';
}

# Code

{
 local *foo = sub { 7 };
 {
  localize *foo, sub { 6 }, 1;
  is foo(), 7, 'localize *foo, sub { 6 }, 1 [not yet]';
 }
 is foo(), 6, 'localize *foo, sub { 6 }, 1 [ok]';
}

{
 local *foo = sub { 9 };
 {
  localize '&foo', sub { 8 }, 1;
  is foo(), 9, 'localize "&foo", sub { 8 }, 1 [not yet]';
 }
 is foo(), 8, 'localize "&foo", sub { 8 }, 1 [ok]';
}

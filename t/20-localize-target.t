#!perl -T

use strict;
use warnings;

use Test::More tests => 50;

use Scope::Upper qw/localize UP HERE/;

# Scalars

our $x;

{
 local $x = 2;
 {
  localize *x, \1 => HERE;
  is $x, 1, 'localize *x, \1 => HERE [ok]';
 }
 is $x, 2, 'localize *x, \1 => HERE [end]';
}

sub _t { shift->{t} }

{
 local $x;
 {
  localize *x, \bless({ t => 1 }, 'main') => HERE;
  is ref($x), 'main', 'localize *x, obj => HERE [ref]';
  is $x->_t, 1, 'localize *x, obj => HERE [meth]';
 }
 is $x, undef, 'localize *x, obj => HERE [end]';
}

{
 local $x = 2;
 {
  local $x = 3;
  localize *x, 1 => HERE;
  is $x, undef, 'localize *x, 1 => HERE [ok]';
 }
 is $x, $] < 5.008009 ? undef : 2, 'localize *x, 1 => HERE [end]';
}
undef *x;

{
 local $x = 7;
 {
  localize '$x', 2 => HERE;
  is $x, 2, 'localize "$x", 2 => HERE [ok]';
 }
 is $x, 7, 'localize "$x", 2 => HERE [end]';
}

{
 local $x = 8;
 {
  localize ' $x', 3 => HERE;
  is $x, 3, 'localize " $x", 3 => HERE [ok]';
 }
 is $x, 8, 'localize " $x", 3 => HERE [end]';
}

SKIP:
{
 skip 'Can\'t localize through a reference in 5.6' => 2 if $] < 5.008;
 eval q{
  no strict 'refs';
  local ${''} = 9;
  {
   localize '$', 4 => HERE;
   is ${''}, 4, 'localize "$", 4 => HERE [ok]';
  }
  is ${''}, 9, 'localize "$", 4 => HERE [end]';
 };
}

SKIP:
{
 skip 'Can\'t localize through a reference in 5.6' => 2 if $] < 5.008;
 eval q{
  no strict 'refs';
  local ${''} = 10;
  {
   localize '', 5 => HERE;
   is ${''}, 5, 'localize "", 4 => HERE [ok]';
  }
  is ${''}, 10, 'localize "", 4 => HERE [end]';
 };
}

{
 local $x = 2;
 {
  localize 'x', \1 => HERE;
  is $x, 1, 'localize "x", \1 => HERE [ok]';
 }
 is $x, 2, 'localize "x", \1 => HERE [end]';
}

{
 local $x = 4;
 {
  localize 'x', 3 => HERE;
  is $x, 3, 'localize "x", 3 => HERE [ok]';
 }
 is $x, 4, 'localize "x", 3 => HERE [end]';
}

{
 local $x;
 {
  localize 'x', bless({ t => 2 }, 'main') => HERE;
  is ref($x), 'main', 'localize "x", obj => HERE [ref]';
  is $x->_t, 2, 'localize "x", obj => HERE [meth]';
 }
 is $x, undef, 'localize "x", obj => HERE [end]';
}

sub callthrough (*$) {
 my ($what, $val) = @_;
 if (ref $what) {
  $what = $$what;
  $val  = eval "\\$val";
 }
 local $x = 'x';
 localize $what, $val => UP;
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
  localize *a, $xa => HERE;
  is_deeply \@a, $xa, 'localize *a, [ ] => HERE [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize *a, [ ] => HERE [end]';
}

{
 local @a = (4 .. 6);
 {
  local @a = (5 .. 7);
  {
   localize *a, $xa => UP;
   is_deeply \@a, [ 5 .. 7 ], 'localize *a, [ ] => UP [not yet]';
  }
  is_deeply \@a, $xa, 'localize *a, [ ] => UP [ok]';
 }
 is_deeply \@a, [ 4 .. 6 ], 'localize *a, [ ] => UP [end]';
}

# Hashes

our %h;
my $xh = { a => 5, c => 7 };

{
 local %h = (a => 1, b => 2);
 {
  localize *h, $xh => HERE;
  is_deeply \%h, $xh, 'localize *h, { } => HERE [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize *h, { } => HERE [end]';
}

{
 local %h = (a => 1, b => 2);
 {
  local %h = (b => 3, c => 4);
  {
   localize *h, $xh => UP;
   is_deeply \%h, { b => 3, c => 4 }, 'localize *h, { } => UP [not yet]';
  }
  is_deeply \%h, $xh, 'localize *h, { } => UP [ok]';
 }
 is_deeply \%h, { a => 1, b => 2 }, 'localize *h, { } => UP [end]';
}

# Code

{
 local *foo = sub { 7 };
 {
  localize *foo, sub { 6 } => UP;
  is foo(), 7, 'localize *foo, sub { 6 } => UP [not yet]';
 }
 is foo(), 6, 'localize *foo, sub { 6 } => UP [ok]';
}

{
 local *foo = sub { 9 };
 {
  localize '&foo', sub { 8 } => UP;
  is foo(), 9, 'localize "&foo", sub { 8 } => UP [not yet]';
 }
 is foo(), 8, 'localize "&foo", sub { 8 } => UP [ok]';
}

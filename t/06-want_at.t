#!perl -T

use strict;
use warnings;

use Test::More tests => 19;

use Scope::Upper qw/want_at/;

sub check {
 my ($w, $exp, $desc) = @_;
 my $cx = sub {
  my $a = shift;
  if (!defined $a) {
   return 'void';
  } elsif ($a) {
   return 'list';
  } else {
   return 'scalar';
  }
 };
 is $cx->($w), $cx->($exp), $desc;
}

my $w;

check want_at,     undef, 'main : want_at';
check want_at(0),  undef, 'main : want_at(0)';
check want_at(1),  undef, 'main : want_at(1)';
check want_at(-1), undef, 'main : want_at(-1)';

my @a = sub {
 check want_at, 1, 'sub0 : want_at';
 {
  check want_at,    1, 'sub : want_at';
  check want_at(1), 1, 'sub : want_at(1)';
  for (1) {
   check want_at,    1, 'for : want_at';
   check want_at(1), 1, 'for : want_at(1)';
   check want_at(2), 1, 'for : want_at(2)';
  }
  eval "
   check want_at,    undef, 'eval string : want_at';
   check want_at(1), 1,     'eval string : want_at(1)';
   check want_at(2), 1,     'eval string : want_at(2)';
  ";
  my $x = eval {
   do {
    check want_at,    0, 'do : want_at';
    check want_at(1), 0, 'do : want_at(0)';
    check want_at(2), 1, 'do : want_at(1)';
   };
   check want_at,    0, 'eval : want_at';
   check want_at(1), 1, 'eval : want_at(0)';
   check want_at(2), 1, 'eval : want_at(1)';
  };
 }
}->();

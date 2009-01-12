#!perl -T

use strict;
use warnings;

use Test::More 'no_plan';

use Scope::Upper qw/unwind/;

our ($call, @args, $args);

$call = sub {
 my ($height, $level, $i) = @_;
 return [ [ "unwind(\@args => $level)\n", '' ] ];
};

sub list { @_ }

my @blocks = (
 [ 'sub {',     '}->()' ],
 [ 'eval {',    '}' ],
);

my @contexts = (
 [ '',        '; ()' ],
 [ 'scalar(', ')' ],
 [ 'list(',   ')' ],
);

@blocks   = map [ map "$_\n", @$_ ], @blocks;
@contexts = map [ map "$_\n", @$_ ], @contexts;

sub gen {
 my ($height, $level, $i) = @_;
 push @_, $i = 0 if @_ == 2;
 my @res;
 my $up = $i == $height + 1 ? $call->(@_) : gen($height, $level, $i + 1);
 if ($i + $level == $height + 1) {
  for (@$up) {
   $_->[1] = "return($args)\n";
  }
 }
 for my $base (@$up) {
  my ($code, $exp) = @$base;
  for my $blk (@blocks) {
   for my $cx (@contexts) {
    push @res, [
     $blk->[0] . $cx->[0] . $code . $cx->[1] . $blk->[1],
     $blk->[0] . $cx->[0] . $exp .  $cx->[1] . $blk->[1],
    ];
    my $list = join ', ', map { int rand 10 } 0 .. rand 3;
    push @res, [
     $blk->[0] . $cx->[0] . "($list, " . $code . ')' . $cx->[1] . $blk->[1],
     $blk->[0] . $cx->[0] . "($list, " . $exp .  ')' . $cx->[1] . $blk->[1],
    ];
   }
  }
 }
 return \@res;
}

sub runtests {
 my $tests = gen @_;
 for (@$tests) {
  no warnings 'void';
  my @res = eval $_->[0];
  my @exp = eval $_->[1] unless $@;
  if ($@ || !is_deeply \@res, \@exp) {
   diag "=== vvv Test vvv ===";
   diag $_->[0];
   diag "------- Got --------";
   diag join(', ', map { defined($_) ? $_ : '(undef)' } @res);
   diag "----- Expected -----";
   diag join(', ', map { defined($_) ? $_ : '(undef)' } @exp);
   diag "=== ^^^^^^^^^^^^ ===";
  }
 }
}

for ([ ], [ 'A' ], [ qw/B C/ ]) {
 @args = @$_;
 $args = '(' . join(', ', map "'$_'", @args) . ')';
 runtests 0, 0;
 runtests 0, 1;
 runtests 1, 0;
 runtests 1, 1;
}

#!perl -T

use strict;
use warnings;

use Test::More 'no_plan'; 

use Scope::Upper qw/localize UP HERE/;

use lib 't/lib';
use Scope::Upper::TestGenerator;

local $Scope::Upper::TestGenerator::call = sub {
 my ($height, $level, $i) = @_;
 $level = $level ? 'UP ' x $level : 'HERE';
 return [ "localize '\$x' => 0 => $level;\n" ];
};

local $Scope::Upper::TestGenerator::test = sub {
 my ($height, $level, $i, $x) = @_;
 my $j = ($i == $height - $level) ? 0 : (defined $x ? $x : 'undef');
 return "is(\$x, $j, 'x h=$height, l=$level, i=$i');\n";
};

local $Scope::Upper::TestGenerator::testlocal = sub { '' };

local $Scope::Upper::TestGenerator::allblocks = 1;

our ($x, $testcase);

{
 no warnings 'redefine';
 *is = sub ($$;$) {
  my ($a, $b, $desc) = @_;
  if (defined $testcase
      and (defined $b) ? (not defined $a or $a != $b) : defined $a) {
   diag <<DIAG;
=== This testcase failed ===
$testcase
==== vvvvv Errors vvvvvv ===
DIAG
   undef $testcase;
  }
  Test::More::is($a, $b, $desc);
 }
}

for my $level (0 .. 1) {
 my $height = $level + 1;
 my $tests = Scope::Upper::TestGenerator::gen($height, $level);
 for (@$tests) {
  $testcase = $_;
  $x = undef;
  eval;
  diag $@ if $@;
 }
}

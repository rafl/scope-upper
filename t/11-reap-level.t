#!perl -T

use strict;
use warnings;

use Test::More 'no_plan'; 

use Scope::Upper qw/reap/;

use lib 't/lib';
use Scope::Upper::TestGenerator;

local $Scope::Upper::TestGenerator::call = sub {
 my ($height, $level, $i) = @_;
 return [ "reap \\&check => $level;\n" ];
};

local $Scope::Upper::TestGenerator::test = sub {
 my ($height, $level, $i) = @_;
 my $j = $i < $height - $level ? 1 : 'undef';
 return "is(\$main::y, $j, 'y h=$height, l=$level, i=$i');\n";
};

our ($x, $y, $testcase);

sub check { $y = 0 unless defined $y; ++$y }

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

for my $level (0 .. 4) {
 for my $height ($level + 1 .. $level + 2) {
  my $tests = Scope::Upper::TestGenerator::gen($height, $level);
  for (@$tests) {
   $testcase = $_;
   $x = $y = undef;
   eval;
   diag $@ if $@;
  }
 }
}

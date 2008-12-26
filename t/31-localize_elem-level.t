#!perl -T

use strict;
use warnings;

use Test::More 'no_plan'; 

use Scope::Upper qw/localize_elem/;

use lib 't/lib';
use Scope::Upper::TestGenerator;

our ($x, $testcase);

local $Scope::Upper::TestGenerator::call = sub {
 my ($height, $level, $i) = @_;
 return [ "localize_elem '\@main::a', 1 => 3 => $level;\n" ];
};

local $Scope::Upper::TestGenerator::test = sub {
 my ($height, $level, $i) = @_;
 my $j = ($i == $height - $level) ? '1, 3' : '1, 2';
 return "is_deeply(\\\@main::a, [ $j ], 'a h=$height, l=$level, i=$i');\n";
};

our @a;

for my $level (0 .. 4) {
 for my $height ($level + 1 .. $level + 2) {
  my $tests = Scope::Upper::TestGenerator::gen($height, $level);
  for (@$tests) {
   $testcase = $_;
   $x = undef;
   @a = (1, 2);
   eval;
   diag $@ if $@;
  }
 }
}

local $Scope::Upper::TestGenerator::call = sub {
 my ($height, $level, $i) = @_;
 return [ "localize_elem '%main::h', 'a' => 1 => $level;\n" ];
}; 

local $Scope::Upper::TestGenerator::test = sub {
 my ($height, $level, $i) = @_;
 my $j = ($i == $height - $level) ? 'a => 1' : '';
 return "is_deeply(\\%main::h, { $j }, 'h h=$height, l=$level, i=$i');\n";
};

our %h;

for my $level (0 .. 4) {
 for my $height ($level + 1 .. $level + 2) {
  my $tests = Scope::Upper::TestGenerator::gen($height, $level);
  for (@$tests) {
   $testcase = $_;
   $x = undef;
   %h = ();
   eval;
   diag $@ if $@;
  }
 }
}

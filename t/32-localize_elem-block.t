#!perl -T

use strict;
use warnings;

use Test::More 'no_plan'; 

use Scope::Upper qw/localize_elem/;

use lib 't/lib';
use Scope::Upper::TestGenerator;

local $Scope::Upper::TestGenerator::testlocal = sub { '' };

local $Scope::Upper::TestGenerator::allblocks = 1;

our $testcase;

local $Scope::Upper::TestGenerator::call = sub {
 my ($height, $level, $i) = @_;
 return [ "localize_elem '\@a', 1 => 0 => $level;\n" ];
};

local $Scope::Upper::TestGenerator::test = sub {
 my ($height, $level, $i, $x) = @_;
 my $j = ($i == $height - $level) ? 0 : (defined $x ? $x : 11);
 return "is(\$a[1], $j, 'x h=$height, l=$level, i=$i');\n";
};

local $Scope::Upper::TestGenerator::local = sub {
 my $x = $_[3];
 return "local \$a[1] = $x;\n";
};

our @a;

for my $level (0 .. 1) {
 my $height = $level + 1;
 my $tests = Scope::Upper::TestGenerator::gen($height, $level);
 for (@$tests) {
  $testcase = $_;
  @a = (10, 11);
  eval;
  diag $@ if $@;
 }
}

local $Scope::Upper::TestGenerator::call = sub {
 my ($height, $level, $i) = @_;
 return [ "localize_elem '%h', 'a' => 0 => $level;\n" ];
};

local $Scope::Upper::TestGenerator::test = sub {
 my ($height, $level, $i, $x) = @_;
 my $j = ($i == $height - $level) ? 0 : (defined $x ? $x : 'undef');
 return "is(\$h{a}, $j, 'x h=$height, l=$level, i=$i');\n";
};

local $Scope::Upper::TestGenerator::local = sub {
 my $x = $_[3];
 return "local \$h{a} = $x;\n";
};

our %h;

for my $level (0 .. 1) {
 my $height = $level + 1;
 my $tests = Scope::Upper::TestGenerator::gen($height, $level);
 for (@$tests) {
  $testcase = $_;
  %h = ();
  eval;
  diag $@ if $@;
 }
}

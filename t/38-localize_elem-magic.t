#!perl

use strict;
use warnings;

use Scope::Upper qw/localize_elem/;

use Test::More tests => 6;

our $x;

{
 local $x;
 local $SIG{__WARN__} = sub { };
 {
  {
   localize_elem '%SIG', '__WARN__' => sub { $x = join '', @_ }, 1;
   is $x, undef, 'localize_elem $SIG{__WARN__} [not yet]';
  }
  warn "1\n";
  is $x, "1\n", 'localize_elem $SIG{__WARN__} [ok]';
 }
 warn "2\n";
 is $x, "1\n", 'localize_elem $SIG{__WARN__} [done]';
}

sub runperl {
 my ($val, $in, $desc) = @_;
 system { $^X } $^X, '-e', "exit(\$ENV{SCOPE_UPPER_TEST} == $val ? 0 : 1)";
SKIP: {
  skip "system() failed: $!" => 1 if $? == -1;
  if ($in) {
   is $?, 0, $desc;
  } else {
   isnt $?, 0, $desc;
  }
 }
}

eval "setpgrp 0, 0";

my $time = time;
{
 local $ENV{SCOPE_UPPER_TEST};
 {
  {
   localize_elem '%ENV', 'SCOPE_UPPER_TEST' => $time, 1;
   runperl $time, 0, 'localize_elem $ENV{SCOPE_UPPER_TEST} [not yet]';
  }
  runperl $time, 1, 'localize_elem $ENV{SCOPE_UPPER_TEST} [ok]';
 }
 runperl $time, 0, 'localize_elem $ENV{SCOPE_UPPER_TEST} [done]';
}

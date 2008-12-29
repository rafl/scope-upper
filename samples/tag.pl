#!perl

package X;

use strict;
use warnings;

use blib;

use Scope::Upper qw/reap localize localize_elem localize_delete/;

sub desc { shift->{desc} }

sub set_tag {
 my ($desc) = @_;

 # First localize $x so that it gets destroyed last
 localize '$x' => bless({ desc => $desc }, __PACKAGE__) => 1;

 reap sub {
  my $pkg = caller;
  my $x = do { no strict 'refs'; ${$pkg.'::x'} }; # Get the $x in the scope
  print $x->desc . ": done\n";
 } => 1;

 localize_elem '%SIG', '__WARN__' => sub {
  my $pkg = caller;
  my $x = do { no strict 'refs'; ${$pkg.'::x'} }; # Get the $x in the scope
  CORE::warn($x->desc . ': ' . join('', @_));
 } => 1;

 localize_delete '@ARGV', $#ARGV => 1; # delete last @ARGV element
}

package main;

use strict;
use warnings;

{
 X::set_tag('pie');
 # $x is now a X object, and @ARGV has one element less
 warn 'what'; # warns "pie: what at ..."
} # "pie: done" is printed

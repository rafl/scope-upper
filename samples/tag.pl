#!perl

package X;

use strict;
use warnings;

use blib;

use Scope::Upper qw/reap localize localize_elem localize_delete :words/;

die 'run this script with some arguments!' unless @ARGV;

sub desc { shift->{desc} }

sub set_tag {
 my ($desc) = @_;

 # First localize $x so that it gets destroyed last
 localize '$x' => bless({ desc => $desc }, __PACKAGE__) => UP;

 reap sub {
  my $pkg = caller;
  my $x = do { no strict 'refs'; ${$pkg.'::x'} }; # Get the $x in the scope
  print $x->desc . ": done\n";
 } => SCOPE 1; # same as UP here

 localize_elem '%SIG', '__WARN__' => sub {
  my $pkg = caller;
  my $x = do { no strict 'refs'; ${$pkg.'::x'} }; # Get the $x in the scope
  CORE::warn($x->desc . ': ' . join('', @_));
 } => UP CALLER 0; # same as UP here

 # delete last @ARGV element
 localize_delete '@ARGV', -1 => UP SUB HERE; # same as UP here
}

package main;

use strict;
use warnings;

{
 X::set_tag('pie');
 # $x is now a X object, and @ARGV has one element less
 warn 'what'; # warns "pie: what at ..."
 warn "\@ARGV contains [@ARGV]";
} # "pie: done" is printed

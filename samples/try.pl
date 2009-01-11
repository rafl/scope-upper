#!perl

use strict;
use warnings;

use blib;

use Scope::Upper qw/unwind want_at :words/;

sub try (&) {
 my @result = shift->();
 my $cx = SUB UP SUB;
 unwind +(want_at($cx) ? @result : scalar @result) => $cx;
}

sub zap {
 try {
  my @things = qw/a b c/;
  return @things; # returns to try() and then outside zap()
 };
 print "NOT REACHED\n";
}

my @what = zap(); # @what contains @things
my $what = zap(); # @what contains @things

print "zap() returns @what in list context and $what in scalar context\n";

package Scope::Upper::TestGenerator;

use strict;
use warnings;

our ($call, $test, $local, $testlocal, $allblocks);

$local = sub {
 my $x = $_[3];
 return "local \$x = $x;\n";
};

$testlocal = sub {
 my ($height, $level, $i, $x) = @_;
 my $j = defined $x ? $x : 'undef';
 return "is(\$x, $j, 'x h=$height, l=$level, i=$i');\n";
};

my @blocks = (
 [ '{',         '}' ],
 [ 'sub {',     '}->();' ],
 [ 'do {',      '};' ],
 [ 'eval {',    '};' ],
 [ 'for (1) {', '}' ],
 [ 'eval q[',   '];' ],
);

@blocks = map [ map "$_\n", @$_ ], @blocks;

sub _block {
 my ($height, $level, $i) = @_;
 my $j = $height - $i;
 $j = 0 if $j > $#blocks or $j < 0;
 return [ map "$_\n", @{$blocks[$j]} ];
}

sub gen {
 my ($height, $level, $i, $x) = @_;
 push @_, $i = 0 if @_ == 2;
 return $call->(@_) if $height < $i;
 my @res;
 my @blks = $allblocks ? @blocks : _block(@_);
 my $up   = gen($height, $level, $i + 1, $x);
 for my $base (@$up) {
  for my $blk (@blks) {
   push @res, $blk->[0] . $base . $test->(@_) . $testlocal->(@_) . $blk->[1];
  }
 }
 $_[3] = $i + 1;
 $up = gen($height, $level, $i + 1, $i + 1);
 for my $base (@$up) {
  for my $blk (@blks) {
   push @res, $blk->[0] .
               $local->(@_) . $base . $test->(@_) . $testlocal->(@_)
              . $blk->[1];
  }
 }
 return \@res;
}

1;

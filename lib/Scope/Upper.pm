package Scope::Upper;

use strict;
use warnings;

=head1 NAME

Scope::Upper - Act on upper scopes.

=head1 VERSION

Version 0.03

=cut

our $VERSION;
BEGIN {
 $VERSION = '0.03';
}

=head1 SYNOPSIS

    package X;

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

    package Y;

    {
     X::set_tag('pie');
     # $x is now a X object, and @ARGV has one element less
     warn 'what'; # warns "pie: what at ..."
     ...
    } # "pie: done" is printed

=head1 DESCRIPTION

This module lets you defer actions that will take place when the control flow returns into an upper scope.
Currently, you can hook an upper scope end, or localize variables, array/hash values or deletions of elements in higher contexts.

=head1 FUNCTIONS

=cut

BEGIN {
 require XSLoader;
 XSLoader::load(__PACKAGE__, $VERSION);
}

=head2 C<reap $callback, $level>

Add a destructor that calls C<$callback> when the C<$level>-th upper scope ends, where C<0> corresponds to the current scope.

=head2 C<localize $what, $value, $level>

A C<local> delayed to the time of first return into the C<$level>-th upper scope.
C<$what> can be :

=over 4

=item *

A glob, in which case C<$value> can either be a glob or a reference.
L</localize> follows then the same syntax as C<local *x = $value>.
For example, if C<$value> is a scalar reference, then the C<SCALAR> slot of the glob will be set to C<$$value> - just like C<local *x = \1> sets C<$x> to C<1>.

=item *

A string beginning with a sigil, representing the symbol to localize and to assign to.
If the sigil is C<'$'>, L</localize> follows the same syntax as C<local $x = $value>, i.e. C<$value> isn't dereferenced.
For example,

    localize '$x', \'foo' => 0;

will set C<$x> to a reference to the string C<'foo'>.
Other sigils (C<'@'>, C<'%'>, C<'&'> and C<'*'>) require C<$value> to be a reference of the corresponding type.

When the symbol is given by a string, it is resolved when the actual localization takes place and not when C<localize> is called.
This means that

    sub tag { localize '$x', $_[0] => 1; }

will localize in the caller's namespace.

=back

=head2 C<localize_elem $what, $key, $value, $level>

Similar to L</localize> but for array and hash elements.
If C<$what> is a glob, the slot to fill is determined from which type of reference C<$value> is ; otherwise it's inferred from the sigil.
C<$key> is either an array index or a hash key, depending of which kind of variable you localize.

=head2 C<localize_delete $what, $key, $level>

Similiar to L</localize>, but for deleting variables or array/hash elements.
C<$what> can be:

=over 4

=item *

A glob, in which case C<$key> is ignored and the call is equivalent to C<local *x>.

=item *

A string beginning with C<'@'> or C<'%'>, for which the call is equivalent to respectiveley C<local $a[$key]; delete $a[$key]> and C<local $h{$key}; delete $h{$key}>.

=item *

A string beginning with C<'&'>, which more or less does C<undef &func> in the upper scope.
It's actually more powerful, as C<&func> won't even C<exists> anymore.
C<$key> is ignored.

=back

=head2 C<TOPLEVEL>

Returns the level that currently represents the highest scope.

=head1 EXPORT

The functions L</reap>, L</localize>, L</localize_elem>, L</localize_delete> and L</TOPLEVEL> are only exported on request, either individually or by the tags C<':funcs'> and C<':all'>.

=cut

use base qw/Exporter/;

our @EXPORT      = ();
our %EXPORT_TAGS = (
 funcs => [ qw/reap localize localize_elem localize_delete TOPLEVEL/ ],
);
our @EXPORT_OK   = map { @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = [ @EXPORT_OK ];

=head1 CAVEATS

Be careful that local variables are restored in the reverse order in which they were localized.
Consider those examples:

    local $x = 0;
    {
     reap sub { print $x } => 0;
     local $x = 1;
     ...
    }
    # prints '0'
    ...
    {
     local $x = 1;
     reap sub { $x = 2 } => 0;
     ...
    }
    # $x is 0

The first case is "solved" by moving the C<local> before the C<reap>, and the second by using L</localize> instead of L</reap>.

L</reap>, L</localize> and L</localize_elem> effects can't cross C<BEGIN> blocks, hence calling those functions in C<import> is deemed to be useless.
This is an hopeless case because C<BEGIN> blocks are executed once while localizing constructs should do their job at each run.

=head1 DEPENDENCIES

L<XSLoader> (standard since perl 5.006).

=head1 SEE ALSO

L<Alias>, L<Hook::Scope>, L<Scope::Guard>, L<Guard>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-scope-upper at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Scope-Upper>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Scope::Upper

Tests code coverage report is available at L<http://www.profvince.com/perl/cover/Scope-Upper>.

=head1 ACKNOWLEDGEMENTS

Inspired by Ricardo Signes.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Scope::Upper

package Scope::Upper;

use strict;
use warnings;

=head1 NAME

Scope::Upper - Act on upper scopes.

=head1 VERSION

Version 0.06

=cut

our $VERSION;
BEGIN {
 $VERSION = '0.06';
}

=head1 SYNOPSIS

    package X;

    use Scope::Upper qw/reap localize localize_elem localize_delete :words/;

    sub desc { shift->{desc} }

    sub set_tag {
     my ($desc) = @_;

     # First localize $x so that it gets destroyed last
     localize '$x' => bless({ desc => $desc }, __PACKAGE__) => UP; # one scope up

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

    package Y;

    {
     X::set_tag('pie');
     # $x is now a X object, and @ARGV has one element less
     warn 'what'; # warns "pie: what at ..."
     ...
    } # "pie: done" is printed

    package Z;

    use Scope::Upper qw/unwind want_at :words/;

    sub try (&) {
     my @result = shift->();
     my $cx = SUB UP SUB;
     unwind +(want_at($cx) ? @result : scalar @result) => $cx;
    }

    ...

    sub zap {
     try {
      return @things; # returns to try() and then outside zap()
     }
    }

    my @what = zap(); # @what contains @things

=head1 DESCRIPTION

This module lets you defer actions that will take place when the control flow returns into an upper scope.
Currently, you can hook an upper scope end, or localize variables, array/hash values or deletions of elements in higher contexts.
You can also return to an upper level and know which context was in use then.

=head1 FUNCTIONS

In all those functions, C<$context> refers to the target scope.

You have to use one or a combination of L</WORDS> to build the C<$context> to pass to these functions.
This is needed in order to ensure that the module still works when your program is ran in the debugger.
Don't try to use a raw value or things will get messy.

The only thing you can assume is that it is an I<absolute> indicator of the frame.
This means that you can safely store it at some point and use it when needed, and it will still denote the original scope.

=cut

BEGIN {
 require XSLoader;
 XSLoader::load(__PACKAGE__, $VERSION);
}

=head2 C<reap $callback, $context>

Add a destructor that calls C<$callback> when the upper scope represented by C<$context> ends.

=head2 C<localize $what, $value, $context>

A C<local> delayed to the time of first return into the upper scope denoted by C<$context>.
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

    localize '$x', \'foo' => HERE;

will set C<$x> to a reference to the string C<'foo'>.
Other sigils (C<'@'>, C<'%'>, C<'&'> and C<'*'>) require C<$value> to be a reference of the corresponding type.

When the symbol is given by a string, it is resolved when the actual localization takes place and not when C<localize> is called.
This means that

    sub tag { localize '$x', $_[0] => UP }

will localize in the caller's namespace.

=back

=head2 C<localize_elem $what, $key, $value, $context>

Similar to L</localize> but for array and hash elements.
If C<$what> is a glob, the slot to fill is determined from which type of reference C<$value> is ; otherwise it's inferred from the sigil.
C<$key> is either an array index or a hash key, depending of which kind of variable you localize.

=head2 C<localize_delete $what, $key, $context>

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

=head2 C<unwind @values, $context>

Returns C<@values> I<from> the context pointed by C<$context>, i.e. from the subroutine, eval or format just above C<$context>.

The upper context isn't coerced onto C<@values>, which is hence always evaluated in list context.
This means that

    my $num = sub {
     my @a = ('a' .. 'z');
     unwind @a => HERE;
    }->();

will set C<$num> to C<'z'>.
You can use L</want_at> to handle these cases.

=head2 C<want_at $context>

Like C<wantarray>, but for the subroutine/eval/format just above C<$context>.

The previous example can then be "corrected" :

    my $num = sub {
     my @a = ('a' .. 'z');
     unwind +(want_at(HERE) ? @a : scalar @a) => HERE;
    }->();

will righteously set C<$num> to C<26>.

=head1 WORDS

=head2 Constants

=head3 C<TOP>

Returns the context that currently represents the highest scope.

=head3 C<HERE>

The context of the current scope.

=head2 Getting a context from a context

For any of those functions, C<$from> is expected to be a context.
When omitted, it defaults to the the current context.

=head3 C<UP $from>

The context of the scope just above C<$from>.

=head3 C<SUB $from>

The context of the closest subroutine above C<$from>.

=head3 C<EVAL $from>

The context of the closest eval above C<$from>.

=head2 Getting a context from a level

Here, C<$level> should denote a number of scopes above the current one.
When omitted, it defaults to C<0> and those functions return the same context as L</HERE>.

=head3 C<SCOPE $level>

The C<$level>-th upper context, regardless of its type.

=head3 C<CALLER $level>

The context of the C<$level>-th upper subroutine/eval/format.
It kind of corresponds to the context represented by C<caller $level>, but while e.g. C<caller 0> refers to the caller context, C<CALLER 0> will refer to the top scope in the current context.

=head1 EXPORT

The functions L</reap>, L</localize>, L</localize_elem>, L</localize_delete>,  L</unwind> and L</want_at> are only exported on request, either individually or by the tags C<':funcs'> and C<':all'>.

Same goes for the words L</TOP>, L</HERE>, L</UP>, L</SUB>, L</EVAL>, L</SCOPE> and L</CALLER> that are only exported on request, individually or by the tags C<':words'> and C<':all'>.

=cut

use base qw/Exporter/;

our @EXPORT      = ();
our %EXPORT_TAGS = (
 funcs => [ qw/reap localize localize_elem localize_delete unwind want_at/ ],
 words => [ qw/TOP HERE UP SUB EVAL SCOPE CALLER/ ],
);
our @EXPORT_OK   = map { @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = [ @EXPORT_OK ];

=head1 CAVEATS

Be careful that local variables are restored in the reverse order in which they were localized.
Consider those examples:

    local $x = 0;
    {
     reap sub { print $x } => HERE;
     local $x = 1;
     ...
    }
    # prints '0'
    ...
    {
     local $x = 1;
     reap sub { $x = 2 } => HERE;
     ...
    }
    # $x is 0

The first case is "solved" by moving the C<local> before the C<reap>, and the second by using L</localize> instead of L</reap>.

L</reap>, L</localize> and L</localize_elem> effects can't cross C<BEGIN> blocks, hence calling those functions in C<import> is deemed to be useless.
This is an hopeless case because C<BEGIN> blocks are executed once while localizing constructs should do their job at each run.

Some rare oddities may still happen when running inside the debugger.
It may help to use a perl higher than 5.8.9 or 5.10.0, as they contain some context fixes.

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

Thanks to Shawn M. Moore for motivation.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Scope::Upper

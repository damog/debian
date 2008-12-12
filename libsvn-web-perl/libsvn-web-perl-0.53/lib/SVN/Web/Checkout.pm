package SVN::Web::Checkout;

use strict;
use warnings;

use base 'SVN::Web::action';

use SVN::Web::X;

our $VERSION = 0.53;

=head1 NAME

SVN::Web::Checkout - SVN::Web action to checkout a given file

=head1 SYNOPSIS

In F<config.yaml>

  actions:
    ...
    checkout:
      class: SVN::Web::Checkout
      action_menu:
        show:
          - file
        link_text: (checkout)
    ...

=head1 DESCRIPTION

Returns the contents of the given filename.  Uses the C<svn:mime-type>
property.

=head1 OPTIONS

=over 4

=item rev

The repository revision to checkout.  Defaults to the repository's youngest
revision.

=back

=head1 TEMPLATE VARIABLES

N/A

=head1 EXCEPTIONS

=over 4

=item (path %1 is not a file in revision %2)

The given path is not a file in the given revision.

=back

=cut

sub run {
    my $self = shift;
    my $ctx  = $self->{repos}{client};
    my $ra   = $self->{repos}{ra};
    my $uri  = $self->{repos}{uri};
    my $rev  = $self->{cgi}->param('rev') || $ra->get_latest_revnum();
    my $path = $self->{path};

    my $node_kind;
    $ctx->info("$uri$path", $rev, $rev,
	       sub { $node_kind = $_[1]->kind(); }, 0);

    if($node_kind != $SVN::Node::file) {
        SVN::Web::X->throw(
            error => '(path %1 is not a file in revision %2)',
            vars  => [$path, $rev]
        );
    }

    my($fh, $fc) = (undef, '');
    open($fh, '>', \$fc);
    $ctx->cat($fh, $uri . $path, $rev);
    close($fh);

    my $mime_type;
    my $props = $ctx->propget('svn:mime-type', $uri . $path, $rev, 0);
    if(exists $props->{$uri . $path}) {
	$mime_type = $props->{$uri . $path};
    } else {
	$mime_type = 'text/plain';
    }

    return {
        mimetype => $mime_type,
        body => $fc,
    };
}

1;

=head1 COPYRIGHT

Copyright 2003-2004 by Chia-liang Kao C<< <clkao@clkao.org> >>.

Copyright 2005-2007 by Nik Clayton C<< <nik@FreeBSD.org> >>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

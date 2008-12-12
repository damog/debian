package SVN::Web::List;

use strict;
use warnings;

use base 'SVN::Web::action';

use File::Basename ();

our $VERSION = 0.53;

=head1 NAME

SVN::Web::List - SVN::Web action to list available repositories

=head1 SYNOPSIS

In F<config.yaml>

  actions:
    ...
    list:
      class: SVN::Web::List
      opts:
        redirect_to_browse_when_one_repo: 0 # or 1
    ...

=head1 DESCRIPTION

Displays a list of available Subversion repositories for browsing.  If only
one repo is available then may redirect straight to it.

=head1 CONFIGURATION

The following options may be specified in F<config.yaml>

=over

=item redirect_to_browse_when_one_repo

Boolean indicating whether, if only one repository is available, SVN::Web::List
should immediately issue a redirect to browse that repository, thereby saving
the user a mouse click.

Defaults to 0.

=back

=head1 TEMPLATE VARIABLES

=over 8

=item reposcount

The number of repositories that were configured.

=item repos

A hash.  Keys are repository names, paths are repository URLs.

=back

=head1 EXCEPTIONS

None.

=cut

my %default_opts = (redirect_to_browse_when_one_repo => 0);

sub run {
    my $self = shift;

    $self->{opts} = { %default_opts, %{ $self->{opts} } };

    my %repos = repos_list($self->{config});

    # If there's only one repo listed then jump straight to it
    if(keys %repos == 1 and $self->{opts}{redirect_to_browse_when_one_repo}) {
        my $url = $self->{cgi}->self_url();
        $url =~ s{/$}{};
        $url .= '/' . (keys %repos)[0];
        print $self->{cgi}->redirect(-uri => $url);
        return;
    }

    return {
        template => 'list',
        data     => {
            action     => 'list',
            nonav      => 1,
            repos      => \%repos,
            reposcount => scalar keys %repos
        }
    };
}

sub repos_list {
    my $config = shift;

    my %repos;
    if($config->{reposparent}) {
        opendir my $dh, "$config->{reposparent}"
            or SVN::Web::X->throw(
            error => '(opendir reposparent %1 %2)',
            vars  => [$config->{reposparent}, $!]
            );

        foreach my $dir (grep { -d File::Spec->catdir($config->{reposparent}, $_) && !/^\./ }
            readdir $dh) {
	    $repos{$dir} = 'file://' . File::Spec->catdir($config->{reposparent}, $dir);
        }
    } else {
	%repos = %{ $config->{repos} };
    }

    delete @repos{ @{ $config->{block} } } if exists $config->{block};

    return %repos;
}

1;

=head1 COPYRIGHT

Copyright 2003-2004 by Chia-liang Kao C<< <clkao@clkao.org> >>.

Copyright 2005-2007 by Nik Clayton C<< <nik@FreeBSD.org> >>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

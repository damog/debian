
=head1 NAME

SVN::Web::Test - automated web testing for SVN::Web

=head1 DESCRIPTION


=cut

package SVN::Web::Test;

use strict;
use warnings;

our $VERSION = 0.53;

use File::Path;
use File::Spec;
use File::Temp qw(tempdir);
use POSIX ();
use IO::Socket::INET;

use Test::More;
use Test::WWW::Mechanize;

use SVN::Web;
use YAML ();

# CGI.pm does not reinitialise itself from the environment when multiple
# objects are created.  This is a problem when testing, as the tests pass
# in different QUERY_STRING variables.  C<< use CGI >> and increment
# $CGI::PERLEX, which is an internal CGI.pm flag that turns off this
# behaviour.
use CGI;
$CGI::PERLEX++;

my $uri_base;
my $script;
my $fake_cgi = 0;

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    %$self = @_;

    my @mech_args = exists $self->{mech_args} ? $self->{mech_args} : ();

    $self->{_mech} =
      exists $self->{httpd_port} ? Test::WWW::Mechanize->new(@mech_args)
	                         : SVN::Web::Test::Mechanize->new(@mech_args);

    if(! exists $self->{root_url}) {
	if(exists $self->{httpd_port}) {
	    $self->{root_url} = "http://localhost:$self->{httpd_port}/svnweb";
	} else {
	    $self->{root_url} = "http://localhost/svnweb";
	}
    }

    $self->{repo_path} = File::Spec->rel2abs($self->{repo_path});
    $self->{repo_dump} = File::Spec->rel2abs($self->{repo_dump});

    $self->create_env();
    $self->create_install();

    return $self;
}

# Returns the Test::WWW::Mechanize object
sub mech {
    return shift->{_mech};
}

sub install_dir {
    return shift->{install_dir};
}

sub site_root {
    return shift->{root_url};
}

sub set_config {
    my $self = shift;
    my $opts = shift;

    $uri_base = $opts->{uri_base};
    $script   = $opts->{script};
    $fake_cgi = 1;

    my $config = {
	version => $VERSION,
        actions => {
	    'browse' => {
		'class' => 'SVN::Web::Browse',
		'action_menu' => {
		    'show' => [ 'directory' ],
		    'link_text' => '(browse directory)'
		}
	    },
	    'blame' => {
		'class' => 'SVN::Web::Blame',
		'action_menu' => {
		    'show' => [ 'file' ],
		    'link_text' => '(view blame)'
		}
	    },
	    'checkout' => {
		'class' => 'SVN::Web::Checkout',
		'action_menu' => {
		    'show' => [ 'file' ],
		    'link_text' => '(checkout)'
		}
	    },
	    'revision' => {
		'class' => 'SVN::Web::Revision'
	    },
	    'view' => {
		'class' => 'SVN::Web::View',
		'action_menu' => {
		    'show' => [ 'file' ],
		    'link_text' => '(view file)'
		}
	    },
	    'diff' => {
		'class' => 'SVN::Web::Diff'
	    },
	    'log' => {
		'class' => 'SVN::Web::Log',
		'action_menu' => {
		    'show' => [ 'file', 'directory' ],
		    'link_text' => '(view revision log)'
		}
	    },
	    'rss' => {
		'class' => 'SVN::Web::RSS',
		'action_menu' => {
		    'icon' => '/css/trac/feed-icon-16x16.png',
		    'show' => [ 'file', 'directory' ],
		    'head_only' => '1',
		    'link_text' => '(rss)'
		}
	    },
	    'list' => {
		'class' => 'SVN::Web::List'
	    }
        },
        cgi_class    => 'CGI',
        templatedirs => ['lib/SVN/Web/Template/trac'],
	%{$opts->{config}},
    };

    SVN::Web::set_config($config);
}

# Create a Subversion repo from a dump file.
sub create_env {
    my $self = shift;

    plan skip_all => 'Test::WWW::Mechanize not installed'
      unless eval { require Test::WWW::Mechanize; 1; };

    plan skip_all => q{Can't find svnadmin}
      unless `svnadmin --version` =~ /version/;

    rmtree([$self->{repo_path}]) if -d $self->{repo_path};
    $ENV{SVNFSTYPE} ||= (($SVN::Core::VERSION =~ /^1\.0/) ? 'bdb' : 'fsfs');

    `svnadmin create --fs-type=$ENV{SVNFSTYPE} $self->{repo_path}`;
    `svnadmin load $self->{repo_path} < $self->{repo_dump}`;
}

# Create a scratch area, run svnweb-install.  The generated config.yaml
# file will be changed to list the repo created create_env().
#
# Returns the directory in which the scratch area is rooted.
sub create_install {
    my $self = shift;

    $self->{install_dir} = tempdir(CLEANUP => 1);
    warn "Created $self->{install_dir}\n";
    my $cwd = POSIX::getcwd();
    chdir($self->{install_dir});
    my $lib_dir = File::Spec->catdir($cwd, 'blib', 'lib');
    my $svnweb_install = File::Spec->catfile($cwd, 'bin', 'svnweb-install');

    system "$^X -I$lib_dir $svnweb_install";

    # Make the directory world-readable by all.  Otherwise, if Apache is
    # started as root the default behaviour is to set user/group to -1.
    # This results in the directory being unreadable by SVN::Web.
    chmod 0755, $self->{install_dir};

    chdir($cwd);		# Get back to the original directory

    # Change the config to point to the test repo
    my $config_file = File::Spec->catfile($self->{install_dir}, 'config.yaml');
    my $config = YAML::LoadFile($config_file);
    $config->{repos}{repos} = $self->{repo_path};
    YAML::DumpFile($config_file, $config);

    return $self->{install_dir};
}

# Forks and execs the process that will act as the web server.
# Arguments are passed, unchanged, to exec().  Returns the PID of
# the child process
sub start_server {
    my $self = shift;
    my @cmd  = @_;

    # Make sure there's nothing else listening on our chosen port
    my $sock = IO::Socket::INET->new(PeerAddr => 'localhost',
				     PeerPort => $self->{httpd_port},
				     Proto    => 'tcp');
    if(defined $sock) {
	close($sock);
	die "Something else is already listening on port $self->{httpd_port}\n"
    }

    $self->{_pid} = fork();
    die "fork() failed: $!\n" unless defined $self->{_pid};

    if($self->{_pid} == 0) {
	# Set a new process group, so that this, and any children, can be
	# killed by our parent
	POSIX::setpgid(0, $$) or die "setpgid(): $!\n";

	exec @cmd;
	exit;
    }

    # Note the original signal handlers and install our own
    $self->{_sigintr} = $SIG{INT};
    $self->{_sigquit} = $SIG{QUIT};
    $self->{_siggerm} = $SIG{TERM};

    $SIG{INT}  = sub { $self->_sig(@_) };
    $SIG{QUIT} = sub { $self->_sig(@_) };
    $SIG{TERM} = sub { $self->_sig(@_) };

    # The child may take a few seconds to start up.  So wait a second
    # for it to do so, and try and reach the root of the site.  If
    # that doesn't work, lather-rinse-repeat another five times before
    # giving up.
    foreach my $count (1..5) {
	sleep 1;
	last if $self->{_mech}->get($self->{root_url})->code() == 200;
	
	if($count == 5) {
	    kill 15, -$self->{_pid};
	    die "Could not get 200 response from server on port $self->{httpd_port}\n"
	      if $count == 5;
	}
    }

    return $self->{_pid};
}

sub _sig {
    my $self = shift;
    my $sig  = shift;

    if(exists $self->{_pid}) {
	diag "Caught signal $sig, stopping server (pid: $self->{_pid})";
	$self->stop_server();
    }

    # Call the original signal handler
    return $self->{_sigintr} if $sig eq 'INT'  and exists $self->{_sigintr};
    return $self->{_sigquit} if $sig eq 'QUIT' and exists $self->{_sigquit};
    return $self->{_sigterm} if $sig eq 'TERM' and exists $self->{_sigterm};

    return;
}

sub stop_server {
    my $self = shift;
    kill 9, -$self->{_pid};
    wait;
    delete $self->{_pid};
}

# Walk the site
sub walk_site {
    my $self = shift;
    my $test = shift;
    my $seen = shift || {};

    $test->($self);

    my @links = $self->mech()->links();
    for my $i (0 .. $#links) {
        my $link_url = $links[$i]->url_abs;

	diag sprintf "Fetching %d/%d %s (%s)",
	    $i + 1, $#links + 1, $link_url, $links[$i]->text()
		if exists $ENV{TEST_VERBOSE} and $ENV{TEST_VERBOSE};

        next if $seen->{$link_url};
	diag "Skipping $link_url", next
	    if $link_url !~ /(?:localhost|127\.0\.0\.1)/;

        ++$seen->{$link_url};

        $self->mech()->get($link_url);
        $self->walk_site($test, $seen);
        $self->mech()->back;
    }
}

package SVN::Web::Test::Mechanize;

use base qw(Test::WWW::Mechanize);

sub send_request {
    my($self, $request) = @_;

    my $buf = '';
    my $uri = $request->uri;

    my($proto, $hostname) = $uri_base =~ m{(https?)://([^/]+)};
    my $port = $proto eq 'http' ? 80 : 443;

    {
        open my $outfh, '>', \$buf;
        local *STDOUT = $outfh;
        $uri =~ s/^$uri_base$script//;
        $uri =~ s/\?(.*?)(?:#.*)?$//g;
        local $ENV{QUERY_STRING}   = $1 || '';
        local $ENV{PATH_INFO}      = $uri;
        local $ENV{SCRIPT_NAME}    = "$uri_base$script";
        local $ENV{HTTP_HOST}      = "$hostname:$port";
        local $ENV{REQUEST_METHOD} = 'GET';
        SVN::Web::run_cgi();
    }

    my $response = HTTP::Response->new(200);
    my $msg = HTTP::Message->parse($buf);
    $response->header(%{ $msg->headers() });
    $response->content($msg->content());
    $response->request($request);
    $response->header("Client-Date" => HTTP::Date::time2str(time));

    return $response;
}

=head1 AUTHORS

Chia-liang Kao E<lt>clkao@clkao.orgE<gt> and E<lt>nik@cpan.org<gt>.

=head1 COPYRIGHT

Copyright (c) 2005-2007 by Nik Clayton E<lt>nik@cpan.org<gt>.

Copyright (c) 2004 by Chia-liang Kao E<lt>clkao@clkao.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

1;

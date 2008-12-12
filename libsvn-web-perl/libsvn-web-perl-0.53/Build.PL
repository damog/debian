#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use Getopt::Long;

use Module::Build;
use File::Basename;
use Getopt::Long;

use Module::Build;

# $SVN::Core::VERSION is set in a manner that confuses Module::Build, so
# do an explicit version check here.
my $svn_maj = 1;
my $svn_min = 4;	# Need Subversion 1.4.x or above

die << "." unless eval { no warnings 'once'; require SVN::Core; $SVN::Core::VER_MAJOR > $svn_maj or ($SVN::Core::VER_MAJOR == $svn_maj and $SVN::Core::VER_MINOR >= $svn_min); };
===> Warning: SVN::Core is missing or outdated.

Please manually install SVN::Core by compiling Subversion
(version $svn_maj.$svn_min.0 or above) with SWIG/Perl bindings,
and try this installation process again.
.

my $class = Module::Build->subclass(code => <<'EOCODE');
    sub ACTION_code {
        my $self = shift;
	my $rc   = $self->SUPER::ACTION_code(@_);

	warn "Copying additional files\n";

	open(MAN, 'MANIFEST') or die 'Could not open MANIFEST';
	my @files = map { chomp; $_ } 
          grep { $_ =~ m{^lib/SVN/Web/(Style|Template|I18N)} } <MAN>;
        close(MAN);

        $self->copy_if_modified(from => $_, 
                                to   => File::Spec->catfile($self->blib(), $_))
          for map { $self->localize_file_path($_) } @files;

	return $rc;
    }
EOCODE

my %feature     = ();
my %config_data = ();
my %requires    = ('Template'                           => 0,
		   'YAML'                               => 0,
		   'Number::Format'                     => 0,
		   'Template::Plugin::Number::Format'   => 0,
		   'Locale::Maketext'			=> 0,
		   'Locale::Maketext::Lexicon'          => 0,
		   'Exception::Class'                   => 1.22,
		   'List::Util'                         => 0,
		   'URI'                                => 0,
		   'Time::Zone'                         => 0,
		   'Test::WWW::Mechanize'               => 0,
		  );

=head1 NAME

Build.PL

=head1 SYNOPSIS

  perl Build.PL [--run_apache_tests]
                [--apache_path PATH]
                [--apxs_path PATH]
                [--run_apache_cgi_tests]
                [--with_mod_perl]
                [--run_mod_perl_tests]
                [--mod_perl_path PATH]
                [--run_svnweb-server_tests]
                [--httpd_port PORT]
                [--skip_questions]
                [-- --Module::Build options]

=head1 DESCRIPTION

This is the build script for SVN::Web.  Since some of SVN::Web's
functionality is optional, and/or doesn't need to be tested at install
time, it determines the correct set of pre-requisite modules prior to
install, and obtains some information from the user that is needed by the
automated tests.

The options are:

=over

=item --run_apache_tests

Whether to run post-build tests that require Apache.  Use
C<--norun_apache_tests> to disable.

=item --apache_path PATH

The full path to the Apache httpd binary.

=item --apxs_path PATH

The full path to the Apache apxs binary.

=item --run_apache_cgi_tests

Whether to run post-build tests that SVN::Web as a CGI script with Apache.
Use C<--norun_apache_cgi_tests> to disable.

=item --with_mod_perl

Whether SVN::Web will be used under mod_perl.  Use C<--nowith_mod_perl> to
disable.

=item --run_mod_perl_tests

Whether to run post-build tests that use SVN::Web as a mod_perl handler.
Use C<--norun_mod_perl_tests> to disable.

=item --mod_perl_path PATH

The full path to the mod_perl shared object file (typically called
F<mod_perl.so> or F<libperl.so>.

=item --run_svnweb-server_tests

Whether to run post-build tests for SVN::Web's simple web server.  Use
C<--norun_svnweb-server_tests> to disable.

=item --httpd_port PORT

Specify the PORT that the Apache and svnweb-server tests should use.

=item --skip_questions

Take the command line options as read, and don't ask the user any questions
before creating the build script.

=back

You may also provide all the usual options that L<Module::Build> supports.
However, these options should appear after the options described
previously, and should be preceeded by C<-->.

=cut

my $skip_questions = 0;

GetOptions('with_mod_perl'           => sub { $requires{'Apache::Request'} = 0; },
	   'run_apache_tests'        => \$feature{run_apache_tests},
	   'apache_path=s'           => \$config_data{apache_path},
	   'apxs_path=s'             => \$config_data{apxs_path},
	   'run_apache_cgi_tests'    => \$feature{run_apache_cgi_tests},
	   'run_mod_perl_tests'      => \$feature{run_mod_perl_tests},
	   'mod_perl_path=s'         => \$config_data{mod_perl_path},
	   'run_svnweb-server_tests' => \$feature{'run_svnweb-server_tests'},
	   'httpd_port=i'            => \$config_data{httpd_port},
	   'skip_questions'          => \$skip_questions,
	  );


goto build if $skip_questions;

# ------------------------------------------------------------------------

print <<EOM;

Welcome to SVN::Web.  The installer will now ask you a few questions to
make sure that the list of modules that SVN::Web requires is correct.

Each question has a command line option associated with it, and there is
also a command line option to skip all the questions.

To do this, press Ctrl-C now and re-run 'perl Build.PL' with the
appropriate options.  To see the documentation for the options run:

    perldoc Build.PL

Press RETURN to continue.

EOM

<STDIN>;

# ------------------------------------------------------------------------

print <<EOM;

The test suite includes tests to check that SVN::Web works correctly
when installed under Apache.  You do not have to run these tests, but
if you intend to use SVN::Web with Apache then they may highlight
issues that were not encountered in the author's development
environment.

EOM

$feature{run_apache_tests} =
      Module::Build->y_n(q{==> Do you want to run the Apache tests?}, 'n');

while($feature{run_apache_tests}) {
    $config_data{apache_path} =
      Module::Build->prompt('==> Please enter the full path to your Apache httpd binary', '/usr/local/sbin/httpd');

    if(! -x $config_data{apache_path}) {
        print "The path\n\n";
	print "  '", $config_data{apache_path}, "'\n\n";
	print "is not executable.\n\n";
	next;
    }

    $config_data{apxs_path} =
      Module::Build->prompt('==> Please enter the full path to your apxs binary', dirname($config_data{apache_path}) . '/apxs');

    if(! -x $config_data{apxs_path}) {
        print "The path\n\n";
	print "  '", $config_data{apxs_path}, "'\n\n";
	print "is not executable.\n\n";
	next;
    }

    last;
} continue {
    $feature{run_apache_tests} =
      Module::Build->y_n('==> Do you still want to run the Apache tests?', 'n');
}

# ------------------------------------------------------------------------

# Work out which version of Apache we're using
if($feature{run_apache_tests}) {
    my $httpd_v = `$config_data{apache_path} -v`;
    my($httpd_version) = $httpd_v =~ m{^Server version: Apache/(\d)\.};
    $config_data{httpd_version} = $httpd_version;

    if($httpd_version == 1) {
        print "Apache 1.x detected\n";
        $requires{'Apache::Request'} = 0;
    }

    if($httpd_version == 2) {
        print "Apache 2.x detected\n";
        $requires{'Apache2::Request'} = 0;
    }

    if($httpd_version < 1 or $httpd_version > 2) {
        print <<"EOM";
The output from running

    $config_data{apache_path} -v

did not produce something this program could parse to determine your
Apache version number.  The output was:

$httpd_v

Please report this as a bug.  In the meantime, the Apache tests have
been disabled.
EOM

	$feature{run_apache_tests} = 0;
    }
}

# ------------------------------------------------------------------------

if($feature{run_apache_tests}) {
    print <<EOM;

SVN::Web can be run under Apache as a CGI script.

EOM

    $feature{run_apache_cgi_tests} =
      Module::Build->y_n('==> Do you want to test that SVN::Web works with Apache as a CGI script', 'y');
}

# ------------------------------------------------------------------------

if($feature{run_apache_tests}) {
    $feature{run_mod_perl_tests} =
      Module::Build->y_n(q{==> Do you want to test mod_perl support?}, 'y');
} else {
    $feature{run_mod_perl_tests} = 0;
}

# Find the mod_perl .so
if(exists $config_data{apxs_path} and defined $config_data{apxs_path}) {
    my $libexec_dir;
    chomp($libexec_dir = `$config_data{apxs_path} -q LIBEXECDIR`);
    $config_data{libexec_dir} = $libexec_dir;

    foreach my $file (qw(mod_perl.so libperl.so)) {
        if(-f "$libexec_dir/$file") {
            $config_data{mod_perl_path} = "$libexec_dir/$file";
	    last;
        }
    }
}

while($feature{run_mod_perl_tests}) {
    $config_data{mod_perl_path} =
      Module::Build->prompt('==> Please enter the full path to your mod_perl library:', $config_data{mod_perl_path});

    if(! -e $config_data{mod_perl_path}) {
        print "The path\n\n";
	print "  '", $config_data{mod_perl_path}, "'\n\n";
	print "does not exist.\n\n";
	next;
    }

    last;
} continue {
    $feature{run_mod_perl_tests} =
      Module::Build->y_n('==> Do you still want to run the mod_perl tests?', 'n');
}

# ------------------------------------------------------------------------

print <<EOM;

SVN::Web includes a simple web server (called "svnweb-server") that
uses the HTTP::Server::Simple module.

Would you like to use this server?  If so, HTTP::Server::Simple will
be added to the list of modules that SVN::Web requires and tests will
be run before installation to make sure that it is working correctly.

EOM

$feature{'run_svnweb-server_tests'} =
      Module::Build->y_n(q{==> Do you want to test svnweb-server?}, 'y');

$requires{'HTTP::Server::Simple'} = 0 if $feature{'run_svnweb-server_tests'};

if($feature{run_apache_tests} or $feature{'run_svnweb-server_tests'}) {
    print <<EOM;

The httpd server will be started listening on the loopback address
(127.0.0.1).  However, it must be bound to a network port that is not
currently being used by another service.

EOM

    until(defined $config_data{httpd_port}) {
        $config_data{httpd_port} =
	  Module::Build->prompt('==> Please enter a spare port', 8080);

	if($config_data{httpd_port} !~ /^\d+$/) {
	    print "The port must contain only digits.\n\n";
	    next;
	}

	if($config_data{httpd_port} < 1024 and $> != 0) {
	    print <<EOM;

You have entered a port number that is less than a 1024, and you are
not the root user.  Please enter a different port number.

EOM

	    next;
	}

	if($config_data{httpd_port} < 1) {
	    print "Ports less than 1 are not allowed\n\n";
	    next;
	}

	if($config_data{httpd_port} > 65535) {
	    print "Ports greater than 65535 are not allowed\n\n";
	    next;
	}

	last;
    } continue {
	$config_data{httpd_port} = undef;
    }
}

# ------------------------------------------------------------------------

print <<EOM;

SVN::Web can use plugins to turn e-mail addresses and URLs in
Subversion commit messages in to clickable hyperlinks.

EOM

if(Module::Build->y_n('==> Do you want to install these plugins?', 'y')) {
    $requires{'Template::Plugin::Clickable'} = 0;
    $requires{'Template::Plugin::Clickable::Email'} = 0;
}

# ------------------------------------------------------------------------

build:

$b = $class->new(
    dist_name          => 'SVN-Web',
    dist_author        => 'Nik Clayton <nik@FreeBSD.org>',
    license            => 'perl',
    module_name        => 'SVN::Web',
    create_makefile_pl => 'passthrough',
    create_readme      => 0,
    sign               => 1,
    script_files       => [ 'bin/svnweb-install', 'bin/svnweb-server' ],
    requires           => \%requires,
    recommends         => { 'Cache::Cache',                      => 0,
	                    'Template::Plugin::Subst'            => 0,
                            'Test::Benchmark'                    => 0,
                            'Test::HTML::Tidy'                   => 0,
                            'XML::RSS::Parser'                   => 0, },
    add_to_cleanup     => [ qw't/repos*' ],
);

$b->config_data($_ => $config_data{$_}) foreach keys %config_data;
$b->feature($_ => $feature{$_})         foreach keys %feature;

$b->create_build_script();

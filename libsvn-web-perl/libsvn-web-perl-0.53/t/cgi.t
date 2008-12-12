#!/usr/bin/perl

use warnings;
use strict;

use POSIX ();
use File::Temp qw(tempdir);
use Test::More;

use Template;

use SVN::Web::Test;
use SVN::Web::ConfigData;

plan skip_all => q{apache cgi tests, disabled by installer}
    unless SVN::Web::ConfigData->feature('run_apache_cgi_tests');

plan 'no_plan';

my $httpd         = SVN::Web::ConfigData->config('apache_path');
my $port          = SVN::Web::ConfigData->config('httpd_port');
my $libexec_dir   = SVN::Web::ConfigData->config('libexec_dir');
my $httpd_version = SVN::Web::ConfigData->config('httpd_version');

my $test = SVN::Web::Test->new(repo_path    => 't/repos',
			       repo_dump    => 't/test_repo.dump',
			       apache1_path => $httpd,
			       httpd_port   => $port);

# Create the httpd config file
my $template = Template->new();
my $cwd = POSIX::getcwd();
my $dir = $test->install_dir();

$template->process("conf/apache$httpd_version.tt",
		   { blib_dir           => "$cwd/blib/lib",
		     svnweb_install_dir => $dir,
		     httpd_port         => $port,
		     cgi_bin            => 1,
		     libexec_dir        => $libexec_dir,
		   }, "$dir/httpd.conf");
undef $template;

$test->start_server(qq{ $httpd -f $dir/httpd.conf -X });
$test->mech()->get_ok($test->site_root());
$test->walk_site(sub { ok(1, $test->mech()->uri()); });
$test->stop_server();

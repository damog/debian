#!/usr/bin/perl

use warnings;
use strict;

use POSIX ();
use Test::More;

use Template;

use SVN::Web::Test;
use SVN::Web::ConfigData;

plan skip_all => q{svnweb-server tests, disabled by installer}
    unless SVN::Web::ConfigData->feature('run_svnweb-server_tests');

plan 'no_plan';

my $port  = SVN::Web::ConfigData->config('httpd_port');

my $test = SVN::Web::Test->new(repo_path    => 't/repos',
			       repo_dump    => 't/test_repo.dump',
			       httpd_port   => $port,
			       root_url     => "http://localhost:$port");

my $cwd = POSIX::getcwd();
my $dir = $test->install_dir();

$test->start_server(qq{ $^X -I$cwd/blib/lib $cwd/bin/svnweb-server --root $dir --port $port });
$test->mech()->get_ok($test->site_root());
$test->walk_site(sub { ok(1, $test->mech()->uri()); });
$test->stop_server();


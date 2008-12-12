#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 6;
use Cwd;
use File::Temp qw(tempdir);
use YAML ();

# Make sure that it compiles cleanly
system $^X, qw(-Iblib/lib -c bin/svnweb-install);
is($? >> 8, 0, 'svnweb-install compiled cleanly');

# Run in a temporary directory, verify that the generated config.yaml parses
my $tmpdir = tempdir(CLEANUP => 1);
my $cwd = getcwd();
chdir($tmpdir);

system "$^X -I$cwd/blib/lib $cwd/bin/svnweb-install > /dev/null";

foreach my $file (qw(config.yaml index.cgi)) {
    ok(-f "$tmpdir/$file", "$tmpdir/$file created");
}

foreach my $dir (qw(css template)) {
    ok(-d "$tmpdir/$dir", "$tmpdir/$dir/ created");
}

my $config;
$config = eval { YAML::LoadFile('config.yaml'); };
ok(defined $config, "YAML::LoadFile('$tmpdir/config.yaml') succeeded");

# $Rev: 33 $
# $Id: Makefile.PL 33 2003-07-20 18:45:06Z afoxson $

use strict;
use inc::Module::Install;

if (-d ".svn") { # this is necessary only because we're using subversion
	require File::Spec;
	require ExtUtils::MakeMaker;

	my $version_diff = 0;
	my $version_from = File::Spec->catfile(qw(lib Acme SoftwareUpdate.pm));

	if ($ARGV[0] && $ARGV[0] eq "--setversion") {
		shift @ARGV;
		open my $st, "svn st -u|" or die;
		my $dirty = 0;
		while (<$st>) {
			next if /^\?/;
			next if /^Head revision:/;
			print;
			$dirty++;
		}
		close $st;
		die "Not everything checked in?\n" if $dirty;

		# $re parses the upper boundary of the output of svnversion
		my $re = qr/(?:\d+:)?(\d+)[SM]*$/;
		my($sv_dot)  = `svnversion .`             =~ $re;
		my($sv_from) = `svn st -u $version_from`  =~ /(\d+)/;
		die "Could not determine sv_from or sv_dot"
			unless $sv_from > 0 && $sv_dot > 0;
		if ($sv_dot > $sv_from) {
			# set some property to make a checkin of this file possible:
			system svn => "propset", "cpan:release",
				"after_$sv_dot", $version_from;
			# must check in to get the version up to the bleading edge:
			system svn => "ci", "-m",
				"Property set for release after_$sv_dot", $version_from;
			# will have to die after Makefile is rewritten:
			$version_diff = 1;
		}
		exit unless $version_diff;
	}

	if ($version_diff) {
		die
			"==> I had to update some \$VERSIONs  <==\n" .
			"==> Your Makefile has been rebuilt. <==\n" .
			"==> Please rerun the make command.  <==\n";
	}

	if ($ExtUtils::MakeMaker::VERSION < 6.06) {
		eval q{
			sub MY::libscan {
				my $path = $_[1];
				return '' if $path =~ /\B\.svn\b/;
				return $path;
			}
		};
	}
}

name('Acme-SoftwareUpdate');
version_from('lib/Acme/SoftwareUpdate.pm');
abstract('check for newer version of caller module');
author('Adam J. Foxson <afoxson@pobox.com>');
license('gpl');

features(
	'Support for auto-upgrading of out-of-date distributions' => [
		-default => 1,
		recommends('ExtUtils::AutoInstall'),
	],
	'Support for non-standard version comparisons' => [
		-default => 1,
		recommends('version'),
		recommends('Sort::Versions'),
	],
);

include('ExtUtils::AutoInstall');

check_nmake();
auto_install();

&Meta->write;
&Build->write if lc($0) eq 'build.pl';
&Makefile->write if lc($0) eq 'makefile.pl';

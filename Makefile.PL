# $Rev: 19 $
# $Id: Makefile.PL 19 2003-07-13 15:53:52Z afoxson $

use inc::Module::Install;

if (-d ".svn") { # this is necessary only because we're using subversion
	require ExtUtils::MakeMaker;
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
    'Support for auto-installation of out-of-date distributions' => [
        -default => 0,
        recommends('ExtUtils::AutoInstall'),
    ],
);

include('ExtUtils::AutoInstall');

check_nmake();
auto_install();

&Meta->write;
&Build->write if lc($0) eq 'build.pl';
&Makefile->write if lc($0) eq 'makefile.pl';

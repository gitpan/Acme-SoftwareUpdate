use strict;
use Test;
use Acme::SoftwareUpdate;

BEGIN {plan tests => 6}

if (!eval { require Socket; Socket::inet_aton('search.cpan.org') }) {
	for (1..6) {
		print "ok $_ # skip - Cannot connect to search.cpan.org\n";
	}
}
else {
	my $inst_vers_of_test_pm =
		Acme::SoftwareUpdate::check_inst_vers($INC{'Test.pm'}, 'Test');
	my ($cpan_vers_of_test_pm, $dlurl_of_test_pm) =
		Acme::SoftwareUpdate::get_cpan_vers_and_dlurl('Test');
	my $inst_vers_of_strict_pm =
		Acme::SoftwareUpdate::check_inst_vers($INC{'strict.pm'}, 'strict');
	my ($cpan_vers_of_strict_pm, $dlurl_of_strict_pm) =
		Acme::SoftwareUpdate::get_cpan_vers_and_dlurl('strict');

	ok($inst_vers_of_test_pm =~ /\d\.\d{2}/);
	ok($cpan_vers_of_test_pm =~ /\d\.\d{2}/);
	ok($dlurl_of_test_pm =~ /search\.cpan\.org\/CPAN\/authors\/id\//);
	ok($inst_vers_of_strict_pm =~ /\d\.\d{2}/);
	ok(not $cpan_vers_of_strict_pm);
	ok(not $dlurl_of_strict_pm);
}

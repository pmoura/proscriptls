JSC=/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Resources/jsc
DEBUG=false
SWIPL=/opt/local/bin/swipl


test:		../wam-pp.js ../bootstrap.js standalone.js ../wam_compiler.pl tests.pl
		$(SWIPL) -q -f ../wam_compiler.pl -g "bootstrap('../', ['tests.pl'], run_unit_tests), halt"
		$(JSC) ../wam-pp.js bootstrap.js standalone.js  -e "unit_tests($(DEBUG))"
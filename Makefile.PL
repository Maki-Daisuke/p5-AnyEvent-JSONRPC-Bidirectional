use inc::Module::Install;
name 'AnyEvent-JSONRPC-Bidirectional';
all_from 'lib/AnyEvent/JSONRPC/Bidirectional.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;

use inc::Module::Install;
name 'AnyEvent-JSONRPC-Bidirectional';
all_from 'lib/AnyEvent/JSONRPC/Bidirectional.pm';

requires 'Carp';
requires 'AnyEvent::Handle';
requires 'Try::Tiny' => 0.07;

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;

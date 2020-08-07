use v6.d;
use Test;

plan 3;

use Shell::Piping;
use Shell::Piping::Whereceptions;

sub must-be-file(IO() $f where &it-is-a-file) {}
sub must-be-directory(IO() $d where &it-is-a-directory) {}
sub must-be-executable(IO() $d where &it-is-executable) {}

throws-like {must-be-file(‚t‘)}, X::IO::FileNotFound, ‚test for file throws‘;
throws-like {must-be-directory(‚t/10-whereceptions.t‘)}, X::IO::DirectoryNotFound, ‚test for file throws‘;
throws-like {must-be-executable(‚t/10-whereceptions.t‘)}, X::IO::FileNotExecutable, ‚test for file throws‘;


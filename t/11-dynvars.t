use v6;
use Test;

plan 3;

use Shell::Piping;

my $*always-capture-stderr = 42;

dies-ok { Shell::Pipe::check-dynvar($*always-capture-stderr) }, ‚type check on dynvar works‘;
lives-ok { $*always-capture-stderr = on; $*always-capture-stderr = off; }, ‚on and off are visible in scope‘;

my $source = Proc::Async.new: ‚t/bin/source‘;
my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
my @a;

$*always-capture-stderr = on;

$source |» $errorer |» @a :done({ .exitcodes; is $_.captured-stderr.elems, 7, ‚$*always-capture-stderr works‘ });

use v6;
use Test;

plan 3;

use Shell::Piping;

lives-ok { $*always-capture-stderr = on; $*always-capture-stderr = off; }, ‚on and off are visible in scope‘;

my $source = Proc::Async.new: ‚t/bin/source‘;
my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
my @a;
my @err;

$source |» $errorer |» @a :stderr(@err) :done({ .exitcodes; is $_.captured-stderr.elems, 0, ‚$*always-capture-stderr does not missfire‘ });

$source = Proc::Async.new: ‚t/bin/source‘;
$errorer = Proc::Async.new: ‚t/bin/errorer‘;
@a = [];

my $*always-capture-stderr = on;
$source |» $errorer |» @a :done({ .exitcodes; is $_.captured-stderr.elems, 7, ‚$*always-capture-stderr works‘ });

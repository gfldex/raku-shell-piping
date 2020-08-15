use v6;
use Test;

plan 6;

use Shell::Piping;

lives-ok { $*capture-stderr = on; $*capture-stderr = off; }, ‚on and off are visible in scope‘;
is on ~~ off, False, ‚on/off values are distinct‘;
is on ~~ 42, False, ‚no automatic coersion to Int‘;
dies-ok { on ~~ 'on' }, ‚no coersion to Str‘;

my $source = Proc::Async.new: ‚t/bin/source‘;
my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
my @a;
my @err;

$source |» $errorer |» @a :stderr(@err) :done({ .exitcodes; is $_.captured-stderr.elems, 0, ‚$*capture-stderr does not missfire‘ });

$source = Proc::Async.new: ‚t/bin/source‘;
$errorer = Proc::Async.new: ‚t/bin/errorer‘;
@a = [];

my $*capture-stderr = on;
$source |» $errorer |» @a :done({ .exitcodes; is $_.captured-stderr.elems, 7, ‚$*capture-stderr works‘ });

use Test;
plan 12;

use Shell::Piping;

{ #1
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @a;

    $source |» $errorer |» @a :stderr(Capture);

    CATCH { 
        when X::Shell::NonZeroExitcode { 
            for .pipe.exitcodes {
                when ‚t/bin/errorer‘ & 1 & /adipiscing \s (\S+)/ {
                    is $0, ‚sed‘, ‚captured STDERR and throw on non-zero exitcode‘;
                }
            }
        }
    }
}
{ #2..5
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @a;

    sub error-handler($pipe) {
        my @a = $pipe.exitcodes;
        ok @a».exitcode.any ~~ 1, ‚.exitcodes handles Failure‘;
        ok (try @a[2] ~~ ‚t/bin/errorer‘), ‚Exitcode smartmatches against Str‘;
        ok (try @a[2] ~~ 1),               ‚Exitcode smartmatches against Int‘;
        ok (try @a[2] ~~ /adipiscing/),    ‚Exitcode smartmatches against Regex‘;
    }

    $source |» { $_ } |» $errorer |» @a :done(&error-handler) :stderr(Capture);
}
{ #6
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my @a;

    sub done-handler(Shell::Pipe $_) {
        nok .exitcodes, ‚zero exitcodes is False‘;
    }
    $source |» $drain |» @a :done(&done-handler) :quiet;

    CATCH { default { say .^name, .backtrace.Str } }
}
{ #7
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $drain = Proc::Async.new: ‚t/bin/drain‘;
    my @a;
    my $pipe = $source |» $drain |» @a;
    
    throws-like { $pipe.exitcodes }, X::Shell::NoExitcodeYet, ‚exitcode unavailable before pipe finishes‘;
}
{ #8
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @a;
    my @err;

    $source |» { $_ } |» $errorer |» @a :done({.exitcodes}) :stderr(@err);
    is-deeply @err[*;1][0,1,2], ("Lorem", "sit", "adipiscing"), ‚:stderr wit Arrayish‘;
}
{ #9
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @err;
    my @a;
    sub err-handler($stream, $msg) {
        @err.push: ($stream, $msg);
    }
    $source |» $errorer |» @a :stderr(&err-handler) :done({.exitcodes});
    is-deeply @err[*;1][0,1,2], ("Lorem", "sit", "adipiscing"), ':stderr with sub';
}
{ #10
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @err;
    my @a;
    my $c = Channel.new;
    $c.Supply.tap: -> \v { @err.push: v }; 
    $source |» $errorer |» @a :stderr($c) :done({.exitcodes});
    $c.close;
    is-deeply @err[*;1][0,1,2], ("Lorem", "sit", "adipiscing"), ':stderr with channel';
}
{ #11
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @err;
    my @a;
    my $c = Channel.new;
    $c.Supply.tap: -> \v { @err.push: v }; 
    $source |» $errorer |» @a :stderr($c & Capture);
    $c.close;
    CATCH { 
        when X::Shell::NonZeroExitcode { 
            for .pipe.exitcodes {
                when ‚t/bin/errorer‘ & 1 & /adipiscing \s (\S+)/ {
                    ok ($0 eq ‚sed‘) && (@err[*;1][0,1,2] ~~ ("Lorem", "sit", "adipiscing")), ‚captured STDERR and Channel‘;
                }
            }
        }
    }
}
{ #12
    my $source = Proc::Async.new: ‚t/bin/source‘;
    my $errorer = Proc::Async.new: ‚t/bin/errorer‘;
    my @a;

    $source |» $errorer |» @a :stderr(Capture but 2);

    CATCH { 
        when X::Shell::NonZeroExitcode { 
            for .pipe.exitcodes {
                when ‚t/bin/errorer‘ & 1  {
                    is .Str, "labore\nmagna", ‚captured STDERR with a limit‘;
                }
            }
        }
    }
}

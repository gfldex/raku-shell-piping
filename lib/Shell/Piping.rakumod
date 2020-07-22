subset Arrayish of Any where { !.isa('Code') && .^can(‚push‘) && .^can(‚list‘) }
subset CodeOrChannel of Any where Code | Channel;

class X::Shell::PipeeStartFailed is Exception is export {
    has $.command;
    has $.env-path;
}
class X::Shell::CommandNotFound is Exception is export {
    has $.cmd;
    method message { 'The shell command ⟨' ~ $.cmd ~ '⟩ was not found.' }
}
class X::Shell::NoAccess is Exception is export {
    has $.cmd;
    method message { 'The shell command ⟨' ~ $.cmd ~ '⟩ is not accessible.' }
}

class Shell::Pipe::Exitcode::Container is export {
    has &.callback;
}

class Shell::Pipe::Path::Container {
    has @.path;
}

class Shell::Pipe is export {
    class Command {
        has $.command-path is rw;
        has @.arguments is rw;
        has Bool $.absolute is rw;
        method proc {
            Proc::Async.new: $.command-path, @.arguments
        }
        method CALL-ME {
            self.proc
        }
    }

    class BlockContainer {
        has &.code;
        has $.proc-in is rw;
        has $.proc-out;
        has $.proc-out-stdout;
        method start { start { 
            await $.proc-out.ready;
            await $.proc-in.ready with $.proc-in;
            for $.proc-out-stdout.lines {
                my $value := &.code.($_);
                my $processed = $value === Nil ?? ‚‘ !! $value ~ "\n";
                $.proc-in.write: $processed.encode with $.proc-in;
            }
            $.proc-in.close-stdin with $.proc-in;
        } }
    }

    constant NotYet = Mu.new but role { method defined { False } };

    has @.pipees;
    has @.starters; # list of Callable returning Awaitable

    has $.exitcode is rw = { NotYet };
    has $.name is rw = "Shell::Pipe <anon>";
    has $.search-path is rw;
    has &.done is rw = Code;
    has $.stderr is rw = CodeOrChannel;
    has $.prefix is rw;
    has Bool $.quiet is rw; # divert STDERR away from terminal

    method start {
        do for @.starters.reverse -> &c { |c }
    }
    method sink { 
        with $.stderr {
            for @.pipees.kv -> $index, $proc {
                if $proc ~~ Proc::Async {
                    if $.stderr ~~ Code {
                        try $proc.stderr.lines.tap: -> $line { $.stderr.($index, $line) };
                    } elsif $.stderr ~~ Channel {
                        try $proc.stderr.lines.tap: -> $line { $.stderr.send( ($index, $line) ) };
                    }
                }
            }
        } elsif $.quiet {
            for @.pipees -> $proc {
                if $proc ~~ Proc::Async {
                    try $proc.stderr.tap: -> $s {};
                }
            }
        }
        # FIXME check if any Promise was broken, because a process did not start
        my @proms = await(self.start).grep: * ~~ Proc;
        my @exitcodes;
        for @proms.reverse {
            @exitcodes.push: .exitcode when Proc;
        }
        $.exitcode = @exitcodes but (@exitcodes.all == 0 ?? False !! True);
        &.done.(self) with &.done;
        @proms
    }
    method gist { 
        @.pipees.map(*.&gist-of-pipee).join(' ↦ ')
    }
    sub gist-of-pipee($e) {
        given $e { 
            when Proc::Async { .path.IO.basename }
            when Routine { .name }
            when Block { „Block({.file.IO.basename}:{.line})“ }
            when BlockContainer { „Block({.code.file.IO.basename}:{.code.line})“ }
            when Arrayish { .?name // .WHAT.gist }
        }
    }
}

sub px(*@l) is export {
    my $command = @l.first;
    my @arguments = @l[1..*];
    my $in-path = not $command.contains($*SPEC.dir-sep);
    my $command-path = $in-path ?? whereis.first(*.x) !! $command.IO;

    X::Shell::CommandNotFound.new(:cmd($command-path)) if !$command-path.e;
    X::Shell::CommandNoAccess.new(:cmd($command-path)) if !$command-path.x;

    return Shell::Pipe::Command.new: :$command-path, :@arguments, :absolute(!$in-path);

    sub whereis {
        %*ENV<PATH>.split(‚:‘).map(*.IO.add($command));
    }
}

multi infix:<|»>(Proc::Async:D $out, Proc::Async:D $in, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export { 
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.append: $out, $in;
    $pipe.starters.append: -> {
        $in.start, $out.start 
    }

    $in.bind-stdin: $out.stdout;

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Shell::Pipe::BlockContainer, Proc::Async:D $in, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    my $blockish = $pipe.pipees.tail;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);
    $blockish.proc-in = $in;

    $pipe.pipees.push: $in;
    $pipe.starters.append: -> {
        $in.start
    }

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe, Proc::Async:D $in, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export { 
    # TEST DONE
    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    my $out = $pipe.pipees.tail;
    $pipe.pipees.push: $in;

    given $out {
        when Proc::Async { 
            $in.bind-stdin: .stdout;
            $pipe.starters.push: -> { $in.start };
        }
        when Arrayish { 
            fail "Arrayish not at the tail or head of a pipe.";
        }
    }

    $pipe
}

multi infix:<|»>(Proc::Async:D $out, Arrayish:D \a, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export { 
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: a;

    $out.stdout.lines.tap(-> \e { a.push: e });
    $pipe.starters.push(-> { $out.start });

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, Arrayish:D \a, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export { 
    # TEST DONE
    my $out = $pipe.pipees.tail;
    $pipe.pipees.push: a;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $out.stdout.lines.tap(-> \e { a.push: e });

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Shell::Pipe::BlockContainer, Arrayish:D \a, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    # TEST DONE
    my $cont = $pipe.pipees.tail;
    my $fake-proc = class { 
        method write($blob) { a.push: $blob.decode.chomp } 
        method ready { my $p = Promise.new; $p.keep; $p }
        method close-stdin { True }
    }.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $cont.proc-in = $fake-proc;
    $pipe.pipees.push: a;

    $pipe
}

multi infix:<|»>(Arrayish:D \a, Proc::Async:D $in, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export { 
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: a;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);
    # $pipe.starters.push: -> { 
    #     | $in.start, start {
    #         LEAVE try $in.close-stdin;
    #         await $in.ready;
    #         $in.write: „$_\n“.encode for a.list;
    #     }
    # }
    $pipe.starters.push: -> { $in.start };
    $pipe.starters.push: -> { 
        start {
            LEAVE try $in.close-stdin;
            await $in.ready;
            await $in.write: „$_\n“.encode for a.list;
        }
    }

    $pipe
}

multi infix:<|»>(&c, Proc::Async:D $in, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: &c;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);

    $pipe.starters.push: -> {
        | $in.start, start {
            LEAVE try $in.close-stdin;
            await $in.ready;
            for c() {
                next if $_ === Nil;
                await $in.write: „$_\n“.encode;
            }
        }
    }
    
    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe, &c, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    my $out = $pipe.pipees.tail;
    my $cont = Shell::Pipe::BlockContainer.new: :code(&c), :proc-out($$out), :proc-out-stdout($out.stdout);

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: $cont;
    # $out.stdout.lines.tap(&c);

    $pipe.starters.push: -> { $cont.start };

    $pipe
}

multi infix:<|»>(Proc::Async:D $out, &c, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) { 
    my $pipe = Shell::Pipe.new;
    my $cont = Shell::Pipe::BlockContainer.new: :code(&c), :proc-out($out), :proc-out-stdout($out.stdout);

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: $cont;

    $pipe.starters.push: -> { $out.start; }
    $pipe.starters.push: -> { $cont.start; };

    $pipe;
}


multi infix:<|»>(Supply:D \s, Proc::Async:D $in, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: s;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);

    $pipe.starters.push: -> { start {
        await $in.ready;
        s.tap: -> $v { await $in.write: „$v\n“.encode }, :done({ try $in.close-stdin }), :quit({ try $in.close-stdin });
    } };
    $pipe.starters.push: -> { $in.start };

    $pipe
}

multi infix:<|»>(Proc::Async:D $out, Supplier:D \s, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: s;
    $pipe.starters.push: -> { $out.start };
    $out.stdout.lines.tap(-> $v { 
        s.emit($v);
    });

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, Supplier:D \s, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    # TEST DONE
    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    my $out = $pipe.pipees.tail;
    $pipe.pipees.push: s;
    $out.stdout.lines.tap(-> $v { 
        s.emit($v);
    });

    $pipe
}

multi infix:<|»>(Channel:D \c, Proc::Async:D $in, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: c;
    $pipe.pipees.push: $in;
    # FIXME workaround R#3778
    $in.^attributes.grep(*.name eq '$!w')[0].set_value($in, True);

    $pipe.starters.push: -> { start {
        for c.list -> $v {
            await $in.write: „$v\n“.encode;
        }
        $in.close-stdin;
    } };
    $pipe.starters.push: -> { $in.start };

    $pipe
}

multi infix:<|»>(Proc::Async $out, Channel:D \c, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    # TEST DONE
    my $pipe = Shell::Pipe.new;

    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    $pipe.pipees.push: $out;
    $pipe.pipees.push: c;

    $out.stdout.lines.tap: -> $v { c.send: $v };
    $pipe.starters.push: -> { $out.start };

    $pipe
}

multi infix:<|»>(Shell::Pipe:D $pipe where $pipe.pipees.tail ~~ Proc::Async, Channel:D \c, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export {
    # TEST DONE
    $pipe.done = &done;
    $pipe.stderr = $stderr with $stderr;
    $pipe.quiet = $quiet;

    my $out = $pipe.pipees.tail;
    
    $pipe.pipees.push: c;
    $out.stdout.lines.tap(-> $v {
        c.send: $v
    });

    $pipe
}

sub infix:«|>>»(\a, \b, :&done? = Code, :$stderr? = CodeOrChannel, Bool :$quiet?) is export { a |» b :&done :$stderr :$quiet }

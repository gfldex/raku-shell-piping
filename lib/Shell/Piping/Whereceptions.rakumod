use v6.d;

INIT my $colour = %*ENV<SHELLPIPINGNOCOLOR>:!exists;

sub RED($str) { $*ERR.t && $colour ?? „\e[31m$str\e[0m“ !! $str }

class X::Whereception is Exception is export {
    has $.stale-symlink is rw;
    method is-dangling-symlink {
        $.stale-symlink = do with $.path { .IO.l & !.IO.e };
    }
}

class X::IO::FileNotFound is X::Whereception is export {
    has $.path;
    method message {
        RED $.is-dangling-symlink ?? „The file ⟨$.path⟩ is a dangling symlink.“ !! „The file ⟨$.path⟩ was not found.“
    }
}

class X::IO::DirectoryNotFound is X::Whereception is export {
    has $.path;
    method message {
        RED $.is-dangling-symlink ?? „The directory ⟨$.path⟩ is a dangling symlink.“ !! „The directory ⟨$.path⟩ was not found.“
    }
}
class X::IO::FileNotExecutable is X::Whereception is export {
    has $.path;
    method message {
        RED $.is-dangling-symlink ?? „The executable ⟨$.path⟩ is a dangling symlink.“ !! „The file ⟨$.path⟩ is not executable.“
    }
}

our &it-is-a-file = -> IO() $_ {
    .e && .f || fail (X::IO::FileNotFound.new(:path(.Str)))
}

our &it-is-a-directory = -> IO() $_ {
    .d || fail (X::IO::DirectoryNotFound.new(:path(.Str)))
}

our &it-is-executable = -> IO() $_ {
    .x || fail (X::IO::FileNotExecutable.new(:path(.Str)))
}

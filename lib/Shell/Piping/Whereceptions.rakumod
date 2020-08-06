use v6.d;

class X::IO::FileNotFound is Exception is export {
    has $.path;
    method message {
        „The file ⟨$.path⟩ was not found.“
    }
}

class X::IO::DirectoryNotFound is Exception is export {
    has $.path;
    method message {
        „The directory ⟨$.path⟩ was not found.“
    }
}
class X::IO::FileNotExecutable is Exception is export {
    has $.path;
    method message {
        „The file ⟨$.path⟩ is not executable.“
    }
}

our &it-is-a-file = -> IO(Str) $_ {
    .e && .f || fail (X::IO::FileNotFound.new(:path(.Str)))
}

our &it-is-a-directory = -> IO(Str) $_ {
    .d || fail (X::IO::DirectoryNotFound.new(:path(.Str)))
}

our &it-is-executable = -> IO(Str) $_ {
    .x || fail (X::IO::FileNotExecutable.new(:path(.Str)))
}

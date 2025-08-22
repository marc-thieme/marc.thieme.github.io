sig Name {}
abstract sig Object {
  name: Name
}

sig Dir extends Object {
  entries : set Object
}

sig File extends Object {}
one sig Root extends Dir {}

fact {
  // Root is actually the root
  Root.*entries = Object
  // Each file belongs to some directory
  entries :> File in Dir one -> File
}

run {
  // Root contains at least one file
  some Root.entries & File
  // Filesystem is deeper than two layers
  some Root.entries.entries
} for 8

Chew & Spit
==============

#### A Source code documentatation tool written in Ruby

The problem with working on large systems is that they can grow
from a handful of file to a tangled mess of codes some of which
are likely to end up getting lost and forgotten leading to unnecessary
code duplication.

Chew and Spit is my attempt to get a handle on that complexity
by automating the profiling  of large codebases.  It's likely possible
that a number of similar tools already exists, but I'm taking this
as an opportunity to get some mileage on ruby (been reading the Dave Thomas'
pickaxe book while working on this early on) while also taking on the problem
of 'how to tackle large systems' (As a developer, this been a constant
source of both annoyance and pain and I'm compelled to find a means around this).

Chew and Spit is designed to be extensible so it won't just be working
on one system but (potentially) on a variety of systems/languages. It is limited to PHP
support at the moment, but support for other languages will be thrown in, gradually.


### Dependencies ###

*rghost
*ruby-graphviz

Usage
-----

spit.rb <outputfile.pdf>


# Parsing Alloy Analyzer output from the commandline
## The Problem
So you are working with the [Alloy analyzer](https://alloytools.org/)?
Usually, you would use the GUI for that.
However, there are cases where you need to interact with it in an automated fashion.
For example, in my Bachelor's thesiss, I was using Alloy to find
solutions to a specific problem.
The programs where generated on the fly and the execution needed to be incorporated
into the build process.

One way of doing this would be to write a driver for the JVM which uses the native
[Java–API of Alloy](https://alloytools.org/documentation/alloy-api/index.html).
However, this comes with the overhead of managing a standalone JVM project just for administering Alloy's execution.
What you can also do is use the cli interface.

For example, let's look at this (shortened) example of a filesystem model inspired by the examples in
[Practical Alloy](https://practicalalloy.github.io/):

```alloy
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
```

## Executing Alloy from the CLI
The jar–file for Alloy is available for download [here](https://github.com/AlloyTools/org.alloytools.alloy/releases/download/v6.2.0/org.alloytools.alloy.dist.jar).
Using that, we would verify the above model by running
`java -jar <alloy-jar-file> exec example.also`.
This executes the first `run` or `check` command in `example.also`
and prints either `SAT` or `UNSAT` depending on the success of the
command.
If you want to know all the flags you could pass to the execution, run
```sh
java -jar <alloy-jar-file> exec --help
```

As there is no code involved other than the Alloy program and the CLI command,
running it like this is easier than the aforementioned approach using a separate JVM project.
Parsing the output for success/failure using a something `grep` is also easier enough.
However, it is not appearent how to obtain the model instance the Alloy solver came up with.

For example, we can look at the filesystem–example above.
If it were malformed and unsatisfyable,
all information we could obtain is the fact that there does not exist an
instance for the model.
However, as the model is satisfyable,
the solver actually comes up with such an instance while solving the problem.
In the following, I will walk through how this instance can be processed using XML and
[XPath](https://www.w3schools.com/xml/xpath_intro.asp) expressions.

## JSON format
The cli supports 4 output formats, specified using the `-t` flag:
`txt`, `table`, `json` and `xml`.
Out of those, `xml` and `java` lend itself well towards automatic parsing.
For `json`, the output of the above example looks like this:

```json
{
  "duration":146,
  "incremental":true,
  "instances":[
    {
      "messages":[
        
      ],
      "skolems":{
        
      },
      "state":0,
      "values":{
        "0":{
          
        },
        "1":{
          
        },
        "2":{
          
        },
        "3":{
          
        },
        "4":{
          
        },
        "5":{
          
        },
        "6":{
          
        },
        "Name$6":{
          
        },
        "Name$7":{
          
        },
        "Object$6":{
          
        },
        "Root$0":{
          
        }
      }
    }
  ],
  "localtime":"2025-08-23T18:52:25.796783651",
  "loopstate":-1,
  "sigs":{
    
  },
  "timezone":"Europe/Berlin",
  "utctime":1755967945796
}
```
As we can see, the `instances` field holds  a list of all values of the generated model.
Each instance further contains the values for all fields of the entities' signature.
However, it does not provide the signature that each entity belongs to.
Instead this would have to be parsed from the ids of the entities.
For example, `Object$0` evidently belongs to the `Object`–signature.
The `json`–format does not contain a lot of information in general.
For example, because signatures are only appearent in the ids of entities,
it does not include information about `extends`–relationships between signatures.
Ultimately, the json representation is easy to parse and is structured in an
entity–oriented way.
That means that you can navigate to an entity and immediately see the other entities
it is linked to by its fields.
However, it lacks information which would be present in the XML output and parsing more
sophisticated models might turn out to be unnecessarily difficult.

## XML output
In the following, I want to explain how the XML output is structured.
This section shall be the bulk of this post because it is both the most information–rich
but also the most powerful output type.
In contrast to the JSON–output,
the XML–output centers around the signatures and relations present in the model.

To give you an idea, is the above output again but using the `-t xml`–flag.

```xml
<alloy builddate="2025-01-09T08:17:18.350Z">

<instance bitwidth="4" maxseq="7" mintrace="-1" maxtrace="-1" command="Run run$1 for 8" filename="" tracelength="1" looplength="1">

<sig label="seq/Int" ID="0" parentID="1" builtin="yes">
</sig>

<sig label="Int" ID="1" parentID="2" builtin="yes">
</sig>

<sig label="String" ID="3" parentID="2" builtin="yes">
</sig>

<sig label="this/Name" ID="4" parentID="2">
   <atom label="Name$0"/>
   <atom label="Name$1"/>
</sig>

<sig label="this/Root" ID="5" parentID="6" one="yes">
   <atom label="Root$0"/>
</sig>

<sig label="this/Dir" ID="6" parentID="7">
</sig>

<field label="entries" ID="8" parentID="6">
   <tuple> <atom label="Root$0"/> <atom label="Root$0"/> </tuple>
   <tuple> <atom label="Root$0"/> <atom label="File$0"/> </tuple>
   <types> <type ID="6"/> <type ID="7"/> </types>
</field>

<sig label="this/File" ID="9" parentID="7">
   <atom label="File$0"/>
</sig>

<sig label="this/Object" ID="7" parentID="2" abstract="yes">
</sig>

<field label="name" ID="10" parentID="7">
   <tuple> <atom label="Root$0"/> <atom label="Name$1"/> </tuple>
   <tuple> <atom label="File$0"/> <atom label="Name$0"/> </tuple>
   <types> <type ID="7"/> <type ID="4"/> </types>
</field>

<sig label="univ" ID="2" builtin="yes">
</sig>

</instance>

</alloy>
```

Arguably, you gain most insight by exploring this XML–output for yourself.
Nevertheless, here is the explanation:

This time we see that the `instances`–tag contains two different types of child–tags:
`sig` and `field`.

Firstly, the `sig`–tags contain a list of `atom`–tags without children.
There, the `label`–attribute indicates the id of the atom.
As for the `sig`–attributes, you can see the name of the signature (prefixed by `this/`),its numeric ID and the numeric ID of its direct parent.
The parent of a signature is relevant for `extends`–relationships.
Notably, the `univ` is the parent for all signature without such a relationship declared.

Secondly, the `field`–tags contain the entries in the model's `n–ary` relations,
that is the fields of the signatures.
The attributes of these tags work in the same veign as above.
`label` gives the name of the field, `ID` its numeric id and `parentID` the numeric id of its parent.
Interestingly, the parent of these fields are the signatures which define them.
Next, the children of these tags are mostly `tuple`s.
Each of them represents one entry in the respective relation.
The children of these `tuple`s are once again `atom` tags whose `label` attributes refers to their id.
The number of `atom`s per tuple is constant for each relation and corresponds to its arity
Besides the several `tuble`–children, there is also one `types` tag among them,
giving the type of the relation at hand.
It has as many children as the `tuple`s.
Each child is a `type`–tag whose ID refers to a signature.

In addition to this structure, there is also additional information scattered around the document
like the `builtin=<yes|false>` attribute of signatures.

In contrast to the JSON–format, this format contains must more information.
However, this comes at the cost of verbosity and arguably more complicated parsing
because the information flow is contains more jumps.

In fact, I want to give a few examples of using
[Xpath](https://www.w3schools.com/xml/xpath_intro.asp)–expressions to parse this xml output.
This shall also serve as a crashcourse–by–example if you haven't worked with Xpath.

## Xpath
For executing xpath expressions using the CLI, I recommend [`xq`](https://github.com/sibprogrammer/xq).

Generally, if you want to access the instances tag,
you need to prefix the expression by navigating the `alloy` and the `instances`–tags:
```xpath
/alloy/instances/field
```
or
```xpath
/alloy/instances/sig
```
However, I prefer just using the recursive selector `//field` or `//sig`.
It is more readable and since the output format at hand is not flexible with where `field` and `sig` can occur,
this doesn't inhibit the accuracy of the expressions.

For example, you can all files in the root directory with this expression:
```xpath
//field[@label="entries"]/tuple[atom[1]/@label = "Root$0"]/atom[2]/@label
```
where `/` and `//` indicate descending into the child(-ren) of an XML node
and the conditions within square brackets indicate conditions on the nodes.

If you'd want the names of the filesystem entries, you could combine two invocations:
```sh
IDs=$(cat $XML | xq -x '//field[@label="entries"]/tuple[atom[1]/@label = "Root$0"]/atom[2]/@label')
for id in $IDs; do
  cat $XML | xq -x '//field[@label="name"]/tuple[atom[1]/@label="'$id'"]/atom[2]/@label'
done
```

For a comprehensive list of Xpath features, I recommend [this cheatsheet](https://devhints.io/xpath) online.

## Summary
In this post, we saw how the Alloy analyzer can be invoked from the commandline.
We also saw how both the json and the xml output work.
We noticed that Json is simpler to parse but contains less information.
Lastly, we saw how Xpath expressions can be used to parse specifically the xml output of the analyzer.

# Contributing guide

Thank you for considering to contribute to Rex! As a free and open source project, it is developed by volunteers all around the world like you.

The guidelines collected here are aimed at helping communication around contributions, in order to make an efficient use of one of our most important resource: time.

Since most contributions we receive is about code, this guide also focuses a lot on them, but it's far from the only way you can participate. Improving documentation, submitting and triaging bug reports, or spreading the word via blogs and talks are all equally encouraged and welcome. Or you can just simply star the project on [GitHub](https://github.com/RexOps/Rex) or add it to your favorites on [MetaCPAN](https://metacpan.org/pod/Rex) :)

Please don't use the [issue tracker](https://github.com/RexOps/Rex/issues) for support questions. Instead, check whether the [#rex IRC channel on Freenode](https://webchat.freenode.net/?channels=rex) can help, or ask in the [Rex Users discussion group](https://groups.google.com/forum/#!forum/rex-users).

## Project guidelines

Over the course of years, many decisions were taken around Rex. We found some of the ideas coming up more often than others, so we collected them here (in no particular order).

### Cross platform support

Rex is expected to be able to _run_ wherever Perl can run. This includes Linux, BDSs, Mac OS X, Windows and possibly others. Patches and how-tos about how to run Rex on even more platforms are very welcome! As a general rule, running Rex is only supported on platforms which are actively maintained by their respective upstreams.

### Supported OSes

Rex is expected to be able to _manage_ machines running various operating systems. This mainly includes Unix-like systems. Patches and how-tos about how to manage other operating systems are very welcome! As a general rule, managing a machine with Rex is only supported for OSes that are actively maintained by their respective upstreams.

### Supported Perl versions

The minimum version of Perl that is supported by Rex is determined by matching the oldest version of Perl 5 that is supplied by the platforms where Rex is supported to run. Up until the EOL date of Red Hat/CentOS 5 on 2017-03-31, this meant 5.8.8. Currently it is 5.10.1.

On top of the supported minimum version of Perl, the goal is to support the latest versions of all minor Perl 5 releases. That makes the full list the following:

 - 5.10.1
 - 5.12.5
 - 5.14.4
 - 5.16.3
 - 5.18.4
 - 5.20.3
 - 5.22.4
 - 5.24.3
 - 5.26.1
 - 5.28.2
 - 5.30.2

### Backwards compatibility

The goal is to remain backwards compatible within major versions of Rex (which is also implied by following Semantic Versioning rules).

To still be able to introduce new features while keeping backwards compatible, Rex has the concept of feature flags that makes it possible to selectively opt in our out of new features, depending on the needs of the use case. The collection of preferred settings for a specific version of Rex can also be enabled via feature flags named after the minor releases. The goal is to have pairs of feature flags for opting in and out.

Features and code paths may be dropped by following a planned deprecation procedure. Ideally, there are warnings enabled about the deprecation first, to provide a transition period for the users.

### Code layout

Rex uses perltidy to format its codebase according to the rules described in `.perltidyrc`. All contributions are expected to be formatted using the same rules. It is important to note that the emphasis is not on the formatting rules themselves, but on having a consistent layout throughout the codebase. Since `.perltidyrc` is part of the repo, it can also be the subject of contributions.

### Tests should pass

Rex has two major test suites:

 - the _unit tests_ included with the code, which are exercising various modules and features
 - the _functional tests_ in the [RexOps/rex-build](https://github.com/RexOps/rex-build) repo, which are making sure Rex can manage actual VMs running various OSes

In general, when adding a new feature or when changing behaviour, tests should be added too, and all tests should still pass.

In order to make the guidelines listed here easier to follow, they should also have corresponding tests as well.

### Have fun

It is very important to have fun while using Rex or contributing to it. If it is not the case, then that's probably a bug somewhere, so please let us know.

## Development tools

The Rex project uses Git for version control of the source code. The [repository](https://github.com/RexOps/Rex) is hosted on GitHub.

It is recommended (but optional) to use a separate Perl environment for development, like the ones you can manage with [Perlbrew](https://perlbrew.pl/).

The code and examples use [`cpanm`](https://metacpan.org/pod/App::cpanminus) to install modules from CPAN.

Rex uses [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) as an authoring tool. With that, installing dependencies can be done by the following commands after cloning the source code:

    dzil authordeps --missing | cpanm
    dzil listdeps --missing | cpanm

[Perltidy](https://metacpan.org/pod/distribution/Perl-Tidy/bin/perltidy) takes care of maintaining a consistent source code formatting.

## Testing

The test suite included with the source code of Rex can be executed with `prove`:

    prove --lib --recurse t/

Extended, author and release tests may need further dependencies, before being executed with `dzil`:

    dzil listdeps --author --missing | cpanm
    dzil test

## Git workflow

The preferred way for sending contributions is to fork the repository on GitHub, and send pull requests against the `master` branch.

It is recommended to use feature branches when working on contributions, which makes it easy to keep together the commits related to a specific changeset.

Ideally, one commit represents a single logical change, has a readable commit message, and passes tests in itself. There are many articles written on the topic, but this is a good example about [how to write a git commit message](https://chris.beams.io/posts/git-commit/).

It is generally fine to:
 - break tests when adding new tests before changing the code to fix them
 - use multiple commits in a single pull request to separate logical steps, and to help understanding the changes as long as the history is still easy to follow and read
 - open and mark pull requests as WIP (Work In Progress) to share and get feedback early
 - use follow up/clean up commits on the same PR, but then please also squash related commits together in the feature branch _before_ merging in order to keep a tidy history

## Contribute to this guide

If you think some of the information here is outdated, not clear enough, or have bugs, feel free to contribute to it too!

## Useful resources

 - [Rex website](https://www.rexify.org)
 - [MetaCPAN](https://metacpan.org/pod/Rex)
 - [GitHub](https://github.com/RexOps/Rex)
 - [Issue tracker](https://github.com/RexOps/Rex/issues)
 - [Google Groups](https://groups.google.com/forum/#!forum/rex-users)
 - [IRC](https://webchat.freenode.net/?channels=rex)

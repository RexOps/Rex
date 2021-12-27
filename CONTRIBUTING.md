# Contributing guide

Thank you for considering to contribute to Rex! It is a free and open source project developed by volunteers like you from all around the world.

We would like to make sure everyone can make an efficient use of their time. The goal of the guidelines here is to help communication around contributions.

Since most contributions we receive is about code, this guide also focuses a lot on them. But it's far from being the only way you can participate:

- improving documentation
- testing with various setups
- submitting and triaging bug reports
- spreading the word via blogs, talks and social media
- starring the project on [GitHub](https://github.com/RexOps/Rex)
- adding it to your favorites on [MetaCPAN](https://metacpan.org/pod/Rex)
- listing it as part of your stack on [StackShare](https://stackshare.io/rex)

All those are equally encouraged and welcome!

## Project guidelines

Over the course of years, many decisions were taken around Rex. We found some of the ideas coming up more often than others, so we collected them here (in no particular order).

### Getting help and support

If you need help with questions like “How do I…?” and “Why does it…?”, please see our [support](https://www.rexify.org/support/index.html) page for both community and commercial support.

Please use the issue tracker only for bug reports and feature requests.

### GitHub issues and pull requests

The first step of any change proposal is to open an issue about it. This gives a chance to discuss the details, and to design potential solutions before spending any effort on the implementation.

To cover the vast majority of typical discussion points in advance, there are predefined templates for issues and pull requests. Please make sure to use them in order to streamline the workflow.

If something comes up that is not a good fit for the templates, that's probably already an early indicator that it should be discussed more closely. In this case please [contact us](https://www.rexify.org/support/index.html) first, or at least provide a reasoning about why the template had to be ignored in that specific case.

### Rex core vs extending Rex

Strictly speaking the core competency of Rex is to execute commands, manage files, define tasks, and orchestrate their execution.

Rex gained lots of other capabilities over time, and historically many of them landed in core as well. But it is often possible to extend Rex by only minimally changing the core, if at all. For example this includes adding support to:

- manage new operating systems
- new shell types
- new virtualization methods
- new cloud providers

It is highly encouraged to add such new capabilities via their own extension modules outside the core. If in doubt, please check some of the common scenarios below, or [contact us](https://www.rexify.org/support/index.html).

### Cross platform support

Rex is expected to _run_ wherever Perl can run. This includes Linux, BSDs, Mac OS X, Windows and possibly others. Patches and guides about how to run Rex on even more platforms are more than welcome!

As a general rule, running Rex is only supported on platforms which are actively maintained by their respective upstream teams.

### Supported OSes

Rex is expected to _manage_ endpoints running various operating systems. Today, this mostly means Unix-like systems. Patches and guides about how to manage other operating systems are more than welcome!

As a general rule, managing an endpoint with Rex is only supported for platforms that are actively maintained by their respective upstream teams.

### Supported Perl versions

The minimum version of Perl that is supported by Rex is determined by matching the oldest version of Perl 5 that is supplied by the platforms where Rex is supported to run. Up until the retirement date of RHEL/CentOS 5 on 2017-03-31, this meant 5.8.8. Currently it is 5.10.1.

On top of the supported minimum version of Perl, the goal is to support the latest versions of all minor Perl 5 releases. That makes the full list the following:

- 5.10.1
- 5.12.5
- 5.14.4
- 5.16.3
- 5.18.4
- 5.20.3
- 5.22.4
- 5.24.4
- 5.26.3
- 5.28.3
- 5.30.3
- 5.32.1
- 5.34.0

### Backwards compatibility

The goal is to remain backwards compatible within major versions of Rex (which is also implied by following [Dotted Semantic Versioning](https://metacpan.org/pod/Version::Dotted::Semantic#Dotted-Semantic-Versioning-Specification) rules).

To still be able to introduce new features while staying backwards compatible, Rex uses [feature flags](https://metacpan.org/pod/Rex#FEATURE-FLAGS). This makes it possible to selectively opt in or out of new features, depending on the needs of the given use case.

The collection of preferred settings for a specific version of Rex can also be enabled via feature flags named after the minor releases.

The goal is to have pairs of feature flags for opting in and out.

### Deprecation policy

Features and code paths may be dropped by following a planned deprecation procedure. In order to provide a transition period for the users, there should be warnings about the deprecation before the behavior is changed.

If a supported OS gets deprecated, we may try to keep it supported while it doesn't cause any problems. As soon a retired OS starts to cause bugs, or gets in the way of progress, it is a candidate to be dropped from support.

In other words, we may choose to be lazy to keep the support around, but it's probably not worth putting effort actively into something that is not supported anymore even by their own creators.

In case you depend on a deprecated feature, or must use or manage a retired OS, you might be interested to get community or commercial [support](https://www.rexify.org/support/index.html).

### Code layout

Rex uses [Perl::Tidy](https://metacpan.org/pod/Perl::Tidy) to format its codebase according to the rules described in `.perltidyrc`. All contributions are expected to be formatted using the same rules.

To avoid unnecessary "tidy only" commits, we recommend to integrate formatting directly into your workflow, for example via a git pre-commit hook, or via your editor as a shortcut or automatic action.

It is important to note that the emphasis is not on the formatting rules themselves, but on having a consistent layout throughout the codebase. Since `.perltidyrc` is part of the repo, it can also be the subject of contributions.

### Code quality

Rex uses [Test::Perl::Critic::Progressive](https://metacpan.org/pod/Test::Perl::Critic::Progressive) to make sure every change follows best practices described by the code quality rules in `.perlcriticrc`, and no new violations are introduced accidentally.

Since `.perlcriticrc` is part of the repo, it can also be the subject of contributions. In fact, improving the rules and the codebase in this regard is highly welcome.

### Tests should pass

Rex has two major test suites:

- the _unit tests_ included with the code, which are exercising various modules and features
- the _functional tests_ in the [RexOps/rex-build](https://github.com/RexOps/rex-build) repo, which are making sure Rex can manage actual VMs running various OSes

In general, when adding a new feature or when changing behavior, tests should be added too, and all previous tests should still pass.

In order to make it easier to follow the guidelines listed here, these should also have corresponding tests as well.

### Have fun

It is highly important to have fun while using Rex or contributing to it. If it is not the case, then that's probably a bug somewhere, so please let us know.

## Development tools

The Rex project uses [Git](https://www.git-scm.com) for version control of the source code. The [repository](https://github.com/RexOps/Rex) is hosted on GitHub.

It is recommended (but optional) to use a separate Perl environment for development, like the ones you can manage with [Perlbrew](https://perlbrew.pl/).

The code and examples use [cpanm](https://metacpan.org/pod/App::cpanminus) to install modules from CPAN.

Rex uses [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) as an authoring tool. With that, installing dependencies can be done by the following commands after cloning the source code:

    dzil authordeps | cpanm
    dzil listdeps | cpanm

Some of the optional dependencies might not be available on all platforms, but to install them as well, use this command:

    dzil listdeps --suggests | cpanm

To install remaining OS-specific dependencies and Rex itself, run:

    dzil install

To install the OS-specific dependencies only, run one of these commands depending on your OS:

- Windows: `cpanm Net::SSH2`
- non-Windows: `cpanm Net::OpenSSH Net::SFTP::Foreign IO::Pty`

[Perltidy](https://metacpan.org/pod/distribution/Perl-Tidy/bin/perltidy) takes care of maintaining a consistent source code formatting.

[Perlcritic](https://metacpan.org/pod/distribution/Perl-Critic/bin/perlcritic) makes sure the codebase keeps following best practices and minimum quality requirements.

## Testing

The test suite included with the source code of Rex can be executed with `prove`:

    prove --lib --recurse t/

Extended, author and release tests may need further dependencies, before being executed with `dzil`:

    dzil listdeps --author --missing | cpanm
    dzil test --all

It's particularly important to run the progressive perlcritic tests on the default branch before modifying the code base. This generates baseline data to compare against later:

    rm xt/author/.perlcritic-history
    prove --lib xt/author/critic-progressive.t

## Git workflow

The preferred way for sending contributions is to [fork](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-forks) the repository on GitHub, and send [pull requests](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-pull-requests) against the default branch of the repository.

It is recommended to use feature [branches](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-branches) when working on contributions. This makes it easy to separate the commits related to a specific changeset from the main line of development, while still keeping them together in one place.

Ideally, a single commit:

- represents a single logical change
- has a readable commit message
- passes tests in itself

There are many articles written on the topic, but this is a good example about [how to write a git commit message](https://chris.beams.io/posts/git-commit/).

It is generally recommended to:

- add new breaking tests on a first commit before changing the code to fix them on a follow up commit
- use multiple commits in a single pull request to separate logical steps, and to help understanding the changes as long as the history is still easy to follow and read
- open [draft pull requests](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/about-pull-requests#draft-pull-requests) to share the idea and ask for feedback early
- [rebase](https://docs.github.com/en/github/using-git/about-git-rebase) your feature branch on top of the default branch if there are new commits since the feature branch has been created
- use follow up/clean up commits on the same PR, but then please also [squash related commits](https://docs.github.com/en/github/using-git/about-git-rebase) together in the feature branch _before_ merging in order to keep a tidy history (in other words, no "tidy only" or "fix typo" commits are necessary)

## Common scenarios

### Add support to manage new operating systems

Allowing Rex to manage a new OS requires the following steps:

1. Teach rex about how to detect the given OS

    - add a way to `Rex::Hardware::Host::get_operating_system()` to detect the given OS
    - add a new `is_myos()` function to `Rex::Commands::Gather`

1. Let Rex choose the proper package and service management modules for the given OS

    - modify `Rex::Service` and `Rex::Pkg`

1. Add new service and package management modules specific to the given OS

    - add `Rex::Service::MyOS`
    - add `Rex::Pkg::MyOS`

### Add support for new virtualization methods

Assuming the new virtualization method is called `MyVirt`, the following steps are required:

- create the top-level `Rex::Virtualization::MyVirt` module which includes the constructor, and the documentation
- create submodules for each virtualization command, e.g. `Rex::Virtualization::MyVirt::info`
- implement the logic of the given command as the `execute` method

## Contribute to this guide

If you think some of the information here is outdated, not clear enough, or have bugs, feel free to contribute to it too!

## Useful resources

- [Rex website](https://www.rexify.org)
- [MetaCPAN](https://metacpan.org/pod/Rex)
- [GitHub](https://github.com/RexOps/Rex)
- [Discussions](https://github.com/RexOps/Rex/discussions)
- [Issue tracker](https://github.com/RexOps/Rex/issues)
- [Google Groups](https://groups.google.com/forum/#!forum/rex-users)
- [StackShare](https://stackshare.io/rex)
- [Matrix](https://matrix.to/#/#rexops:matrix.org)
- [IRC](https://webchat.oftc.net/?channels=rexops)

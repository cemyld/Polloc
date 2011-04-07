Perl modules for Polymorphic Loci Analysis (Polloc)
===================================================

A collection of perl modules to analyse *Polymorphic Loci*
in bacterial genomes.

Author
------

Luis M. Rodriguez R. <lmrodriguezr at gmail dot com>

Institut de Recherche pour le developpement

UMR Resistance des Plantes aux Bioagresseurs

Group *Effecteur/Cible*

Montpellier, France

License
-------

This package is licensed under the terms of *The Artistic
License*. See LICENSE.txt.

Description
-----------



Requirements
------------

### System-wide requirements

The basic system requires, at least, the following perl
modules:

* `Error`

* `File::Path`

* `File::Spec`

* `File::Temp`

* `Symbol`

### Other requirements

The following requirements can be ignored depending on the
set of modules to be used.

#### Perl modules:

*  `File::Basename`

* `Cwd`

* `Bio::SeqIO`

* `Bio::Tools::Run::Alignment::Muscle`

* `Bio::Tools::Run::StandAloneBlast`

* `Bio::Tools::Run::Hmmer`

#### External tools

* [CRISPRfinder](http://crispr.u-psud.fr/Server/), for CRISPRs detection

* [TRF](http://tandem.bu.edu/trf/trf.html), for Tandem Repeats detection (producing `Polloc::Feature::Repeat` objects)

* [mreps](http://bioinfo.lifl.fr/mreps/), for Repeats detection (alternative to TRF).

* [Stand-Alone NCBI BLAST](http://blast.ncbi.nlm.nih.gov/), for several analyses including features grouping,
homology-based detection of features and context-based groups extension.

* [Muscle](http://www.drive5.com/muscle/), for alignments in features detection and grouping, as well as context-based
groups extension.

* [HMMER](http://http://hmmer.janelia.org/), for profiles-based features detection and as alternative to BLAST in
context-based groups extension.

Installation
------------


Usage
-----

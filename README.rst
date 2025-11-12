Introduction
============
Transforms HTML to CNXML.

This project has been converted to **Swift** for modern, high-performance processing.


Swift Version (Recommended)
============================

Requirements
------------
- Swift 5.9 or later
- macOS 13+ or Linux
- libxml2 and libxslt (usually pre-installed on macOS and most Linux distributions)
- Java (required for Jing validation)

Building
--------
::

    swift build

Running Tests
-------------
::

    swift run testbed

Or skip validation::

    swift run testbed -noval

Using as a Library
------------------
Add to your ``Package.swift``::

    dependencies: [
        .package(url: "https://github.com/Getworkforyou/rhaptos.html2cnxml.git", from: "1.0.0")
    ]

Example usage::

    import RhaptosHTML2CNXML

    let transformer = HTMLSoup2CNXML()
    let (cnxml, images, title) = try transformer.htmlsoupToCNXML(
        content: htmlString,
        downloadImages: true,
        baseURL: "https://example.com"
    )


Python Version (Legacy)
========================

Requirements
------------
- Python 2.x
- tidylib - http://pypi.python.org/pypi/pytidylib/0.2.1
- readability-lxml - http://pypi.python.org/pypi/readability-lxml/0.2.3

Running
-------
::

    python testbed_html.py

Or skip validation::

    python testbed_html.py -noval


Contents of folders
===================

Folders for all transformations
    jing                  Jing Relax NG validator and validation files.
    www                   XSLT transformation files.
    www/catalog_xhtml     XHTML Entity Catalog files.

Folders for HTML transformation
    testbed_html          HTML testbed. Contains a set of HTML which should be converted.
    testbed_html_output   CNXML output of the HTML testbed.

Swift Files (Current Implementation)
    Package.swift                           Swift package manifest.
    Sources/RhaptosHTML2CNXML/              Main library modules.
        HTMLSoup2CNXML.swift                Core HTML to CNXML transformation.
        XHTMLPremailer.swift                XHTML Premailer (moves CSS into tags).
        MagicMIME.swift                     MIME type detection.
    Sources/TestbedHTML/                    Executable for testbed processing.
        main.swift                          Main program for HTML testbed processing.

Python Files (Legacy)
    htmlsoup2cnxml.py     Transformation HTML (String) to CNXML (String).
                          This file is a slightly modified version of htmlsoup2cnxml.py in Products.CNXMLTransforms.
    xhtmlpremailer.py     XHTML Premailer (moves CSS into tags).
    magic.py              MIME type detection.
    testbed_html.py       Main program for HTML testbed processing.


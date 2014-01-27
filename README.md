US Patent 5,715,314 Appendix G Source Code 
=============================

[Andrew Payne](https://github.com/payne92), Larry Stewart, and [Win Treese](https://github.com/treese)

December 2013

This repository contains a machine-readable copy of the source code from Appendix G of US Patent 5,715,314 "Network Sales System". The code is in the `pay1094` subdirectory.

The code was originally submitted to the US Patent Office with the original application on microfiche.  A scanned copy of the fiche is in the file `pdf/314-appendix-g.pdf`, and a version with the pages rotated for readability is in the file `pdf/314-appendix-g-rotated.pdf`.  The files here should be close to those on the fiche. The inventors are the sort of engineers who know storage is cheap and are reluctant to delete anything, so we still have the source code repositories from Open Market.  We've pulled out the versions which correspond to the scanned microfiche pages and included them here for anyone who is interested.

According to the U.S. Constitution, Congress has the power "To promote the Progress of Science and useful Arts, by securing for limited Times to Authors and Inventors the exclusive Right to their respective Writings and Discoveries." This is the power that permits the government to issue patents. This is a trade: the patent owner gets a limited term of exclusive rights, and, in exchange, the patent must disclose the invention and enable its use.

The part of a patent that explains the invention for the benefit of others is called the specification. It is supposed to be sufficiently detailed to enable a person of ordinary skill in the art to practice the invention.  Some patents have vague specifications, but we tried to ensure that '314 patent isn't in that category.

The '314 patent, titled Network Sales System, describes aspects of the Internet commerce platform built by Open Market starting in 1994.  The system included an online store-builder, shopping carts, payment processing, online statements, fulfillment of electronic goods, and much else. As is common, the specification for '314 includes a textual description and drawings.  As is also common, it includes some appendices, including, for example, the specification for Hypertext Transfer Protocol (because, in 1994, HTTP and the rest of the World Wide Web were still new).

What was unusual in 1994, and almost unheard of now, is that Open Market included the source code for the Internet commerce application right in the patent application.  In other words, Open Market made an extraordinary effort at disclosure in its application. At that time, there was no way to submit machine-readable appendices, so Appendix F (the online store-builder code) was submitted as printouts, and Appendix G (the e-commerce code) was submitted on microfiche.

Notes on the source code
----------------------

We wrote the first versions of the Open Market software in TCL, John Ousterhout's Tool Command Language.  This was the Python of its day.  It was very effective at linking to C libraries and extensions and for quick turnaround development, but it isn't the best choice for a large scale system.  We chose it because the key developers were familiar with it, having used it to write such things as digital signal processing tools, automated compiler testing packages in TCL, web applications, and other software.  We even developed a page description language for dynamic web pages based on HTML with embedded TCL operators that is not unlike later technologies such as PHP, Microsoft's Active Server Pages, Java Server Pages, or any number of HTML template languages that have been developed over the past twenty years.

Appendix G included the code supporting the major buyer flows for shopping carts, payment processing, and online statements, as well as the supporting code libraries.  We didn't include the UI page templates or administrative code.  The UI was represented through drawings elsewhere in the patent specification and the admin flows weren't relevant to the patent. At this time, the machine-readable code may not be exactly the same as on the microfiche because of the way the microfiche was created.  The version pulled for the patent submission was a snapshot of a working directory, rather than a fresh checkout, so a couple of files on the fiche have modification dates between versions in the repository. If you would like to point out any differences, please get in touch and we would be happy to update the machine-readable version to match the microfiche more closely.

The overall Open Market system of October 1994 used two web servers.  A Merchant Server hosted the online store builder application and store catalogs and a Payment Server hosted the e-commerce application.  Store catalog pages contained product descriptions, and each item had a "Buy" button as an anchor for something we called a payment URL. A payment URL was a link to either the shopping cart application on the payment server or directly to the payment flow (that is, for one-click purchasing!).

The payment URLs carried a payload in the query string.  The payload was a series of name-value pairs, all signed by a message authentication code using a secret key known only to the merchant and to the payment server.  A payment URL generally carried such fields as item description, item identifier, merchant identifier, price, and expiration date of the offer.  This system had many virtues, as commerce-enabled content could be anything supporting URLs, including anything from dynamically generated web pages from the online store builder to static HTML shipped on CDROMs,  or just saved to disk.

Another kind of URL, called an Access URL, carried its payload at the root of the path.  Access URLs granted access rights to regions of digital content, and were used to enable selling of time-limited access to individual documents or sets of content.  This technology was the origin of the session identifiers used by Open Market to support online newspaper and magazine publishers, which over time included Time-Warner, McGraw-Hill, the Tribune Company, and many others.

The Payment server ran a modified copy of NCSA httpd 1.3, using the "non-parsed-headers" feature of CGI to give the applications complete control over HTTP.  The CGI applications were written in TCL, using a modified version of TCL 7.3 augmented by new commands for URL parsing and keyed message authentication codes.  The CGI programs used the sybtcl library to communicate with a commercial Sybase database running on a Sun SparcStation 5.  Most of the other machines were Pentium 90 PCs from Gateway Computer, running BSDI's version of Berkeley UNIX.
 
From a vantage point of nearly twenty years later, it could be easy to critique the source code of a startup in any number of ways. There's plenty we would do differently now ourselves. Both the original submission and the machine-readable code are being made available to highlight the kind of detailed and specific disclosure made on this particular patent.

For more perspective on the inventors' views of Internet Commerce in the 1990s, please see our book about it: _Designing Systems for Internet Commerce_ (Addison-Wesley, Second Edition, 2002, with the First Edition in 1998) by Treese and Stewart. More information about the book is available at [serissa.com/commerce](http:/serissa.com/commerce).

If you have questions about the code, or corrections between the scanned microfiche and the machine-readable version, please email code@soverain.com.

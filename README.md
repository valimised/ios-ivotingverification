Valimiste Hääletuskontrollrakendus (iOS)
========================================

Requirements
------------

- Xcode 6.1.1
- iOS SDK 7.1
- OS X Mountain Lion (10.8) or newer


Library dependencies
--------------------

- OpenSSL for iPhone 1.0.1f (or newer)
- ZBar iPhone SDK 1.2


Building
--------

- Checkout VVK repository, open the Xcode project and build
- To run the application on device a valid wildcard provisioning profile must be included.


Configuration
-------------

- The default root CA certificate is located in "VVK/cert" in the main project directory. The certificate should be in X.509 DER (binary) format. The filename of the certificate used is definied as CA_CERTIFICATE_FILE in AuthenticationChallengeHandler.h It is "ca.cer" by default. When including a new certificate make sure the file is in fact copied to the application bundle by checking the Target Membership checkbox for the given file.
- The URL for the remote configuration file is defined in "VVK/conf/config.txt" in the main project directory.
- After replacing or changing certificates or renaming files it is advisable to first clean the project before building.


Additional information
----------------------

- ZBar is used for efficient QR code scanning


Contributors
--------

- Eigen Lenk - code
- Raimo Tammel - design
- Sven Heiberg and Joonas Trussmann - project leads

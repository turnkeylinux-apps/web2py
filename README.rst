web2py - Python framework
=========================

`web2py`_ is a free open source framework for rapid development of fast,
scalable, secure and portable database-driven web-based applications.
Written and programmable in Python. It includes a web-based IDE that
helps you create, modify, deploy and manage application from anywhere
using your browser.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- web2py configurations:
   
   - Web2py 3 is installed from a pinned official upstream release in
     ``/var/www/web2py``.

     **Security note**: Updates to web2py may require supervision so
     they **ARE NOT** configured to install automatically. Run
     ``web2py-update --check`` to inspect the supported Web2py 3 channel.
     Back up the appliance and review the upstream changes before running
     ``web2py-update --apply``.

   - Serve web2py applications with WSGI on Apache.
   - Force admin console to be served via SSL.
   - Include a MariaDB connection for database-driven Web2py applications.

- SSL support out of the box.
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**


.. _web2py: http://www.web2py.com/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _web2py documentation: http://web2py.com/books/default/chapter/29/14/other-recipes#Upgrading

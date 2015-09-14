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
   
   - Installed from upstream source code to /var/www/web2py
   - Serve web2py applications with WSGI on Apache.
   - Force admin console to be served via SSL.

- SSL support out of the box.
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**


.. _web2py: http://www.web2py.com/
.. _TurnKey Core: https://www.turnkeylinux.org/core

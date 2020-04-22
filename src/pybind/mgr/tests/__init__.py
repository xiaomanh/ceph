# type: ignore
from __future__ import absolute_import


import os

if 'UNITTEST' in os.environ:

    # Mock ceph_module. Otherwise every module that is involved in a testcase and imports it will
    # raise an ImportError

    import sys

    try:
        from unittest import mock
    except ImportError:
        import mock

    class M(object):
        def __init__(self, *args):
            super(M, self).__init__()
            self._ceph_get_version = mock.Mock()
            self._ceph_get = mock.MagicMock()
            self._ceph_get_module_option = mock.MagicMock()
            self._ceph_get_option = mock.MagicMock()
            self._validate_module_option = lambda _: True
            self._configure_logging = lambda *_: None
            self._unconfigure_logging = mock.MagicMock()
            self._ceph_log = mock.MagicMock()
            self._ceph_get_store = lambda _: ''
            self._ceph_get_store_prefix = lambda _: {}
            self._ceph_dispatch_remote = lambda *_: None


    cm = mock.Mock()
    cm.BaseMgrModule = M
    cm.BaseMgrStandbyModule = M
    sys.modules['ceph_module'] = cm

#!/usr/bin/env python
import sys
import unittest
sys.path.append("./site-packages/")

print(sys.path)
import tests.cells_util

print sys.path

if __name__ == '__main__':
    suite = unittest.TestLoader().loadTestsFromTestCase(tests.cells_util.TestUtils)
    unittest.TextTestRunner(verbosity=2).run(suite)
    # unittest.main()

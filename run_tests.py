import unittest
import os
import sys

def run_tests():
    """Run all tests in the tests directory"""
    # Get the directory containing this script
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Add the project root to the path
    sys.path.insert(0, base_dir)
    
    # Discover and run all tests
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover('tests', pattern='test_*.py')
    
    # Run the tests
    test_runner = unittest.TextTestRunner(verbosity=2)
    result = test_runner.run(test_suite)
    
    # Return the result
    return result.wasSuccessful()

if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
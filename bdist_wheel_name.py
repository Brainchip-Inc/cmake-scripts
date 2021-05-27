import argparse
from wheel.bdist_wheel import bdist_wheel
from setuptools.dist import Distribution

class BinaryDistribution(Distribution):
    """Distribution which always forces a binary package with platform name"""

    def __init__(self, *attrs):
        Distribution.__init__(self, *attrs)

    def has_ext_modules(self):
        return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-n", "--name", default='UNKNOWN',
                        help="The package name")
    parser.add_argument("-v", "--version", default='0.0.0',
                        help="The package version")
    parser.add_argument("-p", "--plat-name",
                        help="The package target platform")
    args = parser.parse_args()
    whl = bdist_wheel(BinaryDistribution({'name' : args.name,
                                          'version': args.version}))
    impl_tag, abi_tag, plat_tag = whl.get_tag()
    if args.plat_name is not None:
        plat_tag = args.plat_name
    wheel_name = "{}-{}-{}-{}.whl".format(whl.wheel_dist_name,
                                          impl_tag, abi_tag, plat_tag)
    print(wheel_name)

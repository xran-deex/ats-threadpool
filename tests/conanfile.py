from atsconan import ATSConan

class ATSConan(ATSConan):
    name = "ats-threadpool-tests"
    version = "0.1"
    requires = "ats-threadpool/0.1@randy.valis/testing"
    build_requires = "ats-unit-testing/0.1@randy.valis/testing"
    keep_imports = True

    def package(self):
        self.copy("tests", dst="target", keep_path=False)

    def deploy(self):
        self.copy("*", src="target", dst="bin")

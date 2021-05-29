from atsconan import ATSConan

class ATSConan(ATSConan):
    name = "ats-threadpool"
    version = "0.1"
    requires = "ats-shared-vt/0.1@randy.valis/testing", "ats-channel/0.1@randy.valis/testing"

    def package_info(self):
        super().package_info()
        self.cpp_info.libs = ["ats-threadpool"]
